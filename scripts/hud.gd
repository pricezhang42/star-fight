extends CanvasLayer
## Lives, dash and laser for both ships (blue on the left, red on the right), the
## scroll speed, the bottom-edge warning glow and the big centre message.

const LIFE_ICONS := {
	1: preload("res://assets/kenney_space_shooter_redux/ui/playerLife1_blue.png"),
	2: preload("res://assets/kenney_space_shooter_redux/ui/playerLife1_red.png"),
}

@onready var message: Label = $Message
@onready var scroll_label: Label = $Scroll
@onready var _lives_boxes := {1: $P1Lives, 2: $P2Lives}
@onready var _dash_labels := {1: $P1Dash, 2: $P2Dash}
@onready var _laser_labels := {1: $P1Laser, 2: $P2Laser}
@onready var _item_boxes := {1: $P1Items, 2: $P2Items}

## Which ship this screen belongs to: 1 on the host (and solo), 2 on the
## joining computer. Decides whose bottom-edge warning is shown.
var local_player := 1
var _lives := {1: -1, 2: -1}
var _dash := {1: -1.0, 2: -1.0}
var _laser := {1: -1.0, 2: -1.0}
var _items := {1: [], 2: []}
var _weapon := {1: 0, 2: 0}
var _shield := {1: 0.0, 2: 0.0}
var _selected := {1: 0, 2: 0}
var _danger := {1: 0.0, 2: 0.0}
var _solo := false


func _ready() -> void:
	# Fade the control help out after the first 15 seconds of a run.
	var tw := $Hint.create_tween()
	tw.tween_interval(15.0)
	tw.tween_property($Hint, "modulate:a", 0.0, 1.5)


## Solo practice: hide the red ship's side of the HUD.
func set_solo(solo: bool) -> void:
	_solo = solo
	for node in [$P2Label, $P2Lives, $P2Dash, $P2Laser, $P2Items]:
		node.visible = not solo


func set_lives(id: int, n: int) -> void:
	if _lives[id] == n:
		return
	_lives[id] = n
	var box: HBoxContainer = _lives_boxes[id]
	for c in box.get_children():
		c.queue_free()
	for i in n:
		var icon := TextureRect.new()
		icon.texture = LIFE_ICONS[id]
		box.add_child(icon)


## 0..1 how recharged that ship's dash is (1 = ready).
func set_dash(id: int, ready_fraction: float) -> void:
	_dash[id] = ready_fraction
	var label: Label = _dash_labels[id]
	if ready_fraction >= 1.0:
		label.text = "DASH READY - SHIFT"
		label.modulate = Color(0.6, 0.9, 1.0)
	else:
		label.text = "DASH %d%%" % int(ready_fraction * 100.0)
		label.modulate = Color(0.6, 0.7, 0.8, 0.7)


## 0..1 how recharged that ship's laser is (1 = ready).
func set_laser(id: int, ready_fraction: float) -> void:
	_laser[id] = ready_fraction
	var label: Label = _laser_labels[id]
	var wname: String = PowerUps.WEAPON_NAMES[_weapon[id]]
	var extra := ("   SHIELD %ds" % ceili(_shield[id])) if _shield[id] > 0.0 else ""
	if ready_fraction >= 1.0:
		label.text = wname + " READY" + extra
		label.modulate = Color(1.0, 0.9, 0.5) if _weapon[id] == 0 else Color(1.0, 0.6, 0.3)
	else:
		label.text = "%s %d%%%s" % [wname, int(ready_fraction * 100.0), extra]
		label.modulate = Color(0.8, 0.75, 0.6, 0.7)


## Weapon pickup in use and Shield time, shown on that ship's laser line.
func set_loadout(id: int, weapon: int, shield_left: float) -> void:
	_weapon[id] = weapon
	_shield[id] = shield_left
	set_laser(id, maxf(_laser[id], 0.0))


## That ship's power-up slots: icon + name, the selected one highlighted.
func set_items(id: int, items: Array, selected: int) -> void:
	_items[id] = items.duplicate()
	_selected[id] = selected
	var box: HBoxContainer = _item_boxes[id]
	for c in box.get_children():
		c.queue_free()
	for i in items.size():
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.texture = PowerUps.ICONS[items[i]]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40) if i == selected else Vector2(30, 30)
		slot.add_child(icon)
		var name_label := Label.new()
		name_label.text = PowerUps.NAMES[items[i]]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ls := LabelSettings.new()
		ls.font = scroll_label.label_settings.font
		ls.font_size = 13
		ls.outline_size = 3
		ls.outline_color = Color.BLACK
		name_label.label_settings = ls
		slot.add_child(name_label)
		slot.modulate = Color.WHITE if i == selected else Color(1, 1, 1, 0.45)
		box.add_child(slot)


func set_scroll(mult: float) -> void:
	scroll_label.text = "SCROLL x%.1f" % mult


## Big "GET READY" countdown in the middle; 0 hides it.
func set_countdown(n: int) -> void:
	if n > 0:
		message.text = "GET READY\n\n%d" % n
		message.visible = true
	elif message.text.begins_with("GET READY"):
		message.visible = false


## Red glow at the bottom of the screen, 0..1, as that ship nears the bottom
## edge. Each computer only shows the glow for its own ship.
func set_danger(id: int, amount: float) -> void:
	_danger[id] = amount
	$Danger.modulate.a = _danger[local_player]


func show_message(text: String) -> void:
	message.text = text
	message.visible = true


## Everything the HUD shows, for sending to the other computer in LAN play.
func get_net_state() -> Dictionary:
	return {
		"lives": [_lives[1], _lives[2]],
		"dash": [_dash[1], _dash[2]],
		"laser": [_laser[1], _laser[2]],
		"items": [_items[1], _items[2]],
		"weapon": [_weapon[1], _weapon[2]],
		"shield": [_shield[1], _shield[2]],
		"sel": [_selected[1], _selected[2]],
		"danger": [_danger[1], _danger[2]],
		"scroll": scroll_label.text,
		"msg": message.text, "msg_on": message.visible,
		"hint": $Hint.modulate.a,
	}


## Show what the host's HUD shows (on the joining computer in LAN play).
func apply_net_state(st: Dictionary) -> void:
	local_player = 2
	for i in 2:
		var id := i + 1
		set_lives(id, st.lives[i])
		if st.dash[i] != _dash[id]:
			set_dash(id, st.dash[i])
		if st.weapon[i] != _weapon[id] or st.shield[i] != _shield[id]:
			_weapon[id] = st.weapon[i]
			_shield[id] = st.shield[i]
			set_laser(id, maxf(st.laser[i], 0.0))
		elif st.laser[i] != _laser[id]:
			set_laser(id, st.laser[i])
		if st.items[i] != _items[id] or st.sel[i] != _selected[id]:
			set_items(id, st.items[i], st.sel[i])
		set_danger(id, st.danger[i])
	scroll_label.text = st.scroll
	message.text = st.msg
	message.visible = st.msg_on
	$Hint.modulate.a = st.hint
