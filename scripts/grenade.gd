extends Node2D
## Grenade: flies to the point it was thrown at and explodes there, pushing
## everything nearby outwards: ships, rocks, comets, missiles and shots.
## It does no damage.

const TEX := preload("res://assets/kenney_space_shooter_redux/powerups/powerupBlue_star.png")
const FLASH := preload("res://assets/kenney_space_shooter_redux/lasers/laserBlue08.png")
const BOOM_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_twoTone.ogg")

@export var speed := 650.0
@export var blast_radius := 450.0
@export var ship_push := 750.0
@export var rock_push := 650.0

var _target := Vector2.ZERO
var _exploded := false
var _ring_t := -1.0
var _sprite: Sprite2D


func setup(pos: Vector2, target: Vector2) -> void:
	position = pos
	_target = target


func _ready() -> void:
	z_index = 30
	add_to_group("net_draw")
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.scale = Vector2.ONE * 1.8
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if _exploded:
		_ring_t += delta
		queue_redraw()
		if _ring_t > 0.45:
			queue_free()
		return
	var to := _target - global_position
	var step := speed * delta
	_sprite.rotation += 8.0 * delta
	if to.length() <= step:
		global_position = _target
		_explode()
	else:
		global_position += to.normalized() * step


func _explode() -> void:
	_exploded = true
	_ring_t = 0.0
	_sprite.visible = false
	var scene := get_tree().current_scene
	Fx.flash(scene, global_position, FLASH, 6.0, 0.35)
	Fx.sound(scene, BOOM_SOUND, 0.0)
	var c := global_position
	for ship in get_tree().get_nodes_in_group("player"):
		var k := _falloff(ship.global_position)
		if k > 0.0:
			ship.drift += _away(ship.global_position) * ship_push * k
	for rock in get_tree().get_nodes_in_group("rocks"):
		var k := _falloff(rock.global_position)
		if k > 0.0:
			rock.knock(_away(rock.global_position) * rock_push * k)
	# Comets, missiles and shots all have bend(velocity_change).
	for group in ["comets", "missiles", "player_shots", "enemy_bullets"]:
		for node in get_tree().get_nodes_in_group(group):
			var k := _falloff(node.global_position)
			if k > 0.0 and node.has_method("bend"):
				node.bend(_away(node.global_position) * rock_push * k)


func _falloff(p: Vector2) -> float:
	var d := p.distance_to(global_position)
	if d > blast_radius:
		return 0.0
	return lerpf(1.0, 0.3, d / blast_radius)


func _away(p: Vector2) -> Vector2:
	var v := p - global_position
	return v.normalized() if v.length() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)


func _ring() -> Array:
	var k := clampf(_ring_t / 0.45, 0.0, 1.0)
	return [blast_radius * k, Color(0.6, 0.85, 1.0, 1.0 - k)]


## Blast ring for the other computer in LAN play (see NetMirror).
func net_draw_commands() -> Array:
	if not _exploded:
		return []
	var r: Array = _ring()
	return [["arc", global_position, r[0], 0.0, TAU, r[1], 14.0]]


func _draw() -> void:
	if _exploded:
		var r: Array = _ring()
		draw_arc(Vector2.ZERO, r[0], 0.0, TAU, 64, r[1], 14.0)
