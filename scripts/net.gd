extends Node
## LAN play (autoload "Net"). One computer hosts and runs the whole game
## (and flies the blue ship); the other joins and flies the red ship. The
## joining computer runs no game logic: it sends its keys and mouse to the
## host, and the host streams back everything that is drawn (see NetMirror),
## the HUD and sounds.
##
## Command line shortcuts (after "--"):  --host   or   --join=<ip>

enum Mode { LOCAL, HOST, CLIENT }

const PORT := 7777
## Bump this whenever the network messages change. Both computers must match;
## if they don't, they're told to update instead of freezing.
var NET_PROTOCOL := 5
## The world picture is sent this many times a second, split into small
## packets that each fit in one network packet (no fragmenting).
const WORLD_RATE := 30.0
const SLICE_BYTES := 1000
## UDP port for finding games on the LAN (`-- --discovery-port=N` overrides it,
## e.g. to test while another copy of the game is open on this machine).
var DISCOVERY_PORT := 7778
const DISCOVERY_TAG := "STARFIGHTS"
## A joiner asking "is anyone hosting?"; a host answers with DISCOVERY_TAG.
const PROBE_TAG := "STARFIGHTS?"
const MENU_SCENE := "res://scenes/menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const CLIENT_SCENE := "res://scenes/client_view.tscn"

signal status_changed(text: String)
signal hosts_found_changed(hosts: Array)

var mode := Mode.LOCAL
## Message shown on the menu when we get sent back there (e.g. disconnects).
var menu_message := ""

# --- host side: the red ship's input as received from the client ----------
const BTN_THRUST := 1
const BTN_BRAKE := 2
const BTN_FIRE := 4
const BTN_BOOST := 8
var remote_turn := 0.0 ## -1..1 (A/D)
var remote_buttons := 0 ## BTN_* bits that are held down
var remote_mouse := Vector2.ZERO ## where the red ship is aiming (world position)
var _remote_events := {}

# --- discovery -------------------------------------------------------------
var _broadcaster: PacketPeerUDP = null
var _broadcast_timer := 0.0
var _listener: PacketPeerUDP = null
## Joiner: sends "anyone hosting?" probes and hears the answers.
var _prober: PacketPeerUDP = null
var _probe_timer := 0.0
var _targets_cache: Array = []
var hosts_found: Array = []

# --- host: what the mirror needs ------------------------------------------
var _mirror_sender: RefCounted = null
var _hud_timer := 0.0
var _world_timer := 0.0
var _world_frame := 0
## Joiner: pieces of world frames being reassembled.
var _frames := {}
var _last_applied := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	(multiplayer as SceneMultiplayer).peer_packet.connect(_on_peer_packet)
	# Command line shortcuts, handy for testing two windows on one machine.
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			call_deferred("host")
		elif arg.begins_with("--net-protocol="): # testing the version check
			NET_PROTOCOL = int(arg.trim_prefix("--net-protocol="))
		elif arg.begins_with("--discovery-port="):
			DISCOVERY_PORT = int(arg.trim_prefix("--discovery-port="))
		elif arg.begins_with("--join="):
			call_deferred("join", arg.trim_prefix("--join="))


func is_host() -> bool:
	return mode == Mode.HOST and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0


func is_client() -> bool:
	return mode == Mode.CLIENT


# ===========================================================================
# Starting and stopping
# ===========================================================================

func host() -> void:
	leave(false)
	start_listening(false) # free the discovery port for joiners on this machine
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		_set_status("Could not open port %d (error %d)." % [PORT, err])
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	# Listen on the discovery port so joiners' probes reach us (if a joiner on
	# this same machine already holds the port, just announce instead).
	if _broadcaster.bind(DISCOVERY_PORT) != OK:
		_broadcaster.bind(0)
	_set_status("Hosting. Waiting for the other player to join...\nThis computer: %s" % ", ".join(lan_addresses()))


func join(address: String) -> void:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), PORT)
	if err != OK:
		_set_status("Could not connect to %s (error %d)." % [address, err])
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	_set_status("Connecting to %s..." % address)


## Close any connection. With `to_menu`, also go back to the menu.
func leave(to_menu := true, message := "") -> void:
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.LOCAL
	_broadcaster = null
	_mirror_sender = null
	remote_turn = 0.0
	remote_buttons = 0
	_remote_events.clear()
	if to_menu:
		menu_message = message
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU_SCENE)


func _on_peer_connected(id: int) -> void:
	if mode == Mode.HOST:
		_send_version(id)
		_broadcaster = null
		get_tree().change_scene_to_file(GAME_SCENE)


func _on_peer_disconnected(_id: int) -> void:
	if mode == Mode.HOST:
		leave(true, "The other player disconnected.")


func _on_connected() -> void:
	start_listening(false)
	_send_version(1)
	_frames.clear()
	_last_applied = -1
	get_tree().change_scene_to_file(CLIENT_SCENE)


func _on_connection_failed() -> void:
	leave(true, "Could not reach the host.")


func _on_server_disconnected() -> void:
	leave(true, "The host left the game.")


## Version check, sent as raw bytes so it works even if the two computers'
## scripts differ (when normal messages would silently fail).
func _send_version(to_peer: int) -> void:
	(multiplayer as SceneMultiplayer).send_bytes(("SFV:%d" % NET_PROTOCOL).to_utf8_buffer(), to_peer, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


func _on_peer_packet(_id: int, packet: PackedByteArray) -> void:
	var text := packet.get_string_from_utf8()
	if text.begins_with("SFV:") and int(text.trim_prefix("SFV:")) != NET_PROTOCOL:
		call_deferred("leave", true, "The other computer is running a different version of the game.\nUpdate both to the same version (pull the latest two-ships) and try again.")


func _set_status(text: String) -> void:
	status_changed.emit(text)


## This computer's LAN (IPv4, private range) addresses.
func lan_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10."):
			out.append(a)
		elif a.begins_with("172."):
			var second := int(a.split(".")[1])
			if second >= 16 and second <= 31:
				out.append(a)
	return out


# ===========================================================================
# Finding hosts on the LAN
# ===========================================================================

## Joiner side. Two ways of finding a host, so it works on more networks:
## 1. listen for the host's once-a-second announcements on DISCOVERY_PORT;
## 2. ask: send a probe to every broadcast address and to every machine in our
##    own /24 block, and collect the hosts that answer. Answers to our own
##    probes also get through firewalls that drop unsolicited broadcasts.
func start_listening(on: bool) -> void:
	if not on:
		if _listener:
			_listener.close()
		_listener = null
		if _prober:
			_prober.close()
		_prober = null
		return
	if _listener or _prober:
		return
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null # e.g. a host on this same machine has it; probing still works
	_prober = PacketPeerUDP.new()
	_prober.set_broadcast_enabled(true)
	_prober.bind(0)
	_probe_timer = 0.0
	hosts_found.clear()
	hosts_found_changed.emit(hosts_found)


## Where to send announcements and probes: the real broadcast address of each
## network this computer is on (read from the system, since home networks are
## usually x.y.z.255 but office/school ones often aren't), the general
## broadcast address, x.y.z.255 guesses, and this machine itself.
func broadcast_targets() -> Array:
	if not _targets_cache.is_empty():
		return _targets_cache
	var out := ["255.255.255.255", "127.0.0.1"]
	var text := ""
	var lines := []
	if OS.get_name() == "Windows":
		if OS.execute("ipconfig", [], lines) == 0:
			text = "\n".join(lines)
	else:
		if OS.execute("ifconfig", [], lines) == 0:
			text = "\n".join(lines)
	# macOS / Linux ifconfig: "inet 10.1.2.3 netmask 0xffffc000 broadcast 10.1.63.255"
	var rx := RegEx.create_from_string("broadcast (\\d+\\.\\d+\\.\\d+\\.\\d+)")
	for m in rx.search_all(text):
		out.append(m.get_string(1))
	# Windows ipconfig: work it out from the address and subnet mask.
	var ip_rx := RegEx.create_from_string("IPv4[^:]*:\\s*(\\d+\\.\\d+\\.\\d+\\.\\d+)")
	var mask_rx := RegEx.create_from_string("Subnet Mask[^:]*:\\s*(\\d+\\.\\d+\\.\\d+\\.\\d+)")
	var ips := ip_rx.search_all(text)
	var masks := mask_rx.search_all(text)
	for i in mini(ips.size(), masks.size()):
		var a := ips[i].get_string(1).split(".")
		var m2 := masks[i].get_string(1).split(".")
		var parts := []
		for k in 4:
			parts.append(str((int(a[k]) | (~int(m2[k]) & 255))))
		out.append(".".join(parts))
	for a in lan_addresses():
		var p: PackedStringArray = a.split(".")
		out.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	var unique := []
	for t in out:
		if not unique.has(t):
			unique.append(t)
	_targets_cache = unique
	return unique


func _add_host(ip: String) -> void:
	if ip != "" and not hosts_found.has(ip):
		hosts_found.append(ip)
		hosts_found_changed.emit(hosts_found)


func _process(delta: float) -> void:
	# Host: shout "I'm here" on the LAN once a second while waiting.
	if _broadcaster:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = 1.0
			for dest in broadcast_targets():
				_broadcaster.set_dest_address(dest, DISCOVERY_PORT)
				_broadcaster.put_packet(DISCOVERY_TAG.to_utf8_buffer())
		# Answer joiners' probes directly.
		while _broadcaster.get_available_packet_count() > 0:
			var data := _broadcaster.get_packet().get_string_from_utf8()
			var ip := _broadcaster.get_packet_ip()
			var port := _broadcaster.get_packet_port()
			if data == PROBE_TAG and ip != "":
				_broadcaster.set_dest_address(ip, port)
				_broadcaster.put_packet(DISCOVERY_TAG.to_utf8_buffer())
	# Joiner: collect hosts we hear announcing.
	if _listener:
		while _listener.get_available_packet_count() > 0:
			var data := _listener.get_packet().get_string_from_utf8()
			var ip := _listener.get_packet_ip()
			if data == DISCOVERY_TAG:
				_add_host(ip)
	# Joiner: ask "anyone hosting?" every 1.5 s, and collect the answers.
	if _prober:
		_probe_timer -= delta
		if _probe_timer <= 0.0:
			_probe_timer = 1.5
			var probe := PROBE_TAG.to_utf8_buffer()
			var dests := broadcast_targets().duplicate()
			var mine := lan_addresses()
			for a in mine:
				var p: PackedStringArray = a.split(".")
				for last in range(1, 255):
					var ip := "%s.%s.%s.%d" % [p[0], p[1], p[2], last]
					if ip != a:
						dests.append(ip)
			for dest in dests:
				_prober.set_dest_address(dest, DISCOVERY_PORT)
				_prober.put_packet(probe)
		while _prober.get_available_packet_count() > 0:
			var data := _prober.get_packet().get_string_from_utf8()
			var ip := _prober.get_packet_ip()
			if data == DISCOVERY_TAG:
				_add_host(ip)
	# Host: stream the game to the other computer.
	if is_host():
		var scene := get_tree().current_scene
		if scene and scene.has_method("is_game_scene"):
			if _mirror_sender == null:
				_mirror_sender = NetMirror.Sender.new()
			_world_timer -= delta
			if _world_timer <= 0.0:
				_world_timer = 1.0 / WORLD_RATE
				_send_world(scene)
			_hud_timer -= delta
			if _hud_timer <= 0.0:
				_hud_timer = 1.0 / 15.0
				client_hud.rpc_id(_client_id(), scene.get_node("HUD").get_net_state())


func _client_id() -> int:
	var peers := multiplayer.get_peers()
	return peers[0] if peers.size() > 0 else 0


# ===========================================================================
# Host -> client: world, HUD, sounds
# ===========================================================================

func _send_world(scene: Node) -> void:
	var cam: Camera2D = scene.camera
	var view_size: Vector2 = scene.get_viewport().get_visible_rect().size / cam.zoom
	var packet: PackedByteArray = _mirror_sender.build(scene, cam.get_screen_center_position(), view_size)
	var new_textures: Array = _mirror_sender.take_new_textures()
	if not new_textures.is_empty():
		client_textures.rpc_id(_client_id(), new_textures)
	# Compress, then split into slices small enough for one network packet
	# each. A big packet gets cut into many fragments by the network, and
	# over Wi-Fi losing any one of them loses the whole picture.
	var comp := packet.compress(FileAccess.COMPRESSION_ZSTD)
	_world_frame += 1
	var count := ceili(float(comp.size()) / SLICE_BYTES)
	for i in count:
		var b := StreamPeerBuffer.new()
		b.put_u32(_world_frame)
		b.put_u8(i)
		b.put_u8(count)
		b.put_u32(packet.size())
		b.put_data(comp.slice(i * SLICE_BYTES, mini((i + 1) * SLICE_BYTES, comp.size())))
		client_world_part.rpc_id(_client_id(), b.data_array)


@rpc("authority", "call_remote", "reliable", 2)
func client_textures(entries: Array) -> void:
	var view := get_tree().current_scene
	if view and view.has_method("add_textures"):
		view.add_textures(entries)


## One slice of a world frame (unreliable, its own channel). When all slices
## of a frame newer than the last one shown have arrived, show it.
@rpc("authority", "call_remote", "unreliable", 1)
func client_world_part(part: PackedByteArray) -> void:
	var b := StreamPeerBuffer.new()
	b.data_array = part
	var frame := b.get_u32()
	var idx := b.get_u8()
	var count := b.get_u8()
	var raw_size := b.get_u32()
	if frame <= _last_applied:
		return # older than what's already on screen
	var data: PackedByteArray = b.get_data(part.size() - 10)[1]
	if not _frames.has(frame):
		_frames[frame] = {"count": count, "raw": raw_size, "pieces": {}}
	var f: Dictionary = _frames[frame]
	f.pieces[idx] = data
	if f.pieces.size() < f.count:
		return
	var comp := PackedByteArray()
	for i in f.count:
		comp.append_array(f.pieces[i])
	_last_applied = frame
	for k in _frames.keys():
		if k <= frame:
			_frames.erase(k)
	var view := get_tree().current_scene
	if view and view.has_method("apply_world"):
		view.apply_world(comp.decompress(f.raw, FileAccess.COMPRESSION_ZSTD))


@rpc("authority", "call_remote", "reliable", 2)
func client_hud(state: Dictionary) -> void:
	var view := get_tree().current_scene
	if view and view.has_node("HUD"):
		view.get_node("HUD").apply_net_state(state)


## Called by Fx.sound on the host: play the same sound on the other computer.
func share_sound(stream: AudioStream, volume_db: float, pitch := 1.0) -> void:
	if is_host() and stream and stream.resource_path != "":
		client_sound.rpc_id(_client_id(), stream.resource_path, volume_db, pitch)


@rpc("authority", "call_remote", "unreliable")
func client_sound(path: String, volume_db: float, pitch: float) -> void:
	var stream := load(path) as AudioStream
	if stream:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = clampf(pitch, 0.5, 2.0)
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()


# ===========================================================================
# Client -> host: the red ship's input
# ===========================================================================

## Called every frame on the joining computer.
func send_input(turn: float, buttons: int, mouse: Vector2) -> void:
	if mode == Mode.CLIENT and multiplayer.has_multiplayer_peer():
		host_input.rpc_id(1, turn, buttons, mouse)


## Button presses (reliable, so none get lost).
func send_event(action: String, mouse: Vector2) -> void:
	if mode == Mode.CLIENT and multiplayer.has_multiplayer_peer():
		host_event.rpc_id(1, action, mouse)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func host_input(turn: float, buttons: int, mouse: Vector2) -> void:
	remote_turn = clampf(turn, -1.0, 1.0)
	remote_buttons = buttons
	remote_mouse = mouse


@rpc("any_peer", "call_remote", "reliable")
func host_event(action: String, mouse: Vector2) -> void:
	remote_mouse = mouse
	_remote_events[action] = true


## Host: was this button pressed on the other computer since last asked?
func take_event(action: String) -> bool:
	if _remote_events.has(action):
		_remote_events.erase(action)
		return true
	return false


## F11 toggles fullscreen everywhere (menu, game, client view).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var scene := get_tree().current_scene
		if scene and scene.scene_file_path != MENU_SCENE:
			leave(true)
			get_viewport().set_input_as_handled()
