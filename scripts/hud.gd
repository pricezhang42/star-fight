extends CanvasLayer

const LIFE_ICON := preload("res://assets/kenney_space_shooter_redux/ui/playerLife1_blue.png")

@onready var lives_box: HBoxContainer = $Lives
@onready var distance_label: Label = $Distance
@onready var message: Label = $Message
@onready var p2_label: Label = $P2

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
	p2_label.text = "ALIEN  HITS %d   %s" % [_p2_hits, state]
	p2_label.modulate = Color(0.6, 1.0, 0.6) if _p2_ready >= 1.0 else Color(0.6, 0.8, 0.6, 0.7)
