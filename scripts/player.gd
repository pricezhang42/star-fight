extends CharacterBody2D
## A player's starship. Player 1 is blue, player 2 is red; otherwise they are
## identical. A/D rotate the ship, W thrusts (let go and the ship coasts to a
## stop in about a second), S brakes hard, Shift boosts (uses stamina), Space dashes. The turret on top of
## the ship swivels to follow the mouse. Left click fires a single heavy laser
## shot along the turret (5 s cooldown). It flies like the comets Darth used to
## throw: fast, bounces off asteroids and knocks them away, flies over
## everything else and is bent by black holes.
## Momentum: speed builds up while W is held and bleeds off when it isn't.
## Player 1 reads this computer's keyboard and mouse; in a LAN game player 2's
## input arrives over the network (see Net).
## The chaos / giant / slick effects are left over from the old powerups and
## are not triggered by anything at the moment.

signal lives_changed(lives: int)
signal died
## Emitted when chaos / giant start or end, for the HUD.
signal status_changed(reversed: bool, giant: bool, slick: bool)
## 0..1 how recharged the dash is (1 = ready).
signal dash_changed(ready_fraction: float)
## 0..1 stamina for the boost, and whether the ship is boosting right now.
signal stamina_changed(fraction: float, boosting: bool)
## 0..1 how recharged the laser is (1 = ready).
signal laser_changed(ready_fraction: float)
## The power-ups held (PowerUps.Kind values) and which one is selected.
signal items_changed(items: Array, selected: int)
## Weapon pickup in use, its seconds left, and seconds of Shield left, for the HUD.
signal loadout_changed(weapon: int, weapon_left: float, shield_left: float)

## 1 = blue ship (this computer), 2 = red ship.
@export var player_id := 1
## True when this ship is flown from the other computer (LAN host only).
var remote := false
## Set by the game during the GET READY countdown: the ship ignores input.
var controls_locked := false
@export var speed := 0.0 ## current speed (starts parked)
@export var min_speed := 0.0
@export var max_speed := 340.0
## Boost (hold Shift): faster top speed and acceleration while stamina lasts.
@export var boost_speed_mult := 1.6
@export var boost_accel_mult := 2.2
@export var stamina_max := 100.0
@export var stamina_drain := 35.0 ## per second while boosting (~3 s of boost)
@export var stamina_regen := 18.0 ## per second once you've stopped boosting
@export var stamina_regen_delay := 0.8 ## seconds after a boost before it refills
## After running dry, boost can't start again until stamina is back to this.
@export var stamina_restart := 25.0
@export var acceleration := 420.0 ## speed gained per second while holding W
@export var coast_drag := 320.0 ## speed lost per second when W is released
@export var brake_force := 1400.0 ## speed lost per second while holding S
@export var turn_speed := 3.2 ## radians per second
@export var max_lives := 5
@export var invulnerable_time := 3.0
@export var fire_cooldown := 5.0
@export var bullet_speed := 850.0
## How fast outside pushes (black hole pull, knockback) fade, per second.
@export var drift_damping := 1.6
## Dash: extra speed added in the nose direction (fades like other pushes).
@export var dash_speed := 1000.0
@export var dash_cooldown := 10.0
## Seconds at the start of a dash during which nothing costs a life.
@export var dash_iframes := 0.3
## Seconds at the start of a dash during which the ship flies through rocks,
## planets and satellites. If it is still inside one when this ends, it keeps
## passing through (and stays untouchable) until it is clear.
@export var dash_phase_time := 0.4
## Push away from whatever hit the ship (added to the ship's current speed,
## so it always clears the obstacle).
@export var knockback := 600.0

const BULLET := preload("res://scenes/bullet.tscn")
const LASER_BEAM := preload("res://scripts/laser_beam.gd")
const MISSILE := preload("res://scripts/homing_missile.gd")
const GRENADE := preload("res://scripts/grenade.gd")
const ROCKET := preload("res://scripts/rocket.gd")
const BUBBLE_TEX := preload("res://assets/kenney_space_shooter_redux/effects/shield3.png")
const POP_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_shieldDown.ogg")
const SHIELD_SECONDS := 10.0
const WEAPON_SECONDS := 20.0
const USE_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_zap.ogg")
## Power-up tuning.
const SHRINK_SCALE := 0.6
const SHRINK_SECONDS := 8.0
const GRENADE_RANGE := 900.0
## Blaster sounds: one is picked at random for each shot.
const SHOOT_SOUNDS := [
	preload("res://assets/generated/blaster_1.wav"),
	preload("res://assets/generated/blaster_2.wav"),
	preload("res://assets/generated/blaster_3.wav"),
	preload("res://assets/generated/blaster_4.wav"),
	preload("res://assets/generated/blaster_5.wav"),
]
const DASH_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_twoTone.ogg")
const RED_SHIP := preload("res://assets/kenney_space_shooter_redux/ships/playerShip1_red.png")

var lives := 0
## Extra velocity from outside forces such as black holes.
var drift := Vector2.ZERO
## While above 0, black holes don't pull the ship (set after being flung out).
var gravity_grace := 0.0
var _fire_cd := 0.0
var _dash_cd := 0.0
var _dash_iframe := 0.0
var _phase := 0.0
var _shoved := {} ## rocks already shoved by the current dash
var _phasing := false
var _last_dash_report := -1.0
var _last_laser_report := -1.0
## Boost stamina.
var stamina := 100.0
var boosting := false
var _stamina_locked := false
var _regen_wait := 0.0
var _last_stamina_report := -1.0
var _last_boosting := false
## Power-ups held (up to PowerUps.MAX_HELD) and the selected slot.
var items: Array = []
var selected := 0
## Seconds left at small size (Shrink power-up).
var shrink_time := 0.0
## Seconds left on the Shield power-up's bubble (it pops on the first hit).
var shield_time := 0.0
## Weapon pickup in use (PowerUps.Weapon) and seconds it has left (20 s).
var weapon := 0
var weapon_time := 0.0
var _bubble: Sprite2D
var _last_loadout := ""
var heading := 0.0
var alive := true
var _invuln := 0.0
var _flame_t := 0.0
## Seconds left with A/D and W/S swapped (Darth's Chaos item).
var chaos_time := 0.0
## Seconds left at giant size (Darth's Giant item).
var giant_time := 0.0
## Seconds left of slippery steering (Darth's Slick item): turning builds up
## and keeps spinning, and the ship slides instead of following its nose.
var slick_time := 0.0
var _move_dir := 0.0 ## direction the ship is actually travelling
var _ang_vel := 0.0
var _was_slick := false
## Current size multiplier (eases between 1 and giant_scale).
var size_mult := 1.0
const GIANT_SCALE := 2.0
const BASE_RADIUS := 32.0
const MUZZLE := 46.0 ## how far from the ship's centre bolts appear
var _base_sprite_scale := Vector2.ONE
var _base_flame_pos := Vector2.ZERO
var _was_reversed := false
var _was_giant := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var flame: Sprite2D = $Flame
@onready var turret: Node2D = $Turret
@onready var shield: Sprite2D = $Shield
@onready var hit_sound: AudioStreamPlayer = $HitSound


func _ready() -> void:
	add_to_group("player")
	lives = max_lives
	heading = rotation
	_move_dir = heading
	shield.visible = false
	if player_id == 2:
		sprite.texture = RED_SHIP
	_base_sprite_scale = sprite.scale
	_base_flame_pos = flame.position
	# Own copy of the collision circle so it can grow.
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()


func _physics_process(delta: float) -> void:
	if not alive:
		return

	var reversed := chaos_time > 0.0
	var turn := 0.0
	var go := false
	var stop_ := false
	var firing := false
	var dash_now := false
	var boost_held := false
	var use_now := false
	var next_now := false
	var aim := global_position
	if remote:
		turn = Net.remote_turn
		go = Net.remote_buttons & Net.BTN_THRUST != 0
		stop_ = Net.remote_buttons & Net.BTN_BRAKE != 0
		firing = Net.remote_buttons & Net.BTN_FIRE != 0
		boost_held = Net.remote_buttons & Net.BTN_BOOST != 0
		dash_now = Net.take_event("dash")
		use_now = Net.take_event("use_item")
		next_now = Net.take_event("next_item")
		aim = Net.remote_mouse
	else:
		turn = Input.get_axis("turn_left", "turn_right")
		go = Input.is_action_pressed("thrust")
		stop_ = Input.is_action_pressed("brake")
		firing = Input.is_action_pressed("fire")
		boost_held = Input.is_action_pressed("boost")
		dash_now = Input.is_action_just_pressed("dash")
		use_now = Input.is_action_just_pressed("use_item")
		next_now = Input.is_action_just_pressed("next_item")
		aim = get_global_mouse_position()
	if controls_locked:
		# GET READY countdown: inputs are read (so presses don't pile up) but ignored.
		turn = 0.0
		go = false
		stop_ = false
		firing = false
		dash_now = false
		boost_held = false
		use_now = false
		next_now = false
	if reversed:
		turn = -turn # Chaos only swaps A/D; W/S work normally
	if slick_time > 0.0:
		# Oil on the thrusters: turning speeds up and slows down gradually,
		# and the travel direction lags behind where the nose points.
		_ang_vel += turn * turn_speed * 3.0 * delta
		_ang_vel *= exp(-1.5 * delta)
		_ang_vel = clampf(_ang_vel, -turn_speed * 1.4, turn_speed * 1.4)
		heading += _ang_vel * delta
		_move_dir = rotate_toward(_move_dir, heading, 1.1 * delta)
	else:
		_ang_vel = 0.0
		heading += turn * turn_speed * delta
		_move_dir = rotate_toward(_move_dir, heading, 8.0 * delta)
	# Boost: uses stamina; pushes the ship forward even without W.
	boosting = boost_held and not stop_ and stamina > 0.0 and not _stamina_locked
	if boosting:
		stamina = maxf(0.0, stamina - stamina_drain * delta)
		_regen_wait = stamina_regen_delay
		if stamina <= 0.0:
			_stamina_locked = true # ran dry: wait for it to refill a bit
	else:
		_regen_wait = maxf(0.0, _regen_wait - delta)
		if _regen_wait <= 0.0:
			stamina = minf(stamina_max, stamina + stamina_regen * delta)
		if _stamina_locked and stamina >= stamina_restart:
			_stamina_locked = false
	var top := max_speed * (boost_speed_mult if boosting else 1.0)
	if boosting:
		speed = minf(speed + acceleration * boost_accel_mult * delta, top)
	elif speed > top:
		# Still above normal top speed after a boost: ease back down.
		speed = maxf(top, speed - coast_drag * delta)
	elif go:
		speed = minf(speed + acceleration * delta, top)
	else:
		speed -= coast_drag * delta # coast to a stop
	if stop_:
		speed -= brake_force * delta
	speed = maxf(speed, min_speed)
	var frac := stamina / stamina_max
	if absf(frac - _last_stamina_report) > 0.005 or boosting != _last_boosting:
		_last_stamina_report = frac
		_last_boosting = boosting
		stamina_changed.emit(frac, boosting)
	rotation = heading
	gravity_grace -= delta
	drift *= exp(-drift_damping * delta)
	velocity = Vector2.RIGHT.rotated(_move_dir) * speed + drift

	_update_phasing(delta)
	var col := move_and_collide(velocity * delta)
	if col:
		# Get knocked back off the obstacle and take damage, but keep facing
		# (and flying) the same way.
		var n := col.get_normal()
		drift = drift.slide(n) + n * (knockback + speed)
		position += n * 8.0
		take_hit()

	# The turret swivels to the mouse, whichever way the nose points. (With
	# the mouse right on the ship it keeps its last angle.)
	if aim.distance_to(global_position) > 1.0:
		turret.global_rotation = (aim - global_position).angle()
	# Laser: one heavy shot along the turret, then a 5 s recharge.
	_fire_cd = maxf(0.0, _fire_cd - delta)
	if firing and _fire_cd <= 0.0:
		var dir := Vector2.RIGHT.rotated(turret.global_rotation)
		if weapon == PowerUps.Weapon.ROCKET:
			_fire_cd = fire_cooldown
			var r := Area2D.new()
			r.set_script(ROCKET)
			r.setup(global_position + dir * MUZZLE * size_mult, dir, self)
			get_tree().current_scene.add_child(r)
			Fx.sound(get_tree().current_scene, USE_SOUND, -4.0)
		else:
			# Rapid laser: same shot, half the recharge.
			_fire_cd = fire_cooldown * (0.5 if weapon == PowerUps.Weapon.RAPID else 1.0)
			_shoot(dir, bullet_speed)
	# Power-ups: right click uses the selected one, Space switches.
	if next_now and items.size() > 1:
		selected = (selected + 1) % items.size()
		items_changed.emit(items, selected)
	if use_now and not items.is_empty():
		_use_item(aim)
	var full_cd := fire_cooldown * (0.5 if weapon == PowerUps.Weapon.RAPID else 1.0)
	var laser_ready := 1.0 - _fire_cd / full_cd
	if absf(laser_ready - _last_laser_report) > 0.01 or (laser_ready >= 1.0 and _last_laser_report < 1.0):
		_last_laser_report = laser_ready
		laser_changed.emit(laser_ready)

	# Dash.
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_dash_iframe = maxf(0.0, _dash_iframe - delta)
	if dash_now and _dash_cd <= 0.0:
		_dash()
	if _dash_iframe > 0.0 or _phasing:
		_spawn_ghost()
	var dash_ready := 1.0 - _dash_cd / dash_cooldown
	if absf(dash_ready - _last_dash_report) > 0.01 or (dash_ready >= 1.0 and _last_dash_report < 1.0):
		_last_dash_report = dash_ready
		dash_changed.emit(dash_ready)

	# A dash shoves any rock the ship passes through.
	if _phasing:
		_dash_shove()

	_update_effects(delta)


func _dash_shove() -> void:
	var fwd := Vector2.RIGHT.rotated(heading)
	var reach := BASE_RADIUS * size_mult + 50.0
	for rock in get_tree().get_nodes_in_group("rocks"):
		if _shoved.has(rock):
			continue
		var to: Vector2 = rock.global_position - global_position
		if to.length() < reach + rock.radius:
			_shoved[rock] = true
			# Knock it sideways out of the ship's path and a bit forward.
			var side := to.slide(fwd).normalized()
			if side == Vector2.ZERO:
				side = fwd.orthogonal()
			rock.knock(side * 420.0 + fwd * 260.0)


func _shoot(dir: Vector2, shot_speed: float) -> void:
	var b := BULLET.instantiate()
	b.setup(global_position + dir * MUZZLE * size_mult, dir, self, shot_speed)
	b.make_heavy()
	get_tree().current_scene.add_child(b)
	# Each shot is a random variant, pitched and levelled a little differently.
	Fx.sound(get_tree().current_scene, SHOOT_SOUNDS.pick_random(), -8.0 + randf_range(-1.5, 1.0), randf_range(0.88, 1.12))


func _update_effects(delta: float) -> void:
	# Darth's effects.
	chaos_time = maxf(0.0, chaos_time - delta)
	giant_time = maxf(0.0, giant_time - delta)
	slick_time = maxf(0.0, slick_time - delta)
	shrink_time = maxf(0.0, shrink_time - delta)
	shield_time = maxf(0.0, shield_time - delta)
	if weapon != PowerUps.Weapon.NONE:
		weapon_time = maxf(0.0, weapon_time - delta)
		if weapon_time <= 0.0:
			weapon = PowerUps.Weapon.NONE
	_update_bubble()
	var target := 1.0
	if giant_time > 0.0:
		target = GIANT_SCALE
	elif shrink_time > 0.0:
		target = SHRINK_SCALE
	size_mult = move_toward(size_mult, target, delta * 4.0)
	sprite.scale = _base_sprite_scale * size_mult
	shield.scale = _base_sprite_scale * size_mult
	turret.scale = Vector2.ONE * size_mult
	flame.position = _base_flame_pos * size_mult
	($CollisionShape2D.shape as CircleShape2D).radius = BASE_RADIUS * size_mult
	var tint := Color.WHITE
	if chaos_time > 0.0:
		tint = Color(0.85, 0.45, 1.0)
	elif slick_time > 0.0:
		tint = Color(0.5, 0.85, 1.0)
	sprite.modulate = Color(tint, sprite.modulate.a)
	var reversed := chaos_time > 0.0
	var giant := giant_time > 0.0
	var slick := slick_time > 0.0
	if reversed != _was_reversed or giant != _was_giant or slick != _was_slick:
		_was_reversed = reversed
		_was_giant = giant
		_was_slick = slick
		status_changed.emit(reversed, giant, slick)

	_flame_t += delta * 30.0
	var throttle := inverse_lerp(min_speed, max_speed, speed)
	if boosting:
		throttle *= 1.5 # long boost flame
	flame.scale = Vector2(0.8 + 0.4 * throttle, (0.6 + 1.2 * throttle) * (1.0 + 0.2 * sin(_flame_t))) * size_mult
	if _invuln > 0.0:
		_invuln -= delta
		sprite.modulate.a = 0.35 if fmod(_invuln, 0.2) < 0.1 else 1.0
		shield.visible = true
		shield.modulate.a = clampf(_invuln / invulnerable_time, 0.0, 1.0)
	else:
		sprite.modulate.a = 1.0
		shield.visible = false
	turret.modulate.a = sprite.modulate.a * sprite.self_modulate.a


## Called by barriers (internally) and by alien hitboxes.
## `from` is the position of whatever hit us, used to knock the ship away.
func take_hit(from: Vector2 = Vector2.INF) -> void:
	if not alive or _invuln > 0.0 or _dash_iframe > 0.0 or _phasing:
		return
	if shield_time > 0.0:
		# The Shield bubble takes the hit instead and pops.
		shield_time = 0.0
		_invuln = 0.6 # a moment to get clear
		if from != Vector2.INF:
			var away_s := (global_position - from).normalized()
			if away_s != Vector2.ZERO:
				drift = drift.slide(away_s) + away_s * (knockback + speed)
		Fx.flash(get_tree().current_scene, global_position, BUBBLE_TEX, 1.4, 0.3)
		Fx.sound(get_tree().current_scene, POP_SOUND, 0.0)
		return
	if from != Vector2.INF:
		# Knocked back away from what hit us; the nose stays pointing the same way.
		var away := (global_position - from).normalized()
		if away == Vector2.ZERO:
			away = Vector2.LEFT.rotated(heading) # hit dead centre: push straight back
		drift = drift.slide(away) + away * (knockback + speed)
	lives -= 1
	lives_changed.emit(lives)
	Fx.sound(get_tree().current_scene, hit_sound.stream)
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
	turret.visible = false
	shield.visible = false
	collision_layer = 0 # nothing can hit the wreck
	collision_mask = 0
	died.emit()


## Darth's Chaos item: swap the controls for `seconds`.
func apply_chaos(seconds: float) -> void:
	chaos_time = maxf(chaos_time, seconds)


## Darth's Giant item: grow for `seconds`.
func apply_giant(seconds: float) -> void:
	giant_time = maxf(giant_time, seconds)


## Darth's Slick item: slippery steering for `seconds`.
func apply_slick(seconds: float) -> void:
	slick_time = maxf(slick_time, seconds)


func _dash() -> void:
	_dash_cd = dash_cooldown
	_dash_iframe = dash_iframes
	_phase = dash_phase_time
	_shoved.clear()
	drift += Vector2.RIGHT.rotated(heading) * dash_speed
	Fx.sound(get_tree().current_scene, DASH_SOUND, -4.0)


## Fading afterimage of the ship, left behind while dashing.
func _spawn_ghost() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.global_position = global_position
	g.rotation = sprite.global_rotation
	g.scale = sprite.global_scale
	g.modulate = Color(0.5, 0.85, 1.0, 0.55)
	get_tree().current_scene.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.3)
	tw.tween_callback(g.queue_free)


## While dashing, ignore solid obstacles (collision mask off). Once the dash
## time is over, only switch collisions back on when the ship is clear of
## everything, so it never gets stuck inside a rock.
func _update_phasing(delta: float) -> void:
	_phase = maxf(0.0, _phase - delta)
	var want := _phase > 0.0
	if not want and _phasing and _overlapping_solid():
		want = true
	_phasing = want
	collision_mask = 0 if _phasing else 1
	sprite.self_modulate.a = 0.55 if _phasing else 1.0


func _overlapping_solid() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = global_transform
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


# ===========================================================================
# Power-ups
# ===========================================================================

## Take a power-up from a pickup. Returns false if both slots are full.
func add_item(kind: int) -> bool:
	if items.size() >= PowerUps.MAX_HELD:
		return false
	items.append(kind)
	if items.size() == 1:
		selected = 0
	items_changed.emit(items, selected)
	return true


## The other ship, if it's still flying.
func _opponent() -> Node2D:
	for ship in get_tree().get_nodes_in_group("player"):
		if ship != self and ship.alive:
			return ship
	return null


func _use_item(aim: Vector2) -> void:
	selected = clampi(selected, 0, items.size() - 1)
	var kind: int = items[selected]
	items.remove_at(selected)
	if selected >= items.size():
		selected = maxi(0, items.size() - 1)
	items_changed.emit(items, selected)
	var scene := get_tree().current_scene
	var aim_dir := Vector2.RIGHT.rotated(turret.global_rotation)
	var foe := _opponent()
	match kind:
		PowerUps.Kind.LASER:
			var beam := Node2D.new()
			beam.set_script(LASER_BEAM)
			beam.shooter = self
			beam.setup(global_position, aim_dir)
			scene.add_child(beam)
		PowerUps.Kind.SHIELD:
			shield_time = SHIELD_SECONDS
		PowerUps.Kind.SHRINK:
			shrink_time = SHRINK_SECONDS
			giant_time = 0.0
		PowerUps.Kind.MISSILE:
			var m := Area2D.new()
			m.set_script(MISSILE)
			m.setup(global_position + aim_dir * MUZZLE * size_mult, aim_dir, self, foe)
			scene.add_child(m)
		PowerUps.Kind.GRENADE:
			var to := aim - global_position
			if to.length() > GRENADE_RANGE:
				to = to.normalized() * GRENADE_RANGE
			var g := Node2D.new()
			g.set_script(GRENADE)
			g.setup(global_position + to.normalized() * MUZZLE, global_position + to)
			scene.add_child(g)
	Fx.sound(scene, USE_SOUND, -6.0)


## Weapon pickup: applies straight away (no slot) for 20 s. A new one
## replaces the current one and restarts the 20 s.
func set_weapon(w: int) -> bool:
	weapon = w
	weapon_time = WEAPON_SECONDS
	_fire_cd = minf(_fire_cd, fire_cooldown * (0.5 if w == PowerUps.Weapon.RAPID else 1.0))
	return true


## Shield bubble around the ship, in the ship's colour, and the HUD readout.
func _update_bubble() -> void:
	if _bubble == null:
		_bubble = Sprite2D.new()
		_bubble.texture = BUBBLE_TEX
		_bubble.z_index = 2
		add_child(_bubble)
	_bubble.visible = shield_time > 0.0
	if _bubble.visible:
		var c := Color(0.5, 0.8, 1.0) if player_id == 1 else Color(1.0, 0.55, 0.5)
		var blink := shield_time > 2.0 or fmod(shield_time, 0.3) > 0.15
		_bubble.modulate = Color(c, 0.75 if blink else 0.25)
		_bubble.global_rotation = 0.0
		_bubble.scale = Vector2.ONE * 0.75 * size_mult * (1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.01))
	var key := "%d:%d:%d" % [weapon, ceili(weapon_time), ceili(shield_time)]
	if key != _last_loadout:
		_last_loadout = key
		loadout_changed.emit(weapon, weapon_time, shield_time)
