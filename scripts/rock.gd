extends RigidBody2D
## One asteroid. Belt rocks start frozen in place; a dash or another
## knock sets them loose and they drift to a stop. "Moving" asteroids drift
## and bounce forever. Lasers break them. Touching one costs Luke a life.

const DEBRIS := [
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_tiny1.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_tiny1.png"),
]
const BREAK_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_zap.ogg")

@export var texture: Texture2D
@export var radius := 38.0
@export var sprite_scale := 1.0
@export var hp := 3
## A moving asteroid: starts loose with `start_velocity` and never slows down.
@export var moving := false
@export var start_velocity := Vector2.ZERO
## Moving asteroids are gently slowed back down to this speed after a knock.
@export var cruise_speed := 150.0

var loose := false
var _sprite: Sprite2D
var _material: PhysicsMaterial


func _ready() -> void:
	add_to_group("rocks")
	gravity_scale = 0.0
	collision_layer = 1 # counts as "world": Luke bounces off it
	collision_mask = 1 | 2 # other rocks, planets, satellites, border; and Luke
	mass = maxf(0.3, radius * radius / 900.0)
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	_material = PhysicsMaterial.new()
	_material.bounce = 0.6
	_material.friction = 0.1
	physics_material_override = _material

	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.scale = Vector2.ONE * sprite_scale
	add_child(_sprite)

	body_entered.connect(_on_body_entered)
	if moving:
		_set_loose()
		_material.bounce = 1.0
		_material.friction = 0.0
		linear_damp = 0.0
		angular_damp = 0.0
		linear_velocity = start_velocity
		angular_velocity = randf_range(-1.5, 1.5)
	else:
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true


func _physics_process(delta: float) -> void:
	if moving and linear_velocity.length() > cruise_speed:
		linear_velocity *= 1.0 - 1.2 * delta


func _set_loose() -> void:
	loose = true
	freeze = false
	contact_monitor = true
	max_contacts_reported = 4
	if not moving:
		linear_damp = 0.9
		angular_damp = 0.6


## Shove the rock: `velocity_change` is added to its velocity.
func knock(velocity_change: Vector2) -> void:
	if not loose:
		_set_loose()
	sleeping = false
	linear_velocity += velocity_change
	angular_velocity += randf_range(-2.0, 2.0)


func take_damage(amount: int) -> void:
	hp -= amount
	if _sprite:
		_sprite.modulate = Color(2.5, 2.5, 2.5)
		_sprite.create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	if hp <= 0:
		shatter()


func shatter() -> void:
	if is_queued_for_deletion():
		return
	var scene := get_tree().current_scene
	# A few tiny fragments fly out and fade.
	for i in 4:
		var d := Sprite2D.new()
		d.texture = DEBRIS[randi() % DEBRIS.size()]
		d.position = global_position
		d.rotation = randf() * TAU
		scene.add_child(d)
		var dir := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 110.0) * (radius / 38.0)
		var tw := d.create_tween().set_parallel()
		tw.tween_property(d, "position", d.position + dir, 0.5)
		tw.tween_property(d, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(d.queue_free)
	Fx.sound(scene, BREAK_SOUND, -14.0)
	queue_free()


func _on_body_entered(body: Node) -> void:
	# A loose rock drifting into Luke hurts him too.
	if body.is_in_group("player") and body.has_method("take_hit"):
		body.take_hit(global_position)
