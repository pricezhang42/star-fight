extends CharacterBody2D
## Alien that hovers at its spawn point and chases the player once they come
## close, shooting when the player is in front of it. Gives up and returns
## home if the player gets far enough away.

@export var speed := 165.0
@export var turn_speed := 2.6
@export var detect_radius := 480.0
@export var lose_radius := 780.0
@export var health := 2
@export var fire_range := 520.0
@export var fire_cooldown := 1.3

var heading := 0.0
var chasing := false
var home := Vector2.ZERO
var _cooldown := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	home = global_position
	heading = rotation
	_cooldown = randf_range(0.5, fire_cooldown)


func _physics_process(delta: float) -> void:
	var player := Alien.find_player(self)
	if player:
		var d := global_position.distance_to(player.global_position)
		chasing = d < (lose_radius if chasing else detect_radius)
	else:
		chasing = false

	var to_target := (player.global_position if chasing else home) - global_position
	var spd := speed
	if not chasing:
		# Drift back home, slowing down as we arrive.
		spd = minf(speed * 0.5, to_target.length() * 2.0)
	if to_target.length() > 2.0:
		heading = rotate_toward(heading, to_target.angle(), turn_speed * delta)
	velocity = Vector2.RIGHT.rotated(heading) * spd
	rotation = heading
	move_and_slide()

	_cooldown -= delta
	if chasing and _cooldown <= 0.0 and to_target.length() < fire_range \
			and absf(angle_difference(heading, to_target.angle())) < 0.35:
		_cooldown = fire_cooldown
		Alien.fire(self, Vector2.RIGHT.rotated(heading))


func take_damage(amount: int) -> void:
	health -= amount
	Alien.hurt_flash(sprite)
	chasing = true # getting shot makes it angry
	if health <= 0:
		Alien.explode(self)
