extends Control
## Title screen: fly solo for practice, host a LAN game (blue ship) or join
## one (red ship).

@onready var status: Label = $Center/Box/Status
@onready var ip_box: LineEdit = $Center/Box/JoinRow/IP
@onready var found_box: VBoxContainer = $Center/Box/Found
@onready var join_panel: Control = $Center/Box/JoinRow
@onready var found_title: Label = $Center/Box/FoundTitle


func _ready() -> void:
	$Center/Box/Local.pressed.connect(_on_local)
	$Center/Box/Host.pressed.connect(_on_host)
	$Center/Box/JoinRow/Join.pressed.connect(_on_join)
	Net.status_changed.connect(_on_status)
	Net.hosts_found_changed.connect(_on_hosts)
	status.text = Net.menu_message
	Net.menu_message = ""
	# Start listening for games on the LAN right away.
	Net.start_listening(true)
	_on_hosts(Net.hosts_found)


func _on_local() -> void:
	Net.leave(false)
	Net.start_listening(false)
	get_tree().change_scene_to_file(Net.GAME_SCENE)


func _on_host() -> void:
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
