extends Control
## Title screen: fly solo for practice, host or join an online game (works
## anywhere, also in a web browser), or host or join a LAN game (desktop only).

@onready var status: Label = $Center/Box/Status
@onready var ip_box: LineEdit = $Center/Box/JoinRow/IP
@onready var code_box: LineEdit = $Center/Box/CodeRow/Code
@onready var copy_button: Button = $Center/Box/Copy
@onready var found_box: VBoxContainer = $Center/Box/Found
@onready var join_panel: Control = $Center/Box/JoinRow
@onready var found_title: Label = $Center/Box/FoundTitle


func _ready() -> void:
	$Center/Box/Local.pressed.connect(_on_local)
	$Center/Box/OnlineHost.pressed.connect(_on_host_online)
	$Center/Box/CodeRow/JoinOnline.pressed.connect(_on_join_online)
	code_box.text_submitted.connect(func(_t): _on_join_online())
	copy_button.pressed.connect(_on_copy)
	$Center/Box/Host.pressed.connect(_on_host)
	$Center/Box/JoinRow/Join.pressed.connect(_on_join)
	Net.status_changed.connect(_on_status)
	Net.hosts_found_changed.connect(_on_hosts)
	Net.room_ready.connect(_on_room_ready)
	status.text = Net.menu_message
	Net.menu_message = ""
	if Net.is_web():
		# Browsers can't do LAN play: only solo and online.
		for n in ["LanTitle", "Host", "JoinRow", "FoundTitle", "Found"]:
			get_node("Center/Box/" + n).hide()
		$Center/Box/OnlineTitle.text = "PLAY ONLINE:"
		return
	# Start listening for games on the LAN right away.
	Net.start_listening(true)
	_on_hosts(Net.hosts_found)


func _on_local() -> void:
	Net.leave(false)
	Net.start_listening(false)
	get_tree().change_scene_to_file(Net.GAME_SCENE)


func _on_host_online() -> void:
	copy_button.hide()
	Net.host_online()


func _on_join_online() -> void:
	if code_box.text.strip_edges() == "":
		status.text = "Type the game code the host sees on their screen."
		return
	copy_button.hide()
	Net.join_online(code_box.text)


func _on_room_ready(code: String) -> void:
	copy_button.text = "COPY INVITE LINK" if Net.invite_link() != "" else "COPY CODE %s" % code
	copy_button.show()


func _on_copy() -> void:
	var link := Net.invite_link()
	DisplayServer.clipboard_set(link if link != "" else Net.room_code)
	copy_button.text = "COPIED!"


func _on_host() -> void:
	copy_button.hide()
	Net.start_listening(false)
	Net.host()


func _on_join() -> void:
	if ip_box.text.strip_edges() == "":
		status.text = "Type the host's address, or click a game found below."
		return
	Net.join(ip_box.text)


func _on_status(text: String) -> void:
	status.text = text


func _on_hosts(hosts: Array) -> void:
	for c in found_box.get_children():
		c.queue_free()
	found_title.text = "GAMES FOUND ON YOUR NETWORK:" if hosts.size() > 0 else "LOOKING FOR GAMES ON YOUR NETWORK..."
	for ip in hosts:
		var b := Button.new()
		b.text = "JOIN %s" % ip
		b.pressed.connect(func(): ip_box.text = ip; Net.join(ip))
		found_box.add_child(b)
