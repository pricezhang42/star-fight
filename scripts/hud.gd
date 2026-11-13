extends CanvasLayer

const LIFE_ICON := preload("res://assets/kenney_space_shooter_redux/ui/playerLife1_blue.png")

@onready var lives_box: HBoxContainer = $Lives
@onready var distance_label: Label = $Distance
@onready var message: Label = $Message
@onready var p2_label: Label = $P2
@onready var items_box: HBoxContainer = $Items
@onready var luke_status: Label = $LukeStatus
@onready var dash_label: Label = $Dash

const ITEM_ICONS := [
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupYellow_bolt.png"), # chaos
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupBlue_star.png"), # flash bang
	preload("res://assets/kenney_space_shooter_redux/enemies/enemyBlack1.png"), # hunter
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupRed_bolt.png"), # laser
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupGreen_shield.png"), # giant
	preload("res://assets/kenney_space_shooter_redux/powerups/pill_blue.png"), # slick
]
const ITEM_NAMES := ["CHAOS", "FLASH", "HUNTER", "LASER", "GIANT", "SLICK"]

var _p2_hits := 0
var _p2_ready := 0.0


func set_lives(n: int) -> void:
	for c in lives_box.get_children():
		c.queue_free()
	for i in n:
		var icon := TextureRect.new()
		icon.texture = LIFE_ICON
		lives_box.add_child(icon)


func set_score(score: int, best: int) -> void:
	distance_label.text = "SCORE %d\nBEST %d" % [score, best]


func show_message(text: String) -> void:
	message.text = text
	message.visible = true


func set_p2_hits(hits: int) -> void:
	_p2_hits = hits
	_update_p2()


func set_p2_cooldown(ready_fraction: float) -> void:
	_p2_ready = ready_fraction
	_update_p2()


func _update_p2() -> void:
	var state := "COMET READY - CLICK" if _p2_ready >= 1.0 else "RECHARGING %d%%" % int(_p2_ready * 100.0)
	p2_label.text = "DARTH  HITS %d   %s" % [_p2_hits, state]
	p2_label.modulate = Color(0.6, 1.0, 0.6) if _p2_ready >= 1.0 else Color(0.6, 0.8, 0.6, 0.7)


## Darth's item slots: icon + name, the selected one highlighted.
func set_items(items: Array, selected: int) -> void:
	for c in items_box.get_children():
		c.queue_free()
	for i in items.size():
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.texture = ITEM_ICONS[items[i]]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(34, 34)
		slot.add_child(icon)
		var name_label := Label.new()
		name_label.text = ITEM_NAMES[items[i]]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ls := LabelSettings.new()
		ls.font = p2_label.label_settings.font
		ls.font_size = 13
		ls.outline_size = 3
		ls.outline_color = Color.BLACK
		name_label.label_settings = ls
		slot.add_child(name_label)
		slot.modulate = Color(1, 1, 1, 1) if i == selected else Color(1, 1, 1, 0.45)
		if i == selected:
			icon.custom_minimum_size = Vector2(44, 44)
		items_box.add_child(slot)


## Warnings on Luke's side when Darth's effects are active.
func set_luke_status(reversed: bool, giant: bool, slick: bool = false) -> void:
	var parts := []
	if reversed:
		parts.append("CONTROLS REVERSED!")
	if giant:
		parts.append("GIANT SHIP!")
	if slick:
		parts.append("SLIPPERY STEERING!")
	luke_status.text = "   ".join(parts)


func set_dash(ready_fraction: float) -> void:
	if ready_fraction >= 1.0:
		dash_label.text = "DASH READY - SHIFT"
		dash_label.modulate = Color(0.6, 0.9, 1.0)
	else:
		dash_label.text = "DASH %d%%" % int(ready_fraction * 100.0)
		dash_label.modulate = Color(0.6, 0.7, 0.8, 0.7)
