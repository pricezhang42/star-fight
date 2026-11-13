extends Node2D
## Darth's Laser: a thin flashing warning line first, then a thick beam along
## the same line that costs Luke a life if it touches him. Passes through
## everything.

signal hit_luke

const BEAM_TEX := preload("res://assets/kenney_space_shooter_redux/lasers/laserRed01.png")
const FIRE_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_laser2.ogg")

@export var warn_time := 1.0
@export var fire_time := 0.4
@export var length := 6000.0
@export var beam_width := 70.0

var direction := Vector2.RIGHT
var _t := 0.0
var _fired := false
var _hit := false
var _beam: Sprite2D


func setup(origin: Vector2, dir: Vector2) -> void:
	position = origin
	direction = dir.normalized()
	rotation = direction.angle()


func _ready() -> void:
	z_index = 40
	_beam = Sprite2D.new()
	_beam.texture = BEAM_TEX
	_beam.rotation = PI / 2.0 # the sprite is vertical
	_beam.centered = true
	_beam.position = Vector2(length / 2.0, 0)
	_beam.scale = Vector2(beam_width / BEAM_TEX.get_width(), length / BEAM_TEX.get_height())
	_beam.visible = false
	add_child(_beam)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not _fired and _t >= warn_time:
		_fired = true
		_beam.visible = true
		Fx.sound(get_tree().current_scene, FIRE_SOUND, 2.0)
	if _fired:
		var k := (_t - warn_time) / fire_time
		_beam.modulate.a = 1.0 - k * k
		_check_hit()
	if _t >= warn_time + fire_time:
		queue_free()


func _check_hit() -> void:
	if _hit:
		return
	var luke := get_tree().get_first_node_in_group("player") as Node2D
	if luke == null or not luke.alive:
		return
	var a := global_position
	var b := a + direction * length
	var closest := Geometry2D.get_closest_point_to_segment(luke.global_position, a, b)
	var reach: float = beam_width * 0.5 + 20.0 * luke.size_mult
	if luke.global_position.distance_to(closest) < reach:
		_hit = true
		var before: int = luke.lives
		luke.take_hit(closest)
		if luke.lives < before:
			hit_luke.emit()


func _draw() -> void:
	if _fired:
		return
	# Flashing warning line that gets more urgent as the shot approaches.
	var urgency := _t / warn_time
	var blink := 0.5 + 0.5 * sin(_t * lerpf(14.0, 40.0, urgency))
	var col := Color(1.0, 0.2, 0.2, lerpf(0.25, 0.9, blink))
	draw_line(Vector2.ZERO, Vector2(length, 0), col, lerpf(6.0, 16.0, urgency))
