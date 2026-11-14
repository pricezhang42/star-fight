extends Area2D
## Laser bolt fired by a player's ship or an alien. Stops on meteors and
## comets. A player's bolt costs the other player's ship a life.

const BLUE_TEX := preload("res://assets/kenney_space_shooter_redux/lasers/laserBlue01.png")
const RED_TEX := preload("res://assets/kenney_space_shooter_redux/lasers/laserRed01.png")
const BLUE_HIT := preload("res://assets/kenney_space_shooter_redux/lasers/laserBlue08.png")
const RED_HIT := preload("res://assets/kenney_space_shooter_redux/lasers/laserRed08.png")

# Collision layers: 1 world, 2 player, 4 alien bodies, 8 alien hurtboxes, 16 comets.
const PLAYER_MASK := 1 | 2 | 8 | 16
const ALIEN_MASK := 1 | 2 | 16

var direction := Vector2.RIGHT
var speed := 900.0
var from_player := true
## The ship that fired this bolt (null for aliens). It can't hit its own ship.
var shooter: Node = null
var _blue := true
var life := 1.4
var _done := false

@onready var sprite: Sprite2D = $Sprite2D


## Call before adding to the tree.
## `fired_by` is the player's ship, or null for an alien's bolt.
func setup(pos: Vector2, dir: Vector2, fired_by: Node, bolt_speed: float) -> void:
	position = pos
	direction = dir.normalized()
	shooter = fired_by
	from_player = fired_by != null
	_blue = from_player and fired_by.player_id == 1
	speed = bolt_speed
	rotation = direction.angle()
	collision_layer = 0
	collision_mask = PLAYER_MASK if from_player else ALIEN_MASK


func _ready() -> void:
	sprite.texture = BLUE_TEX if _blue else RED_TEX
	if not from_player:
		add_to_group("enemy_bullets")
		add_to_group("bendable") # black holes bend enemy shots, not the players'
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body != shooter:
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
	Fx.flash(get_parent(), global_position, BLUE_HIT if _blue else RED_HIT, 0.7, 0.15)
	queue_free()


## Black hole pull (enemy bullets only; see black_hole.gd).
func bend(velocity_change: Vector2) -> void:
	var v := direction * speed + velocity_change
	speed = v.length()
	direction = v / maxf(speed, 0.001)
	rotation = direction.angle()
