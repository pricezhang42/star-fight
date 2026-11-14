extends Area2D
## Rocket weapon: a slower shot that explodes. It blows up when it touches
## anything solid, a ship (other than the one that fired it) or an NPC, or
## after flying `max_range`. The blast costs any ship inside it a life
## (including the shooter's own), destroys rocks, damages NPCs and pushes
## things outward a little.

const TEX := preload("res://assets/kenney_space_shooter_extension/spaceMissiles_001.png")
const BOOM := preload("res://assets/kenney_space_shooter_redux/lasers/laserRed08.png")
const BOOM_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_zap.ogg")

@export var speed := 450.0
@export var max_range := 1200.0
@export var blast_radius := 220.0
@export var push := 300.0

var shooter: Node = null
var velocity := Vector2.ZERO
var _travelled := 0.0
var _done := false
var _ring_t := -1.0
var _sprite: Sprite2D


func setup(pos: Vector2, dir: Vector2, fired_by: Node) -> void:
	position = pos
	velocity = dir.normalized() * speed
	shooter = fired_by
	rotation = velocity.angle()


func _ready() -> void:
	add_to_group("missiles") # lasers can shoot it down; grenades push it
	add_to_group("bendable")
	add_to_group("net_draw")
	collision_layer = 32
	collision_mask = 1 | 2 | 8 # solids, ships, NPC hitboxes
	var shape := CircleShape2D.new()
	shape.radius = 26.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.rotation = PI / 2.0 # the sprite points up
	_sprite.scale = Vector2.ONE * 1.6
	if shooter and shooter.player_id == 2:
		_sprite.modulate = Color(1.0, 0.7, 0.7)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _done:
		_ring_t += delta
		queue_redraw()
		if _ring_t > 0.4:
			queue_free()
		return
	var step := velocity * delta
	position += step
	rotation = velocity.angle()
	_travelled += step.length()
	if Engine.get_physics_frames() % 3 == 0:
		Fx.flash(get_parent(), global_position - velocity.normalized() * 34.0, BOOM, 0.4, 0.25)
	if _travelled >= max_range:
		explode()


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return # doesn't go off on its own ship at launch
	explode()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("alien_hurtbox"):
		explode()


func explode() -> void:
	if _done:
		return
	_done = true
	_ring_t = 0.0
	_sprite.visible = false
	set_deferred("monitoring", false)
	var scene := get_tree().current_scene
	Fx.flash(scene, global_position, BOOM, 5.0, 0.4)
	Fx.sound(scene, BOOM_SOUND, 0.0)
	for ship in get_tree().get_nodes_in_group("player"):
		if ship.alive and ship.global_position.distance_to(global_position) < blast_radius + ship.BASE_RADIUS * ship.size_mult:
			ship.take_hit(global_position)
			ship.drift += _away(ship.global_position) * push
	for rock in get_tree().get_nodes_in_group("rocks"):
		if rock.global_position.distance_to(global_position) < blast_radius + rock.radius:
			rock.call_deferred("shatter")
	for hb in get_tree().get_nodes_in_group("alien_hurtbox"):
		if hb.global_position.distance_to(global_position) < blast_radius + 40.0:
			hb.get_parent().take_damage(4)
	for body in get_tree().root.find_children("*", "AnimatableBody2D", true, false):
		if body.has_method("take_damage") and body.get("hostile") and body.global_position.distance_to(global_position) < blast_radius + 50.0:
			body.take_damage(2)


func _away(p: Vector2) -> Vector2:
	var v := p - global_position
	return v.normalized() if v.length() > 0.01 else Vector2.RIGHT


## Black hole pull and grenade blasts.
func bend(velocity_change: Vector2) -> void:
	velocity += velocity_change


func _ring() -> Array:
	var k := clampf(_ring_t / 0.4, 0.0, 1.0)
	return [blast_radius * k, Color(1.0, 0.6, 0.3, 1.0 - k)]


## Blast ring for the other computer in LAN play (see NetMirror).
func net_draw_commands() -> Array:
	if not _done:
		return []
	var r: Array = _ring()
	return [["arc", global_position, r[0], 0.0, TAU, r[1], 12.0]]


func _draw() -> void:
	if _done:
		var r: Array = _ring()
		draw_arc(Vector2.ZERO, r[0], 0.0, TAU, 48, r[1], 12.0)
