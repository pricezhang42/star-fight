@tool
extends AnimatableBody2D
## A satellite circling its parent (usually a Planet). It is solid: the ship
## bounces off it and loses a life. When `hostile` is on, it also shoots at
## the player and can be destroyed.

@export var orbit_radius := 280.0:
	set(v):
		orbit_radius = v
		_place()
@export var angle := 0.0: ## current orbit angle in radians
	set(v):
		angle = v
		_place()
@export var orbit_speed := 0.5 ## radians per second (negative = clockwise)
@export var hostile := false
@export var health := 4
@export var fire_range := 620.0
@export var fire_cooldown := 1.6

var _cooldown := 1.0

const PASSIVE_TEX := preload("res://assets/kenney_space_shooter_extension/spaceStation_018.png")
const HOSTILE_TEX := preload("res://assets/kenney_space_shooter_extension/spaceStation_019.png")

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_place()
	sprite.texture = HOSTILE_TEX if hostile else PASSIVE_TEX
	sprite.modulate = Color(1.0, 0.55, 0.5) if hostile else Color.WHITE
	if not Engine.is_editor_hint():
		_cooldown = randf_range(0.5, fire_cooldown)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	angle += orbit_speed * delta
	if not hostile:
		return
	_cooldown -= delta
	var player := Alien.find_player(self)
	if player and _cooldown <= 0.0:
		var to_player := player.global_position - global_position
		if to_player.length() < fire_range:
			_cooldown = fire_cooldown
			Alien.fire(self, to_player, 80.0)


func _place() -> void:
	position = Vector2.RIGHT.rotated(angle) * orbit_radius
	rotation = angle + PI / 2.0 # solar panels along the orbit


func take_damage(amount: int) -> void:
	if not hostile:
		return
	health -= amount
	Alien.hurt_flash(sprite)
	if health <= 0:
		Alien.explode(self)
