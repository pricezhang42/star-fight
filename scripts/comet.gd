extends Area2D
## A burning comet that streaks across the screen. Hurts the player on contact
## and blocks lasers. Freed once it leaves the play area.
## Comets thrown by Darth also bounce off asteroids, knocking them away.

var velocity := Vector2.ZERO
## Player 2 (alien astronaut) if they threw this comet, so hits can be scored.
var thrower: Node = null
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
	if thrower:
		# Thrown comets also see the world layer, so they can bounce off rocks.
		collision_mask |= 1
		# Thrown comets burn green so you can tell them apart.
		rock.modulate = Color(0.75, 1.0, 0.75)
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(0.7, 1.0, 0.5, 1.0), Color(0.1, 0.8, 0.3, 0.0)])
		trail.color_ramp = ramp


func _physics_process(delta: float) -> void:
	position += velocity * delta
	rock.rotation += spin * delta
	_age += delta
	if _age > 14.0:
		queue_free()
	for body in get_overlapping_bodies():
		if thrower and body.is_in_group("rocks"):
			_bounce_off_rock(body)
			continue
		if body.is_in_group("player"):
			var before: int = body.lives
			body.take_hit(global_position)
			if body.lives < before and is_instance_valid(thrower):
				thrower.scored_hit()


## Black hole pull (see black_hole.gd).
func bend(velocity_change: Vector2) -> void:
	velocity += velocity_change
	trail.direction = -velocity.normalized()


## Billiard-style bounce off an asteroid: the comet reflects and keeps its
## speed, and the rock gets knocked the other way.
func _bounce_off_rock(rock_body: Node2D) -> void:
	var n := (global_position - rock_body.global_position).normalized()
	if n == Vector2.ZERO or velocity.dot(n) >= 0.0:
		return # already moving away from it
	var speed := velocity.length()
	velocity = velocity.bounce(n)
	trail.direction = -velocity.normalized()
	rock_body.knock(-n * speed * 0.45)
	# Step out of the rock so the next frame doesn't count it again.
	position += n * 6.0
