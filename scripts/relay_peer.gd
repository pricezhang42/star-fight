class_name RelayPeer
extends MultiplayerPeerExtension
## Online play through the relay server (server/relay.js), over a WebSocket,
## so it also works in a web browser (which can't use ENet or LAN broadcast).
##
## It looks to the game exactly like the LAN connection: the hosting player is
## peer 1 and runs the game; the joining player is peer 2. The relay pairs the
## two by a short room code and forwards every message between them. Nothing
## else in net.gd needs to know which kind of connection it is using.
##
## Relay protocol: text frames are JSON control messages from the relay
## ({"t": "room", "code": "ABCD"}, {"t": "paired"}, {"t": "left"},
## {"t": "error", "msg": "..."}); binary frames are game messages, forwarded
## as-is. Each game message starts with one byte: the channel (low 6 bits)
## and the transfer mode (top 2 bits).

const HOST_ID := 1
const JOIN_ID := 2
## Unreliable messages (the streamed picture, sounds) are dropped instead of
## queued once this much is waiting to be sent, so a slow connection skips
## frames instead of falling further and further behind.
const MAX_BACKLOG := 64 * 1024
## The relay closes with this code when it refuses us; the reason says why.
const CLOSE_REFUSED := 4001

## Room code the relay gave us (host) or that we asked for (joiner).
var room_code := ""
## Why the connection ended or failed, for the menu.
var error_text := ""
## Emitted on the host when the relay hands out the room code.
signal room_ready(code: String)

var _ws := WebSocketPeer.new()
var _hosting := false
var _status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _paired := false
var _incoming: Array = [] # [[channel, mode, payload], ...]
var _current: Array = []
var _target := 0
var _mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _channel := 0
var _refusing := false
var _ws_open := false
var _url := ""
var _first_try_msec := 0
var _retry_at_msec := 0
## A free server that went to sleep can take up to a minute to wake up, so
## keep retrying the first connection for this long.
const CONNECT_PATIENCE_MSEC := 90000


## Start hosting: the relay answers with a room code (signal room_ready).
func create_host(relay_url: String) -> Error:
	_hosting = true
	return _open(relay_url.trim_suffix("/") + "/host")


## Join the room with this code.
func create_join(relay_url: String, code: String) -> Error:
	_hosting = false
	room_code = code.strip_edges().to_upper()
	return _open(relay_url.trim_suffix("/") + "/join/" + room_code.uri_encode())


func _open(url: String) -> Error:
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	_ws.max_queued_packets = 4096
	if _url == "":
		_url = url
		_first_try_msec = Time.get_ticks_msec()
	var err := _ws.connect_to_url(url)
	if err != OK:
		error_text = "Could not reach the game server (error %d)." % err
		return err
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	return OK


func _poll() -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	if _retry_at_msec > 0:
		if Time.get_ticks_msec() < _retry_at_msec:
			return
		_retry_at_msec = 0
		_ws = WebSocketPeer.new()
		if _open(_url) != OK:
			_drop()
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_ws_open = true
	# Read what arrived, even if the relay already closed the connection
	# (it sends its reason, e.g. a wrong code, right before closing).
	while _ws.get_available_packet_count() > 0 and _status != MultiplayerPeer.CONNECTION_DISCONNECTED:
		var pkt := _ws.get_packet()
		_ws_open = true
		if _ws.was_string_packet():
			_on_control(pkt.get_string_from_utf8())
		elif _paired and pkt.size() >= 1:
			var head := pkt[0]
			_incoming.append([head & 63, head >> 6, pkt.slice(1)])
	if state == WebSocketPeer.STATE_CLOSED:
		if error_text == "" and _ws.get_close_code() == CLOSE_REFUSED:
			error_text = _ws.get_close_reason()
		if error_text == "" and not _ws_open \
				and Time.get_ticks_msec() - _first_try_msec < CONNECT_PATIENCE_MSEC:
			_retry_at_msec = Time.get_ticks_msec() + 3000 # server may be waking up
			return
		if error_text == "":
			if not _ws_open:
				error_text = "Could not reach the game server. Check your internet connection and try again."
			elif _paired:
				error_text = "The other player disconnected." if _hosting else "The host left the game."
			else:
				error_text = "Lost the connection to the game server."
		_drop()


func _on_control(text: String) -> void:
	var msg = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	match str(msg.get("t", "")):
		"room": # host: we're in, here is the code to share
			room_code = str(msg.get("code", ""))
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			room_ready.emit(room_code)
		"paired":
			_paired = true
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			peer_connected.emit(JOIN_ID if _hosting else HOST_ID)
		"left":
			error_text = "The other player disconnected." if _hosting else "The host left the game."
			_drop()
		"error":
			error_text = str(msg.get("msg", "The game server refused the connection."))
			_drop()


## Forget the connection; tell the game the other player is gone.
func _drop() -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	var was_paired := _paired
	_paired = false
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_incoming.clear()
	if _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close()
	if was_paired:
		peer_disconnected.emit(JOIN_ID if _hosting else HOST_ID)


func _close() -> void:
	_paired = false
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_incoming.clear()
	_ws.close()


func _disconnect_peer(_peer: int, _force: bool) -> void:
	_close()


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	_current = _incoming.pop_front()
	return _current[2]


func _get_packet_channel() -> int:
	return _current[0] if _current.size() > 0 else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return _current[1] if _current.size() > 0 else MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _get_packet_peer() -> int:
	return JOIN_ID if _hosting else HOST_ID


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if not _paired or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNCONFIGURED
	if _mode == MultiplayerPeer.TRANSFER_MODE_UNRELIABLE \
			and _ws.get_current_outbound_buffered_amount() > MAX_BACKLOG:
		return OK # skip this one; a newer picture follows shortly
	var out := PackedByteArray([(_channel & 63) | (_mode << 6)])
	out.append_array(buffer)
	return _ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)


func _get_max_packet_size() -> int:
	return 1 << 20


func _set_target_peer(peer: int) -> void:
	_target = peer


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _get_unique_id() -> int:
	return HOST_ID if _hosting else JOIN_ID


func _is_server() -> bool:
	return _hosting


func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(enable: bool) -> void:
	_refusing = enable


func _is_refusing_new_connections() -> bool:
	return _refusing


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status
