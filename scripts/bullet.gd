extends Area2D
## Laser bolt fired by a player's ship or an alien. Stops on meteors and
## comets. A player's bolt costs the other player's ship a life.
##
## Ships fire "heavy" shots (see make_heavy): they work like the comets Darth
## used to throw. Bigger and long-lived, they bounce off asteroids (knocking
## them away), fly over planets, satellites, walls and comets, are bent by
## black holes, and vanish when they hit the other ship.

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
var heavy := false
var _done := false
var _ghost_t := 0.0

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


## Turn this into a ship's heavy laser shot. Call before adding to the tree.
func make_heavy() -> void:
	heavy = true
	life = 14.0
	scale = Vector2.ONE * 1.8
	collision_mask = 1 | 2 | 32 # rocks to bounce off, ships, and missiles


func _ready() -> void:
	sprite.texture = BLUE_TEX if _blue else RED_TEX
	if heavy:
		add_to_group("bendable") # black holes bend heavy shots too
		add_to_group("player_shots") # grenades push them
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
	if heavy:
		# Short glowing streak behind the shot.
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			_spawn_ghost()


func _spawn_ghost() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.global_position = global_position
	g.rotation = sprite.global_rotation
	g.scale = sprite.global_scale
	g.modulate = Color(1, 1, 1, 0.45)
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.2)
	tw.tween_callback(g.queue_free)


func _on_body_entered(body: Node) -> void:
	if heavy and not body.is_in_group("player"):
		if body.is_in_group("rocks"):
			_bounce_off_rock(body)
		return # flies over planets, satellites and walls
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
	if heavy:
		# Shoots down the other ship's missiles; flies over comets.
		if area.is_in_group("missiles") and area.shooter != shooter:
			area.explode()
			_impact()
		return
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


## Billiard-style bounce off an asteroid: the shot reflects and keeps its
## speed, and the rock gets knocked the other way.
func _bounce_off_rock(rock_body: Node2D) -> void:
	var n := (global_position - rock_body.global_position).normalized()
	if n == Vector2.ZERO or direction.dot(n) >= 0.0:
		return # already moving away from it
	direction = direction.bounce(n)
	rotation = direction.angle()
	# Deferred: physics state can't be changed in the middle of a collision callback.
	rock_body.call_deferred("knock", -n * speed * 0.45)
	position += n * 6.0


## Black hole pull (enemy and heavy shots; see black_hole.gd).
func bend(velocity_change: Vector2) -> void:
	var v := direction * speed + velocity_change
	speed = v.length()
	direction = v / maxf(speed, 0.001)
	rotation = direction.angle()
