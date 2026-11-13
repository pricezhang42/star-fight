extends Node2D
## Builds the level endlessly to the right in chunks, in the same spirit as the
## hand-made opening: asteroid belts, short rock strips, planets with
## satellites, black holes, red ships on curved paths and chasers.
## It gets busier the further the player goes. Old chunks behind the player
## are freed.

const WALL := preload("res://scenes/meteor_wall.tscn")
const CLUSTER := preload("res://scenes/asteroid_cluster.tscn")
const PLANET := preload("res://scenes/planet.tscn")
const SATELLITE := preload("res://scenes/satellite.tscn")
const BLACK_HOLE := preload("res://scenes/black_hole.tscn")
const PATH_SHIP := preload("res://scenes/path_ship.tscn")
const CHASER := preload("res://scenes/chaser.tscn")
const ROCK := preload("res://scenes/rock.tscn")
const ROCK_TEXTURES := [
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_big1.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_big3.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_med1.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_med1.png"),
]
const PLANET_TEXTURES := [
	preload("res://assets/wisedawn_planets/planet19.png"),
	preload("res://assets/wisedawn_planets/planet14.png"),
	preload("res://assets/wisedawn_planets/planet3.png"),
	preload("res://assets/wisedawn_planets/planet8.png"),
]

@export var start_x := 3400.0 ## where generated chunks begin
@export var chunk_width := 1400.0
@export var world_height := 1680.0
## Distance over which the level ramps from easy to full difficulty
## (20000 px = a score of 2000).
@export var ramp_distance := 20000.0
## Extra distance after the opening section that stays at the easiest setting.
@export var easy_stretch := 3000.0

var generated_until := 0.0
var _last_big_x := -INF ## x of the last big planet / black hole, to keep them apart
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	generated_until = start_x


## Make sure the level exists up to `x`, and free chunks that end before
## `forget_before`.
func update(x: float, forget_before: float) -> void:
	while generated_until < x:
		_build_chunk(generated_until)
		generated_until += chunk_width
	for chunk in get_children():
		if chunk.get_meta("end_x", INF) < forget_before:
			chunk.queue_free()


func _build_chunk(x0: float) -> void:
	var chunk := Node2D.new()
	chunk.name = "Chunk%d" % int(x0)
	chunk.set_meta("end_x", x0 + chunk_width)
	add_child(chunk)
	var difficulty := clampf((x0 - start_x - easy_stretch) / ramp_distance, 0.0, 1.0)

	# Top and bottom borders.
	for y in [0.0, world_height]:
		var border := WALL.instantiate()
		border.position = Vector2(x0, y)
		border.vertical = false
		border.length = chunk_width - 52.0
		border.spacing = 52.0
		border.rock_scale = 0.6
		border.breakable = false
		border.random_seed = _rng.randi()
		chunk.add_child(border)

	# The chunk is split into columns. Early on there are only two columns
	# and many are left empty; further in there are three, and they fill up.
	var columns := 2 if difficulty < 0.3 else 3
	var col_w := chunk_width / columns
	for c in columns:
		var cx := x0 + col_w * (c + 0.5) + _rng.randf_range(-60.0, 60.0)
		if _rng.randf() < lerpf(0.6, 0.0, difficulty):
			continue # empty column: free space
		var roll := _rng.randf()
		var room_for_big := cx - _last_big_x > 900.0
		if roll < 0.25:
			if _add_planet(chunk, cx, difficulty, room_for_big and difficulty > 0.15):
				_last_big_x = cx
		elif room_for_big and roll < 0.31 + 0.1 * difficulty:
			_add_black_hole(chunk, cx, difficulty)
			_last_big_x = cx
		else:
			# Three horizontal bands (top / middle / bottom); fill one to three
			# of them, always leaving room to slip between.
			var bands := [
				_rng.randf_range(0.12, 0.26) * world_height,
				_rng.randf_range(0.43, 0.57) * world_height,
				_rng.randf_range(0.74, 0.88) * world_height,
			]
			bands.shuffle()
			# Only one obstacle per column early on (about score 1000).
			var count := 1
			if difficulty >= 0.2:
				count += int(_rng.randf() < 0.1 + 0.6 * difficulty) + int(_rng.randf() < 0.45 * difficulty - 0.05)
			for i in count:
				_add_small(chunk, Vector2(cx + _rng.randf_range(-80.0, 80.0), bands[i]), difficulty)

	# Moving asteroids that drift and bounce: one early on, up to four later.
	for i in 1 + int(3.0 * difficulty + _rng.randf() * 0.99):
		var rock := ROCK.instantiate()
		var idx := _rng.randi() % ROCK_TEXTURES.size()
		var big := idx < 2
		var s := _rng.randf_range(0.7, 1.0)
		rock.texture = ROCK_TEXTURES[idx]
		rock.sprite_scale = s
		rock.radius = (42.0 if big else 20.0) * s * 0.9
		rock.hp = 3 if big else 1
		rock.moving = true
		rock.start_velocity = Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(50.0, 90.0 + 50.0 * difficulty)
		rock.cruise_speed = 110.0 + 60.0 * difficulty
		rock.position = Vector2(x0 + _rng.randf_range(100.0, chunk_width - 100.0), _rng.randf_range(0.15, 0.85) * world_height)
		chunk.add_child(rock)

	# Enemy ships: rare and slow-firing at first, common and aggressive later.
	if _rng.randf() < 0.1 + 0.7 * difficulty:
		_add_ship_loop(chunk, Vector2(x0 + _rng.randf_range(300.0, chunk_width - 300.0),
				_rng.randf_range(0.25, 0.75) * world_height), 1 + int(_rng.randf() < difficulty), difficulty)
	var chasers := int(_rng.randf() < 0.15 + 0.6 * difficulty) + int(_rng.randf() < 0.7 * difficulty - 0.1)
	for i in chasers:
		var ch := CHASER.instantiate()
		ch.position = Vector2(x0 + _rng.randf_range(200.0, chunk_width - 200.0), _rng.randf_range(0.1, 0.9) * world_height)
		ch.rotation = PI
		ch.speed = 125.0 + 95.0 * difficulty
		ch.detect_radius = 380.0 + 160.0 * difficulty
		_scale_fire(ch, difficulty)
		chunk.add_child(ch)


## Enemies fire about half as often at the start as at full difficulty.
func _scale_fire(enemy: Node, difficulty: float) -> void:
	enemy.fire_cooldown *= lerpf(1.8, 0.85, difficulty)


## Asteroid clump or a short (optionally tilted) strip of rocks.
func _add_small(chunk: Node, pos: Vector2, _difficulty: float) -> void:
	if _rng.randf() < 0.55:
		var cl := CLUSTER.instantiate()
		cl.position = pos
		# Small clumps early, bigger ones later.
		cl.radius = _rng.randf_range(lerpf(55.0, 80.0, _difficulty), lerpf(90.0, 140.0, _difficulty))
		cl.count = int(cl.radius / 11.0)
		cl.rock_scale = _rng.randf_range(0.8, 1.0)
		cl.random_seed = _rng.randi()
		chunk.add_child(cl)
	else:
		var strip := WALL.instantiate()
		var length := _rng.randf_range(lerpf(160.0, 220.0, _difficulty), lerpf(260.0, 380.0, _difficulty))
		strip.length = length
		strip.spacing = 64.0
		strip.rock_scale = 0.8
		strip.brown = _rng.randf() < 0.5
		strip.random_seed = _rng.randi()
		strip.rotation = _rng.randf_range(-0.7, 0.7)
		# Centre the strip on pos.
		strip.position = pos - Vector2(0, length / 2.0).rotated(strip.rotation)
		chunk.add_child(strip)


## Adds a planet of random size with an orbiting satellite. Returns true if
## it was a big one (needs the whole column).
func _add_planet(chunk: Node, cx: float, difficulty: float, allow_big: bool) -> bool:
	var planet := PLANET.instantiate()
	var big := allow_big and _rng.randf() < 0.5
	var radius := _rng.randf_range(140.0, 220.0) if big else _rng.randf_range(60.0, 120.0)
	var orbit := radius + _rng.randf_range(70.0, 110.0)
	# Keep the orbit inside the level, leaving the other half open.
	var y := 0.0
	if big:
		y = (0.25 if _rng.randf() < 0.5 else 0.75) * world_height
	else:
		y = _rng.randf_range(orbit + 40.0, world_height - orbit - 40.0)
	planet.position = Vector2(cx, y)
	planet.radius = radius
	planet.texture = PLANET_TEXTURES[_rng.randi() % PLANET_TEXTURES.size()]
	planet.spin_speed = _rng.randf_range(-0.06, 0.06)
	var sat := SATELLITE.instantiate()
	sat.orbit_radius = orbit
	sat.angle = _rng.randf() * TAU
	# Smaller orbits spin a little faster.
	sat.orbit_speed = _rng.randf_range(0.7, 1.1) * (300.0 / orbit) ** 0.4 * (1.0 if _rng.randf() < 0.5 else -1.0)
	sat.hostile = _rng.randf() < 0.1 + 0.65 * difficulty
	_scale_fire(sat, difficulty)
	planet.add_child(sat)
	chunk.add_child(planet)
	return big


func _add_black_hole(chunk: Node, cx: float, difficulty: float) -> void:
	var bh := BLACK_HOLE.instantiate()
	bh.strength = lerpf(1000.0, 1650.0, difficulty)
	bh.position = Vector2(cx, _rng.randf_range(0.3, 0.7) * world_height)
	bh.pull_radius = _rng.randf_range(300.0, 380.0)
	chunk.add_child(bh)


## An oval loop with `ships` red ships flying around it.
func _add_ship_loop(chunk: Node, center: Vector2, ships: int, difficulty: float) -> void:
	var path := Path2D.new()
	path.position = center
	var w := _rng.randf_range(220.0, 340.0)
	var h := _rng.randf_range(120.0, 200.0)
	var curve := Curve2D.new()
	var k := 0.55 # handle length for a smooth oval
	curve.add_point(Vector2(-w, 0), Vector2(0, h * k), Vector2(0, -h * k))
	curve.add_point(Vector2(0, -h), Vector2(-w * k, 0), Vector2(w * k, 0))
	curve.add_point(Vector2(w, 0), Vector2(0, -h * k), Vector2(0, h * k))
	curve.add_point(Vector2(0, h), Vector2(w * k, 0), Vector2(-w * k, 0))
	curve.add_point(Vector2(-w, 0), Vector2(0, h * k), Vector2(0, -h * k))
	path.curve = curve
	chunk.add_child(path)
	var length := curve.get_baked_length()
	for i in ships:
		var ship := PATH_SHIP.instantiate()
		ship.speed = lerpf(150.0, 220.0, difficulty)
		_scale_fire(ship, difficulty)
		path.add_child(ship)
		ship.progress = length * i / ships
