extends Area2D
## Laser bolt fired by the player or an alien. Stops on meteors and comets.

const PLAYER_TEX := preload("res://assets/kenney_space_shooter_redux/lasers/laserBlue01.png")
const ALIEN_TEX := preload("res://assets/kenney_space_shooter_redux/lasers/laserRed01.png")
const PLAYER_HIT := preload("res://assets/kenney_space_shooter_redux/lasers/laserBlue08.png")
const ALIEN_HIT := preload("res://assets/kenney_space_shooter_redux/lasers/laserRed08.png")

# Collision layers: 1 world, 2 player, 4 alien bodies, 8 alien hurtboxes, 16 comets.
const PLAYER_MASK := 1 | 8 | 16
const ALIEN_MASK := 1 | 2 | 16

var direction := Vector2.RIGHT
var speed := 900.0
var from_player := true
var life := 1.4
var _done := false

@onready var sprite: Sprite2D = $Sprite2D


## Call before adding to the tree.
func setup(pos: Vector2, dir: Vector2, player_owned: bool, bolt_speed: float) -> void:
	position = pos
	direction = dir.normalized()
	from_player = player_owned
	speed = bolt_speed
	rotation = direction.angle()
	collision_layer = 0
	collision_mask = PLAYER_MASK if player_owned else ALIEN_MASK


func _ready() -> void:
	sprite.texture = PLAYER_TEX if from_player else ALIEN_TEX
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if not from_player:
			body.take_hit(global_position - direction * 40.0)
			_impact()
	else:
		# Solid object: rock, planet or satellite. Hostile satellites take damage.
		if from_player and body.has_method("take_damage"):
			body.take_damage(1)
		_impact()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("alien_hurtbox"):
		if from_player:
			area.get_parent().take_damage(1)
			_impact()
	elif area.is_in_group("comets"):
		_impact()


func _impact() -> void:
	if _done:
		return
	_done = true
	Fx.flash(get_parent(), global_position, PLAYER_HIT if from_player else ALIEN_HIT, 0.7, 0.15)
	queue_free()
