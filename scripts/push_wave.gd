extends Node2D
## The visible ripple of Luke's push: a few arcs that sweep outward and fade.

var reach := 450.0
var half_angle := 0.6
var _t := 0.0
const DURATION := 0.35


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func _draw() -> void:
	var k := _t / DURATION
	for i in 3:
		var r := reach * clampf(k - i * 0.12, 0.05, 1.0)
		var a := (1.0 - k) * (0.9 - i * 0.25)
		draw_arc(Vector2.ZERO, r, -half_angle, half_angle, 24, Color(0.6, 0.9, 1.0, a), 10.0 - i * 3.0)
