@tool
extends Node2D
## A black hole trap. Pulls the player toward its centre, harder the closer
## they get. Touching the core costs a life and flings the ship back out.

@export var pull_radius := 380.0:
	set(v):
		pull_radius = v
		queue_redraw()
@export var core_radius := 45.0
## Pull acceleration at the core (pixels / s^2). Fades to 0 at pull_radius.
@export var strength := 1500.0
@export var spin_speed := 0.4
## Speed the ship is thrown out at after touching the core.
@export var fling_speed := 950.0
## Seconds the ship ignores all black hole pull after being thrown out.
@export var fling_grace := 1.6

var _t := 0.0
@onready var sprite: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	_t += delta
	sprite.rotation += spin_speed * delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_bend_projectiles(delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.alive or player.gravity_grace > 0.0:
		return
	var to_center := global_position - player.global_position
	var d := to_center.length()
	if d > pull_radius or d < 0.001:
		return
	var dir := to_center / d
	var falloff := 1.0 - d / pull_radius
	player.drift += dir * strength * pow(falloff, 1.5) * delta * 2.0
	if d < core_radius:
		player.take_hit(global_position)
		player.heading = (-dir).angle()
		player.drift = -dir * fling_speed
		player.gravity_grace = fling_grace


## Comets and the hunter's bullets curve toward the hole and are swallowed by
## the core. (Luke's lasers and Darth's beam are not affected.)
func _bend_projectiles(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("bendable"):
		var to_center: Vector2 = global_position - node.global_position
		var d := to_center.length()
		if d > pull_radius:
			continue
		if d < core_radius:
			node.queue_free()
			continue
		var falloff := 1.0 - d / pull_radius
		node.bend(to_center / d * strength * pow(falloff, 1.5) * 2.0 * delta)


func _draw() -> void:
	# Faint pulsing ring that marks how far the pull reaches.
	var a := 0.12 + 0.06 * sin(_t * 2.5)
	draw_arc(Vector2.ZERO, pull_radius, 0.0, TAU, 96, Color(0.55, 0.75, 1.0, a), 3.0)
