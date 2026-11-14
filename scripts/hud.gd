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
@onready var _stamina_bars := {1: $P1Stamina, 2: $P2Stamina}

## Which ship this screen belongs to: 1 on the host (and solo), 2 on the
## joining computer. Decides whose bottom-edge warning is shown.
var local_player := 1
var _lives := {1: -1, 2: -1}
var _dash := {1: -1.0, 2: -1.0}
var _laser := {1: -1.0, 2: -1.0}
var _items := {1: [], 2: []}
var _stamina := {1: 1.0, 2: 1.0}
var _boosting := {1: false, 2: false}
var _weapon := {1: 0, 2: 0}
var _weapon_left := {1: 0.0, 2: 0.0}
var _shield := {1: 0.0, 2: 0.0}
var _selected := {1: 0, 2: 0}
var _danger := {1: 0.0, 2: 0.0}
var _solo := false


## Control help: rows of [key images..., "WHAT IT DOES"]. Key images are from
## Kenney's Input Prompts pack (CC0).
const KEYS := "res://assets/kenney_input_prompts/"
const HELP_ROWS := [
	[["keyboard_a", "keyboard_d"], "TURN", ["keyboard_w"], "THRUST", ["keyboard_s"], "BRAKE", ["keyboard_shift"], "BOOST", ["keyboard_space"], "DASH"],
	[["mouse_move"], "AIM", ["mouse_left"], "FIRE", ["mouse_right"], "POWER-UP", ["keyboard_tab"], "SWITCH", ["keyboard_escape"], "PAUSE"],
]

signal resume_pressed
signal exit_pressed


func _ready() -> void:
	_build_help()
	$PauseMenu/Center/Box/Resume.pressed.connect(func(): resume_pressed.emit())
	$PauseMenu/Center/Box/Exit.pressed.connect(func(): exit_pressed.emit())
	var font: Font = scroll_label.label_settings.font
	for b in [$PauseMenu/Center/Box/Resume, $PauseMenu/Center/Box/Exit]:
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 26)
	# Fade the control help out after the first 15 seconds of a run.
	var tw := $Hint.create_tween()
	tw.tween_interval(15.0)
	tw.tween_property($Hint, "modulate:a", 0.0, 1.5)


## Solo practice: hide the red ship's side of the HUD.
func set_solo(solo: bool) -> void:
	_solo = solo
	for node in [$P2Label, $P2Lives, $P2Dash, $P2Laser, $P2Items, $P2Stamina]:
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
		label.text = "DASH READY - SPACE"
		label.modulate = Color(0.6, 0.9, 1.0)
	else:
		label.text = "DASH %d%%" % int(ready_fraction * 100.0)
		label.modulate = Color(0.6, 0.7, 0.8, 0.7)


## 0..1 how recharged that ship's laser is (1 = ready).
func set_laser(id: int, ready_fraction: float) -> void:
	_laser[id] = ready_fraction
	var label: Label = _laser_labels[id]
	var wname: String = PowerUps.WEAPON_NAMES[_weapon[id]]
	if _weapon[id] != 0:
		wname += " %ds" % ceili(_weapon_left[id])
	var extra := ("   SHIELD %ds" % ceili(_shield[id])) if _shield[id] > 0.0 else ""
	if ready_fraction >= 1.0:
		label.text = wname + " READY" + extra
		label.modulate = Color(1.0, 0.9, 0.5) if _weapon[id] == 0 else Color(1.0, 0.6, 0.3)
	else:
		label.text = "%s %d%%%s" % [wname, int(ready_fraction * 100.0), extra]
		label.modulate = Color(0.8, 0.75, 0.6, 0.7)


## Weapon pickup in use and Shield time, shown on that ship's laser line.
func set_loadout(id: int, weapon: int, weapon_left: float, shield_left: float) -> void:
	_weapon[id] = weapon
	_weapon_left[id] = weapon_left
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


## Boost stamina bar, 0..1 (brighter while boosting).
func set_stamina(id: int, fraction: float, boosting: bool) -> void:
	_stamina[id] = fraction
	_boosting[id] = boosting
	var bar: Control = _stamina_bars[id]
	var fill: ColorRect = bar.get_node("Fill")
	var inner := bar.size.x - 4.0
	fill.size.x = inner * clampf(fraction, 0.0, 1.0)
	if id == 2:
		fill.position.x = 2.0 + inner - fill.size.x # red bar drains toward the right edge
	var base := Color(0.45, 0.85, 1.0) if id == 1 else Color(1.0, 0.6, 0.5)
	fill.color = base.lightened(0.35) if boosting else (base if fraction > 0.25 else Color(1.0, 0.35, 0.3))


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
		"stamina": [_stamina[1], _stamina[2]],
		"boosting": [_boosting[1], _boosting[2]],
		"weapon": [_weapon[1], _weapon[2]],
		"weapon_left": [_weapon_left[1], _weapon_left[2]],
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
		if st.weapon[i] != _weapon[id] or st.shield[i] != _shield[id] or st.weapon_left[i] != _weapon_left[id]:
			_weapon[id] = st.weapon[i]
			_weapon_left[id] = st.weapon_left[i]
			_shield[id] = st.shield[i]
			set_laser(id, maxf(st.laser[i], 0.0))
		elif st.laser[i] != _laser[id]:
			set_laser(id, st.laser[i])
		set_stamina(id, st.stamina[i], st.boosting[i])
		if st.items[i] != _items[id] or st.sel[i] != _selected[id]:
			set_items(id, st.items[i], st.sel[i])
		set_danger(id, st.danger[i])
	scroll_label.text = st.scroll
	message.text = st.msg
	message.visible = st.msg_on
	$Hint.modulate.a = st.hint



func _build_help() -> void:
	var ls := LabelSettings.new()
	ls.font = scroll_label.label_settings.font
	ls.font_size = 20
	ls.outline_size = 4
	ls.outline_color = Color.BLACK
	for row in HELP_ROWS:
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 6)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for item in row:
			if item is Array:
				for key in item:
					var icon := TextureRect.new()
					icon.texture = load(KEYS + key + ".png")
					icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon.custom_minimum_size = Vector2(42, 42)
					line.add_child(icon)
			else:
				var label := Label.new()
				label.text = item
				label.label_settings = ls
				label.custom_minimum_size = Vector2(0, 42)
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				line.add_child(label)
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(26, 0)
				line.add_child(gap)
		$Hint.add_child(line)


## Pause menu. `by` names who paused ("" in solo practice).
func show_pause(on: bool, by: String) -> void:
	$PauseMenu.visible = on
	# The big centre message (GET READY / game over) would show through the menu.
	message.self_modulate.a = 0.0 if on else 1.0
	$PauseMenu/Center/Box/By.text = ("PAUSED BY " + by) if by != "" else ""
