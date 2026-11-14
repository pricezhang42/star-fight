extends Node2D
## Level controller for the endless run: wires up the player and HUD, keeps
## the level generating ahead of the player, tracks the distance score and
## handles game over and restart.

## Height of the playable area. (Width is endless.)
@export var world_size := Vector2(3400, 1200)
## Score points per pixel flown to the right.
@export var score_per_pixel := 0.1
## Points Luke earns for each laser hit on Darth.
@export var darth_hit_points := 100
## How far behind their furthest point the player may fly back.
@export var backtrack_limit := 1100.0
## Seconds between random comets at the start (easy) and at full difficulty.
@export var comet_interval_easy := Vector2(4.0, 6.5)
@export var comet_interval_hard := Vector2(1.0, 2.2)
## Most random comets on screen at once (Darth's thrown ones don't count).
@export var max_random_comets := 2
## Distance (past the opening section) over which comets ramp up.
@export var ramp_distance := 20000.0
@export var comet_speed := Vector2(260, 420)
## Fraction of the monitor the game window takes up at launch.
@export var window_fraction := 0.92

const COMET := preload("res://scenes/comet.tscn")
const SAVE_PATH := "user://star_fights.cfg"
static var _window_sized := false

var _over := false
var _comet_timer := 3.0
var _start_x := 0.0
var _furthest_x := 0.0
var score := 0
## Points from shooting Darth (added to the distance score).
var bonus := 0
var best := 0

@onready var player = $Player
@onready var hud = $HUD
@onready var generator = $LevelGenerator
@onready var background: Sprite2D = $Background
@onready var camera: Camera2D = $Player/Camera2D
@onready var lose_sound: AudioStreamPlayer = $LoseSound


func _ready() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 100000000
	camera.limit_bottom = int(world_size.y)
	player.lives_changed.connect(hud.set_lives)
	player.died.connect(_on_player_died)
	hud.set_lives(player.lives)
	var alien = $AlienAstronaut
	alien.hits_changed.connect(hud.set_p2_hits)
	alien.cooldown_changed.connect(hud.set_p2_cooldown)
	alien.items_changed.connect(hud.set_items)
	alien.shot_by_luke.connect(_on_darth_shot)
	player.status_changed.connect(hud.set_luke_status)
	player.dash_changed.connect(hud.set_dash)
	hud.set_p2_hits(0)
	_start_x = player.global_position.x
	_furthest_x = _start_x
	best = _load_best()
	hud.set_score(0, best)
	_size_window()
	get_viewport().size_changed.connect(_fit_height)
	_fit_height()


## Make the window nearly fill the monitor (once per launch).
func _size_window() -> void:
	if _window_sized or DisplayServer.get_name() == "headless":
		return
	_window_sized = true
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	var size := Vector2i(Vector2(area.size) * window_fraction)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(area.position + (area.size - size) / 2)


## Zoom the camera so the whole level height fills the screen vertically.
func _fit_height() -> void:
	var z := get_viewport().get_visible_rect().size.y / world_size.y
	camera.zoom = Vector2(z, z)


func _process(delta: float) -> void:
	_comet_timer -= delta
	if _comet_timer <= 0.0:
		var d := clampf((_furthest_x - 3400.0) / ramp_distance, 0.0, 1.0)
		var interval := comet_interval_easy.lerp(comet_interval_hard, d)
		_comet_timer = randf_range(interval.x, interval.y)
		var random_comets := get_tree().get_nodes_in_group("comets").filter(func(c): return c.thrower == null)
		if random_comets.size() < max_random_comets:
			_spawn_comet()

	# Slide the tiled background along with the camera (snapped to whole
	# tiles so it doesn't visibly move).
	var tile := float(background.texture.get_width())
	background.position.x = floorf((camera.get_screen_center_position().x - 2200.0) / tile) * tile

	var x: float = player.global_position.x
	_furthest_x = maxf(_furthest_x, x)
	score = int((_furthest_x - _start_x) * score_per_pixel) + bonus
	hud.set_score(score, maxi(score, best))

	# Keep the level built ahead, forget what is far behind, and stop the
	# player flying back into the forgotten part.
	var back := maxf(0.0, _furthest_x - backtrack_limit)
	camera.limit_left = int(maxf(0.0, back - 300.0))
	generator.update(_furthest_x + 3000.0, back - 2500.0)
	if not _over and x < back:
		player.position.x = back
		player.heading = PI - player.heading # bounce back to the right
		player.drift.x = absf(player.drift.x)

	if _over and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()


func _on_player_died() -> void:
	if _over:
		return
	_over = true
	lose_sound.play()
	var new_best := score > best
	if new_best:
		best = score
		_save_best(best)
	hud.show_message("LUKE'S SHIP IS LOST\n\nSCORE %d%s\nDARTH'S HITS %d\n\nPRESS ENTER TO FLY AGAIN"
			% [score, "   NEW BEST!" if new_best else "   BEST %d" % best, $AlienAstronaut.hits])


func _on_darth_shot() -> void:
	if _over:
		return
	bonus += darth_hit_points
	var alien: Node2D = $AlienAstronaut
	# Floating "+100" at Darth.
	var label := Label.new()
	label.text = "+%d" % darth_hit_points
	var ls := LabelSettings.new()
	ls.font = hud.p2_label.label_settings.font
	ls.font_size = 64
	ls.font_color = Color(1.0, 0.9, 0.3)
	ls.outline_size = 8
	ls.outline_color = Color.BLACK
	label.label_settings = ls
	label.position = alien.global_position + Vector2(-60, -120)
	label.z_index = 60
	add_child(label)
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "position:y", label.position.y - 120.0, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(label.queue_free)


## F11 switches between fullscreen and a window.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("score", "best", 0))


func _save_best(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", value)
	cfg.save(SAVE_PATH)


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
