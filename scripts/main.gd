extends Node2D
## Level controller for the endless versus run: wires up the two ships and the
## HUD, keeps the level generating above the screen, scrolls the screen and
## decides the winner (the last ship still flying).
##
## Solo practice (no LAN game) has only the blue ship. In a LAN game the host
## flies blue and the joining computer flies red.
##
## The level itself is built "sideways" under the Level node, which is turned
## 90 degrees so that the level's forward direction (its +x) points up the
## screen. Level-local x = height climbed = -world y.

## Width of the playable area (x). Height is endless upwards.
@export var world_size := Vector2(2600, 3400)
## Auto-scroll: the screen climbs on its own, faster the higher it gets.
@export var scroll_start_speed := 60.0
@export var scroll_per_pixel := 0.008 ## extra px/s per pixel climbed (8 per 1000)
@export var scroll_max_speed := 260.0
@export var countdown_seconds := 3.0
## If a ship flies into the top part of the screen (this fraction of its
## height), the screen speeds up to keep it in view.
@export var catch_up_fraction := 0.33
## Seconds between random comets at the start (easy) and at full difficulty.
@export var comet_interval_easy := Vector2(4.0, 6.5)
@export var comet_interval_hard := Vector2(1.0, 2.2)
## Most random comets on screen at once.
@export var max_random_comets := 2
## Distance (past the opening section) over which comets ramp up.
@export var ramp_distance := 20000.0
@export var comet_speed := Vector2(260, 420)
## Fraction of the monitor the game window takes up at launch.
@export var window_fraction := 0.92

const COMET := preload("res://scenes/comet.tscn")
const BUMP_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_shieldDown.ogg")
const SHIP_NAMES := {1: "BLUE", 2: "RED"}
static var _window_sized := false

var _over := false
var _comet_timer := 3.0
var _start_x := 0.0
var _furthest_x := 0.0
var _scroll_y := 0.0 ## world y of the screen centre
var _scroll_speed := 0.0
var _countdown := 0.0
var _solo := false
## The ships in this game (one in solo practice, two in a LAN game).
var players: Array = []
## Ships bounce off each other (no damage). Push speed and a short pause so
## one touch doesn't bounce them over and over.
@export var bump_push := 260.0
var _bump_cd := 0.0

@onready var hud = $HUD
@onready var generator = $Level/LevelGenerator
@onready var background: Sprite2D = $Background
@onready var camera: Camera2D = $Camera2D
@onready var lose_sound: AudioStreamPlayer = $LoseSound


func _ready() -> void:
	camera.limit_left = 0
	camera.limit_right = int(world_size.x)
	camera.limit_top = -100000000
	camera.limit_bottom = 100000000
	# Solo practice has no red ship; in a LAN game it is flown by the joiner.
	_solo = Net.mode != Net.Mode.HOST
	players = [$Player]
	if _solo:
		$Player2.free()
		$Player.global_position.x = world_size.x / 2.0
	else:
		$Player2.remote = true
		players.append($Player2)
	hud.set_solo(_solo)
	for p in players:
		var id: int = p.player_id
		p.lives_changed.connect(func(n: int): hud.set_lives(id, n))
		p.dash_changed.connect(func(f: float): hud.set_dash(id, f))
		p.stamina_changed.connect(func(f: float, b: bool): hud.set_stamina(id, f, b))
		p.laser_changed.connect(func(f: float): hud.set_laser(id, f))
		p.items_changed.connect(func(it: Array, sel: int): hud.set_items(id, it, sel))
		p.loadout_changed.connect(func(w: int, wl: float, sh: float): hud.set_loadout(id, w, wl, sh))
		p.died.connect(_on_player_died.bind(p))
		hud.set_lives(p.player_id, p.lives)
	_size_window()
	get_viewport().size_changed.connect(_fit_width)
	_fit_width()
	# Three power-ups scattered over the hand-made opening section.
	generator.call_deferred("place_pickups", generator, 300.0, 3300.0, 3)
	# Start with the bottom of the screen on the bottom wall and the ships a
	# bit above it, then count down before scrolling.
	_scroll_y = -_view_height() / 2.0
	camera.global_position = Vector2(world_size.x / 2.0, _scroll_y)
	for p in players:
		p.global_position.y = -_view_height() * 0.28
	_start_x = _view_height() * 0.28
	_furthest_x = _start_x
	_countdown = countdown_seconds


## Make the window nearly fill the monitor (once per launch).
func _size_window() -> void:
	if _window_sized or DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return
	_window_sized = true
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	var size := Vector2i(Vector2(area.size) * window_fraction)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(area.position + (area.size - size) / 2)


func _view_height() -> float:
	return get_viewport().get_visible_rect().size.y / camera.zoom.y


func _physics_process(delta: float) -> void:
	_bump_cd = maxf(0.0, _bump_cd - delta)
	var flying := _alive_players()
	if flying.size() < 2 or _bump_cd > 0.0:
		return
	var a: Node2D = flying[0]
	var b: Node2D = flying[1]
	var gap: Vector2 = b.global_position - a.global_position
	var touch: float = a.BASE_RADIUS * a.size_mult + b.BASE_RADIUS * b.size_mult
	if gap.length() < touch:
		var n := gap.normalized() if gap.length() > 0.01 else Vector2.RIGHT
		a.drift = a.drift.slide(n) - n * bump_push
		b.drift = b.drift.slide(n) + n * bump_push
		# Nudge them apart so they don't stay overlapped.
		var overlap: float = touch - gap.length()
		a.global_position -= n * overlap * 0.5
		b.global_position += n * overlap * 0.5
		_bump_cd = 0.3
		Fx.sound(self, BUMP_SOUND, -6.0)


func _alive_players() -> Array:
	return players.filter(func(p): return p.alive)


## Auto-scroll, top catch-up, and keeping the ships on screen.
func _update_scroll(delta: float) -> void:
	var half := _view_height() / 2.0
	var flying := _alive_players()
	# No one can fly during the GET READY countdown.
	for p in players:
		if is_instance_valid(p):
			p.controls_locked = _countdown > 0.0
	if _countdown > 0.0:
		_countdown -= delta
		hud.set_countdown(ceili(_countdown) if _countdown > 0.0 else 0)
	elif not _over:
		_scroll_speed = minf(scroll_start_speed + (_furthest_x - _start_x) * scroll_per_pixel, scroll_max_speed)
		_scroll_y -= _scroll_speed * delta
		# Top catch-up: a ship can't fly off the top; the screen follows the
		# higher ship (and so pushes the bottom edge up toward the other one).
		var catch_line := _scroll_y - half + _view_height() * catch_up_fraction
		for p in flying:
			if p.global_position.y < catch_line:
				_scroll_y -= catch_line - p.global_position.y
				catch_line = p.global_position.y
	hud.set_scroll(maxf(_scroll_speed, scroll_start_speed) / scroll_start_speed)
	camera.global_position = Vector2(world_size.x / 2.0, _scroll_y)

	for p in players:
		if _over or not p.alive:
			hud.set_danger(p.player_id, 0.0)
			continue
		# Bottom edge: falling below it costs a life and bumps the ship back up.
		var margin: float = p.BASE_RADIUS * p.size_mult + 6.0
		var bottom := _scroll_y + half - margin
		var gap: float = bottom - p.global_position.y
		hud.set_danger(p.player_id, clampf(1.0 - gap / (_view_height() * 0.25), 0.0, 1.0))
		if p.global_position.y > bottom:
			p.global_position.y = bottom
			var shielded: bool = p._invuln > 0.0 or p._dash_iframe > 0.0 or p._phasing
			if not shielded:
				p.take_hit(Vector2(p.global_position.x, bottom + 200.0))
				p.global_position.y = bottom - 60.0
			# Either way, the edge carries the ship up with the screen.
			p.drift.y = minf(p.drift.y, -(_scroll_speed + 150.0))


## Zoom the camera so the whole level width fills the screen horizontally.
func _fit_width() -> void:
	var z := get_viewport().get_visible_rect().size.x / world_size.x
	camera.zoom = Vector2(z, z)


func _process(delta: float) -> void:
	_comet_timer -= delta
	if _comet_timer <= 0.0:
		var d := clampf((_furthest_x - 3400.0) / ramp_distance, 0.0, 1.0)
		var interval := comet_interval_easy.lerp(comet_interval_hard, d)
		_comet_timer = randf_range(interval.x, interval.y)
		if get_tree().get_nodes_in_group("comets").size() < max_random_comets:
			_spawn_comet()

	# Slide the tiled background along with the camera (snapped to whole
	# tiles so it doesn't visibly move).
	var tile := float(background.texture.get_height())
	background.position.y = floorf((camera.get_screen_center_position().y - 2100.0) / tile) * tile

	# Progress is measured upwards: level-local x = -world y.
	for p in _alive_players():
		_furthest_x = maxf(_furthest_x, -p.global_position.y)

	_update_scroll(delta)

	# Keep the level built above the screen and forget what is far below it.
	var screen_top := -(_scroll_y - _view_height() / 2.0)
	var screen_bottom := -(_scroll_y + _view_height() / 2.0)
	generator.update(screen_top + 3000.0, screen_bottom - 2500.0)

	if _over and (Input.is_action_just_pressed("restart") or Net.take_event("restart")):
		get_tree().reload_current_scene()


## A ship ran out of lives: the other one (if any) wins.
func _on_player_died(loser: Node) -> void:
	if _over:
		return
	_over = true
	Fx.sound(self, lose_sound.stream)
	if _solo:
		hud.show_message("YOUR SHIP IS LOST\n\nPRESS ENTER TO FLY AGAIN")
	else:
		hud.show_message("%s SHIP WINS!\n\n%s SHIP IS LOST\n\nPRESS ENTER TO PLAY AGAIN"
				% [SHIP_NAMES[3 - loser.player_id], SHIP_NAMES[loser.player_id]])


## Marks this as the game scene (Net streams it to the other computer).
func is_game_scene() -> bool:
	return true


## Launch a comet from a random edge of the visible screen, flying across it.
func _spawn_comet() -> void:
	var view_size := get_viewport().get_visible_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - view_size / 2.0, view_size)
	var margin := 80.0
	var start: Vector2
	match randi() % 4:
		0: start = Vector2(view.position.x - margin, randf_range(view.position.y, view.end.y))
		1: start = Vector2(view.end.x + margin, randf_range(view.position.y, view.end.y))
		2: start = Vector2(randf_range(view.position.x, view.end.x), view.position.y - margin)
		_: start = Vector2(randf_range(view.position.x, view.end.x), view.end.y + margin)
	# Aim somewhere in the middle part of the screen.
	var target := view.position + view.size * Vector2(randf_range(0.25, 0.75), randf_range(0.25, 0.75))
	var vel := (target - start).normalized() * randf_range(comet_speed.x, comet_speed.y)
	var comet := COMET.instantiate()
	comet.setup(start, vel, randf_range(0.9, 1.5))
	add_child(comet)
