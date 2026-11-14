extends Area2D
## A burning comet that streaks across the screen. Hurts the player on contact
## and blocks lasers. Freed once it leaves the play area.

var velocity := Vector2.ZERO
var spin := 0.0
var _age := 0.0

@onready var rock: Sprite2D = $Rock
@onready var trail: CPUParticles2D = $Trail


func setup(pos: Vector2, vel: Vector2, rock_scale: float) -> void:
	position = pos
	velocity = vel
	spin = randf_range(-3.0, 3.0)
	scale = Vector2.ONE * rock_scale


func _ready() -> void:
	add_to_group("comets")
	add_to_group("bendable")
	# Point the fire trail backwards.
	trail.direction = -velocity.normalized()
	trail.add_to_group("net_particles")


func _physics_process(delta: float) -> void:
	position += velocity * delta
	rock.rotation += spin * delta
	_age += delta
	if _age > 14.0:
		queue_free()
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_hit(global_position)


## Black hole pull (see black_hole.gd).
func bend(velocity_change: Vector2) -> void:
	velocity += velocity_change
	trail.direction = -velocity.normalized()
