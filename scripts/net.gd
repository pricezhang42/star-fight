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
const DISCOVERY_PORT := 7778
const DISCOVERY_TAG := "STARFIGHTS"
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
var remote_turn := 0.0 ## -1..1 (A/D)
var remote_buttons := 0 ## BTN_* bits that are held down
var remote_mouse := Vector2.ZERO ## where the red ship is aiming (world position)
var _remote_events := {}

# --- discovery -------------------------------------------------------------
var _broadcaster: PacketPeerUDP = null
var _broadcast_timer := 0.0
var _listener: PacketPeerUDP = null
var hosts_found: Array = []

# --- host: what the mirror needs ------------------------------------------
var _mirror_sender: RefCounted = null
var _hud_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Command line shortcuts, handy for testing two windows on one machine.
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			call_deferred("host")
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


func _on_peer_connected(_id: int) -> void:
	if mode == Mode.HOST:
		_broadcaster = null
		get_tree().change_scene_to_file(GAME_SCENE)


func _on_peer_disconnected(_id: int) -> void:
	if mode == Mode.HOST:
		leave(true, "The other player disconnected.")


func _on_connected() -> void:
	start_listening(false)
	get_tree().change_scene_to_file(CLIENT_SCENE)


func _on_connection_failed() -> void:
	leave(true, "Could not reach the host.")


func _on_server_disconnected() -> void:
	leave(true, "The host left the game.")


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

func start_listening(on: bool) -> void:
	if not on:
		if _listener:
			_listener.close()
		_listener = null
		return
	if _listener:
		return
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null
	hosts_found.clear()
	hosts_found_changed.emit(hosts_found)


func _process(delta: float) -> void:
	# Host: shout "I'm here" on the LAN once a second while waiting.
	if _broadcaster:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = 1.0
			# Each local network's broadcast address (x.y.z.255), the general
			# broadcast address, and this machine itself (two windows, one Mac).
			var targets := ["255.255.255.255", "127.0.0.1"]
			for a in lan_addresses():
				var parts: PackedStringArray = a.split(".")
				targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
			for dest in targets:
				_broadcaster.set_dest_address(dest, DISCOVERY_PORT)
				_broadcaster.put_packet(DISCOVERY_TAG.to_utf8_buffer())
	# Joiner: collect hosts we hear.
	if _listener:
		while _listener.get_available_packet_count() > 0:
			var data := _listener.get_packet().get_string_from_utf8()
			var ip := _listener.get_packet_ip()
			if data == DISCOVERY_TAG and ip != "" and not hosts_found.has(ip):
				hosts_found.append(ip)
				hosts_found_changed.emit(hosts_found)
	# Host: stream the game to the other computer.
	if is_host():
		var scene := get_tree().current_scene
		if scene and scene.has_method("is_game_scene"):
			if _mirror_sender == null:
				_mirror_sender = NetMirror.Sender.new()
			_send_world(scene)
			_hud_timer -= delta
			if _hud_timer <= 0.0:
				_hud_timer = 0.05
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
	client_world.rpc_id(_client_id(), packet)


@rpc("authority", "call_remote", "reliable")
func client_textures(entries: Array) -> void:
	var view := get_tree().current_scene
	if view and view.has_method("add_textures"):
		view.add_textures(entries)


@rpc("authority", "call_remote", "unreliable_ordered")
func client_world(packet: PackedByteArray) -> void:
	var view := get_tree().current_scene
	if view and view.has_method("apply_world"):
		view.apply_world(packet)


@rpc("authority", "call_remote", "unreliable_ordered")
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
