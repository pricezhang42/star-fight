extends PathFollow2D
## Red enemy starship that flies along its parent Path2D (a curve drawn in
## the editor), looping forever and shooting ahead and at the player.

@export var speed := 190.0
@export var health := 3
@export var fire_range := 520.0
@export var fire_cooldown := 1.5

var _cooldown := 1.0
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	loop = true
	rotates = true
	_cooldown = randf_range(0.5, fire_cooldown)


func _physics_process(delta: float) -> void:
	progress += speed * delta
	_cooldown -= delta
	var player := Alien.find_player(self)
	if player and _cooldown <= 0.0:
		var to_player := player.global_position - global_position
		if to_player.length() < fire_range:
			_cooldown = fire_cooldown
			Alien.fire(self, to_player.rotated(randf_range(-0.1, 0.1)))


func take_damage(amount: int) -> void:
	health -= amount
	Alien.hurt_flash(sprite)
	if health <= 0:
		Alien.explode(self)
