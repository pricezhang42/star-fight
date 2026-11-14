extends Area2D
## Tracked missile: chases the other ship. Explodes on rocks, planets,
## satellites and walls; costs the target a life on a hit. Can be shot down
## by the other ship's laser.

const TEX := preload("res://assets/kenney_space_shooter_extension/spaceMissiles_004.png")
const BOOM := preload("res://assets/kenney_space_shooter_redux/lasers/laserRed08.png")
const BOOM_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_zap.ogg")

@export var speed := 450.0
@export var turn_rate := 2.6 ## radians per second
@export var lifetime := 7.0

var shooter: Node = null
var target: Node2D = null
var velocity := Vector2.ZERO
var _done := false


func setup(pos: Vector2, dir: Vector2, fired_by: Node, chase: Node2D) -> void:
	position = pos
	velocity = dir.normalized() * speed
	shooter = fired_by
	target = chase


func _ready() -> void:
	add_to_group("missiles")
	add_to_group("bendable")
	collision_layer = 32 # so lasers can shoot it down
	collision_mask = 1 | 2 # world and ships
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	var s := Sprite2D.new()
	s.texture = TEX
	s.rotation = PI / 2.0 # the sprite points up
	s.scale = Vector2.ONE * 1.6
	add_child(s)
	if shooter and shooter.player_id == 2:
		s.modulate = Color(1.0, 0.7, 0.7)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		explode()
		return
	if is_instance_valid(target) and target.alive:
		var want := (target.global_position - global_position).angle()
		var ang := rotate_toward(velocity.angle(), want, turn_rate * delta)
		velocity = Vector2.RIGHT.rotated(ang) * maxf(speed, velocity.length() * 0.98)
	position += velocity * delta
	rotation = velocity.angle()
	# A little smoke puff behind it.
	if Engine.get_physics_frames() % 3 == 0:
		Fx.flash(get_parent(), global_position - velocity.normalized() * 30.0, BOOM, 0.35, 0.25)


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body.is_in_group("player"):
		body.take_hit(global_position)
	explode()


func explode() -> void:
	if _done:
		return
	_done = true
	var scene := get_tree().current_scene
	Fx.flash(scene, global_position, BOOM, 2.4, 0.35)
	Fx.sound(scene, BOOM_SOUND, -4.0)
	queue_free()


## Black hole pull and grenade blasts.
func bend(velocity_change: Vector2) -> void:
	velocity += velocity_change
