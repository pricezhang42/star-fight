extends CharacterBody2D
## Luke's starship (player 1). A/D rotate the ship, W/S speed up and brake.
## The ship always keeps drifting forward at its current speed.
## Darth's items can reverse the controls (chaos) or make it bigger (giant).

signal lives_changed(lives: int)
signal died
## Emitted when chaos / giant start or end, for the HUD.
signal status_changed(reversed: bool, giant: bool)

@export var speed := 220.0 ## starting / current speed
@export var min_speed := 60.0
@export var max_speed := 340.0
@export var acceleration := 220.0 ## speed gained per second while holding W
@export var brake_force := 420.0 ## speed lost per second while holding S
@export var turn_speed := 3.2 ## radians per second
@export var max_lives := 5
@export var invulnerable_time := 1.5
@export var fire_cooldown := 0.22
@export var bullet_speed := 900.0
## How fast outside pushes (black hole pull, knockback) fade, per second.
@export var drift_damping := 1.6

const BULLET := preload("res://scenes/bullet.tscn")
const SHOOT_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_laser1.ogg")

var lives := 0
## Extra velocity from outside forces such as black holes.
var drift := Vector2.ZERO
## While above 0, black holes don't pull the ship (set after being flung out).
var gravity_grace := 0.0
var _fire_cd := 0.0
var heading := 0.0
var alive := true
var _invuln := 0.0
var _flame_t := 0.0
## Seconds left with A/D and W/S swapped (Darth's Chaos item).
var chaos_time := 0.0
## Seconds left at giant size (Darth's Giant item).
var giant_time := 0.0
## Current size multiplier (eases between 1 and giant_scale).
var size_mult := 1.0
const GIANT_SCALE := 2.0
const BASE_RADIUS := 20.0
var _base_sprite_scale := Vector2.ONE
var _base_flame_pos := Vector2.ZERO
var _was_reversed := false
var _was_giant := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var flame: Sprite2D = $Flame
@onready var shield: Sprite2D = $Shield
@onready var hit_sound: AudioStreamPlayer = $HitSound


func _ready() -> void:
	add_to_group("player")
	lives = max_lives
	heading = rotation
	shield.visible = false
	_base_sprite_scale = sprite.scale
	_base_flame_pos = flame.position
	# Own copy of the collision circle so it can grow.
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()


func _physics_process(delta: float) -> void:
	if not alive:
		return

	var reversed := chaos_time > 0.0
	var turn := Input.get_axis("turn_left", "turn_right")
	var go := Input.is_action_pressed("thrust")
	var stop_ := Input.is_action_pressed("brake")
	if reversed:
		turn = -turn
		var tmp := go
		go = stop_
		stop_ = tmp
	heading += turn * turn_speed * delta
	if go:
		speed += acceleration * delta
	if stop_:
		speed -= brake_force * delta
	speed = clampf(speed, min_speed, max_speed)
	rotation = heading
	gravity_grace -= delta
	drift *= exp(-drift_damping * delta)
	velocity = Vector2.RIGHT.rotated(heading) * speed + drift

	var col := move_and_collide(velocity * delta)
	if col:
		# Bounce off the barrier and take damage.
		var n := col.get_normal()
		heading = Vector2.RIGHT.rotated(heading).bounce(n).angle()
		drift = drift.bounce(n) * 0.5
		rotation = heading
		position += n * 8.0
		take_hit()

	_fire_cd -= delta
	if Input.is_action_pressed("fire") and _fire_cd <= 0.0:
		_fire_cd = fire_cooldown
		_shoot()

	_update_effects(delta)


func _shoot() -> void:
	var dir := Vector2.RIGHT.rotated(heading)
	var b := BULLET.instantiate()
	b.setup(global_position + dir * 36.0, dir, true, bullet_speed + speed)
	get_tree().current_scene.add_child(b)
	Fx.sound(get_tree().current_scene, SHOOT_SOUND, -8.0)


func _update_effects(delta: float) -> void:
	# Darth's effects.
	chaos_time = maxf(0.0, chaos_time - delta)
	giant_time = maxf(0.0, giant_time - delta)
	var target := GIANT_SCALE if giant_time > 0.0 else 1.0
	size_mult = move_toward(size_mult, target, delta * 4.0)
	sprite.scale = _base_sprite_scale * size_mult
	shield.scale = _base_sprite_scale * size_mult
	flame.position = _base_flame_pos * size_mult
	($CollisionShape2D.shape as CircleShape2D).radius = BASE_RADIUS * size_mult
	var tint := Color(0.85, 0.45, 1.0) if chaos_time > 0.0 else Color.WHITE
	sprite.modulate = Color(tint, sprite.modulate.a)
	var reversed := chaos_time > 0.0
	var giant := giant_time > 0.0
	if reversed != _was_reversed or giant != _was_giant:
		_was_reversed = reversed
		_was_giant = giant
		status_changed.emit(reversed, giant)

	_flame_t += delta * 30.0
	var throttle := inverse_lerp(min_speed, max_speed, speed)
	flame.scale = Vector2(0.8 + 0.4 * throttle, (0.6 + 1.2 * throttle) * (1.0 + 0.2 * sin(_flame_t))) * size_mult
	if _invuln > 0.0:
		_invuln -= delta
		sprite.modulate.a = 0.35 if fmod(_invuln, 0.2) < 0.1 else 1.0
		shield.visible = true
		shield.modulate.a = clampf(_invuln / invulnerable_time, 0.0, 1.0)
	else:
		sprite.modulate.a = 1.0
		shield.visible = false


## Called by barriers (internally) and by alien hitboxes.
## `from` is the position of whatever hit us, used to knock the ship away.
func take_hit(from: Vector2 = Vector2.INF) -> void:
	if not alive or _invuln > 0.0:
		return
	if from != Vector2.INF:
		heading = (global_position - from).angle()
		rotation = heading
	lives -= 1
	lives_changed.emit(lives)
	hit_sound.play()
	if lives <= 0:
		_die()
	else:
		_invuln = invulnerable_time


func stop() -> void:
	alive = false
	velocity = Vector2.ZERO
	flame.visible = false


func _die() -> void:
	stop()
	sprite.visible = false
	shield.visible = false
	died.emit()


## Darth's Chaos item: swap the controls for `seconds`.
func apply_chaos(seconds: float) -> void:
	chaos_time = maxf(chaos_time, seconds)


## Darth's Giant item: grow for `seconds`.
func apply_giant(seconds: float) -> void:
	giant_time = maxf(giant_time, seconds)
