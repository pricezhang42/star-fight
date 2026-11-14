extends Node2D
## Darth (player 2): an alien astronaut that runs along a fixed rectangular
## track around the edge of the screen (arrow keys), throws a comet at the
## mouse every few seconds (left click), and collects item crates that appear
## on the track; items are used with right click (mouse wheel to switch).

signal hits_changed(hits: int)
signal cooldown_changed(ready_fraction: float)
signal items_changed(items: Array, selected: int)
## Luke's laser hit Darth (Luke earns points).
signal shot_by_luke

const COMET := preload("res://scenes/comet.tscn")
const FLASH_BANG := preload("res://scripts/flash_bang.gd")
const LASER := preload("res://scripts/laser_beam.gd")
const HUNTER := preload("res://scenes/hunter.tscn")
const PICKUP_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_shieldUp.ogg")
const CRATE_TEX := preload("res://assets/kenney_space_shooter_redux/powerups/powerupYellow.png")
const CRATE_FONT := preload("res://assets/kenney_space_shooter_redux/fonts/kenvector_future.ttf")
## Same icons as Darth's item bar in the HUD (order matches Item).
const ITEM_ICONS := [
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupYellow_bolt.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupBlue_star.png"),
	preload("res://assets/kenney_space_shooter_redux/enemies/enemyBlack1.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupRed_bolt.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupGreen_shield.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/pill_blue.png"),
]
const USE_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_zap.ogg")

enum Item { CHAOS, FLASH_BANG, HUNTER, LASER, GIANT, SLICK }
const ITEM_NAMES := ["CHAOS", "FLASH", "HUNTER", "LASER", "GIANT", "SLICK"]

## Seconds between new crates appearing on the track (random in this range).
@export var crate_interval := Vector2(6.0, 8.0)
@export var crate_lifetime := 8.0
@export var max_crates := 2
## How close (world px along the track) Darth must get to grab a crate.
@export var pickup_distance := 90.0
@export var max_items := 3
@export var chaos_seconds := 2.0
@export var giant_seconds := 3.0
@export var slick_seconds := 4.0

@export var speed := 900.0 ## world pixels per second along the track
## Gap between the track and the screen edge, in screen pixels.
@export var inset := 50.0
@export var throw_cooldown := 4.0
@export var comet_speed := 850.0

var hits := 0
## Position along the track, 0..1 (clockwise from the top-left corner).
## Position along the U-shaped track, 0..1: from the top of the left edge,
## down, along the bottom, and up the right edge. There is no top edge, so
## the two top corners are dead ends. Set on the first frame to the middle of
## the left edge.
var track_pos := -1.0
var _cooldown := 1.5
var _track_local := Rect2()
var items: Array[int] = []
var selected := 0
var _item_timer := 4.0 ## time until the next crate appears
## Crates on the track: each is {"t": track fraction, "life": seconds, "node": Sprite2D}.
var _crates: Array = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var aim: Line2D = $Aim
@onready var throw_sound: AudioStreamPlayer = $ThrowSound


func _process(delta: float) -> void:
	_hit_grace = maxf(0.0, _hit_grace - delta)
	var rect := _track_rect()
	if track_pos < 0.0:
		track_pos = 0.5 * rect.size.y / _track_length(rect)
	var input := Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")
	if input.length() > 0.1:
		_step_along_track(rect, input, speed * delta)
	global_position = _point_on(rect, track_pos)
	sprite.rotation += delta * 1.5
	_track_local = Rect2(rect.position - global_position, rect.size)
	queue_redraw()

	# Aim line toward the mouse, shown while the throw is ready.
	var mouse := get_global_mouse_position()
	aim.visible = _cooldown <= 0.0
	aim.points = PackedVector2Array([Vector2.ZERO, (mouse - global_position).limit_length(260.0)])

	var was := _cooldown
	_cooldown = maxf(0.0, _cooldown - delta)
	if was != _cooldown or _cooldown == 0.0:
		cooldown_changed.emit(1.0 - _cooldown / throw_cooldown)
	if _cooldown <= 0.0 and Input.is_action_just_pressed("p2_throw"):
		_throw(mouse)

	# Item crates on the track: Darth has to run over them to collect.
	_update_crates(rect, delta)
	if items.size() > 0:
		if Input.is_action_just_pressed("p2_next"):
			selected = (selected + 1) % items.size()
			_items_updated()
		if Input.is_action_just_pressed("p2_prev"):
			selected = (selected - 1 + items.size()) % items.size()
			_items_updated()
		if Input.is_action_just_pressed("p2_use"):
			use_item(mouse)


func _throw(target: Vector2) -> void:
	_cooldown = throw_cooldown
	var dir := (target - global_position).normalized()
	var comet := COMET.instantiate()
	comet.setup(global_position + dir * 50.0, dir * comet_speed, 1.6)
	comet.thrower = self
	get_tree().current_scene.add_child(comet)
	throw_sound.play()


func _update_crates(rect: Rect2, delta: float) -> void:
	var perimeter := _track_length(rect)
	# Spawn.
	_item_timer -= delta
	if _item_timer <= 0.0:
		_item_timer = randf_range(crate_interval.x, crate_interval.y)
		if _crates.size() < max_crates:
			# Somewhere Darth has to travel to: at least 15% of the track away.
			var t := randf()
			for attempt in 10:
				if absf(t - track_pos) >= 0.15:
					break
				t = randf()
			# The crate's item is decided now and shown on it.
			var item := randi() % Item.size()
			var spr := Sprite2D.new()
			spr.texture = CRATE_TEX
			spr.scale = Vector2.ONE * 2.6
			spr.top_level = true
			spr.z_index = 9
			add_child(spr)
			var icon := Sprite2D.new()
			icon.texture = ITEM_ICONS[item]
			# Fit the icon inside the crate (icons come in different sizes).
			icon.scale = Vector2.ONE * (22.0 / maxf(icon.texture.get_width(), icon.texture.get_height()))
			icon.z_index = 1
			spr.add_child(icon)
			var label := Label.new()
			label.text = ITEM_NAMES[item]
			var ls := LabelSettings.new()
			ls.font = CRATE_FONT
			ls.font_size = 13
			ls.outline_size = 4
			ls.outline_color = Color.BLACK
			label.label_settings = ls
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.size = Vector2(80, 16)
			label.position = Vector2(-40, 16)
			label.z_index = 1
			spr.add_child(label)
			_crates.append({"t": t, "life": crate_lifetime, "node": spr, "item": item})
	# Update, blink, collect, expire.
	for i in range(_crates.size() - 1, -1, -1):
		var c: Dictionary = _crates[i]
		c.life -= delta
		var spr: Sprite2D = c.node
		spr.global_position = _point_on(rect, c.t)
		spr.rotation = sin(c.life * 3.0) * 0.15
		spr.visible = c.life > 2.0 or fmod(c.life, 0.3) > 0.12
		var gap := absf(c.t - track_pos) * perimeter
		if gap < pickup_distance and items.size() < max_items:
			items.append(c.item)
			Fx.sound(get_tree().current_scene, PICKUP_SOUND, -6.0)
			Fx.flash(get_tree().current_scene, spr.global_position, CRATE_TEX, 4.0, 0.3)
			_items_updated()
			spr.queue_free()
			_crates.remove_at(i)
		elif c.life <= 0.0:
			spr.queue_free()
			_crates.remove_at(i)


## Use the selected item, aimed at `target` (world position) where relevant.
func use_item(target: Vector2) -> void:
	if items.is_empty():
		return
	selected = clampi(selected, 0, items.size() - 1)
	var item: int = items[selected]
	items.remove_at(selected)
	if selected >= items.size():
		selected = maxi(0, items.size() - 1)
	_items_updated()
	var scene := get_tree().current_scene
	var luke: Node2D = get_tree().get_first_node_in_group("player")
	match item:
		Item.CHAOS:
			if luke:
				luke.apply_chaos(chaos_seconds)
		Item.GIANT:
			if luke:
				luke.apply_giant(giant_seconds)
		Item.SLICK:
			if luke:
				luke.apply_slick(slick_seconds)
		Item.FLASH_BANG:
			var fb := Node2D.new()
			fb.set_script(FLASH_BANG)
			fb.position = target
			scene.add_child(fb)
		Item.HUNTER:
			var h := HUNTER.instantiate()
			var dir: Vector2 = (luke.global_position - global_position).normalized() if luke else Vector2.RIGHT
			h.position = global_position + dir * 60.0
			h.rotation = dir.angle()
			scene.add_child(h)
		Item.LASER:
			var beam := Node2D.new()
			beam.set_script(LASER)
			beam.setup(global_position, target - global_position)
			beam.hit_luke.connect(scored_hit)
			scene.add_child(beam)
	Fx.sound(scene, USE_SOUND, -6.0)


func _items_updated() -> void:
	items_changed.emit(items, selected)


## Luke's lasers can hit Darth. Each hit gives Luke points (handled by main).
## A short grace period stops one burst from counting many times.
var _hit_grace := 0.0
const HIT_GRACE := 0.05


func take_damage(_amount: int) -> void:
	if _hit_grace > 0.0:
		return
	_hit_grace = HIT_GRACE
	sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "modulate", Color(0.7, 1, 0.6, 1), 0.25)
	shot_by_luke.emit()


## Called by a thrown comet when it damages the ship.
func scored_hit() -> void:
	hits += 1
	hits_changed.emit(hits)


## The visible screen in world coordinates, shrunk by the inset.
func _track_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var size := get_viewport().get_visible_rect().size / cam.zoom
	var pad := inset / cam.zoom.x
	var view := Rect2(cam.get_screen_center_position() - size / 2.0, size)
	return view.grow(-pad)


## Move along the track in whichever direction best matches the arrow keys.
## Pressing "along" an edge moves along it; at a corner, pressing toward the
## next edge (or the way you were going) turns onto it. The two top ends of
## the U are dead ends.
func _step_along_track(rect: Rect2, input: Vector2, dist: float) -> void:
	var total := _track_length(rect)
	var step := dist / total
	var here := _point_on(rect, track_pos)
	var best := 0.0
	var best_score := 0.3 # needs to point at least roughly the right way
	for dir in [1.0, -1.0]:
		var ahead := _point_on(rect, clampf(track_pos + dir * 0.002, 0.0, 1.0))
		if ahead.is_equal_approx(here):
			continue # at a dead end
		var score := (ahead - here).normalized().dot(input.normalized())
		if score > best_score:
			best_score = score
			best = dir
	if best == 0.0:
		# At a corner, pressing the way you were going (e.g. left at the
		# bottom-left corner) carries on round the corner onto the next edge.
		for dir in [1.0, -1.0]:
			var behind := _point_on(rect, clampf(track_pos - dir * 0.002, 0.0, 1.0))
			if behind.is_equal_approx(here):
				continue
			var ahead := _point_on(rect, clampf(track_pos + dir * 0.002, 0.0, 1.0))
			if ahead.is_equal_approx(here):
				continue
			var score := (here - behind).normalized().dot(input.normalized())
			if score > best_score:
				best_score = score
				best = dir
	if best == 0.0:
		return
	# Stop exactly at a corner instead of overshooting onto the next edge,
	# so the player can choose which way to turn there.
	var corners := [rect.size.y / total, (rect.size.y + rect.size.x) / total]
	var target := track_pos + best * step
	if best > 0.0:
		for k in corners:
			if track_pos < k - 0.00001 and target >= k:
				target = k
				break
	else:
		for i in range(corners.size() - 1, -1, -1):
			var k: float = corners[i]
			if track_pos > k + 0.00001 and target <= k:
				target = k
				break
	track_pos = clampf(target, 0.0, 1.0)


## Length of the U: left edge + bottom + right edge.
func _track_length(rect: Rect2) -> float:
	return 2.0 * rect.size.y + rect.size.x


## Point at fraction t (0..1) along the U: down the left edge from the top,
## along the bottom, then up the right edge.
func _point_on(rect: Rect2, t: float) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	var d := clampf(t, 0.0, 1.0) * _track_length(rect)
	if d < h:
		return rect.position + Vector2(0, d)
	d -= h
	if d < w:
		return rect.position + Vector2(d, h)
	d -= w
	return rect.position + Vector2(w, h - d)


func _draw() -> void:
	# Faint dashed outline of the track: left, bottom and right (no top).
	var r := _track_local
	var c := Color(0.5, 1.0, 0.6, 0.25)
	var tl := r.position
	var bl := Vector2(r.position.x, r.end.y)
	var br := r.end
	var tr := Vector2(r.end.x, r.position.y)
	draw_dashed_line(tl, bl, c, 6.0, 30.0)
	draw_dashed_line(bl, br, c, 6.0, 30.0)
	draw_dashed_line(br, tr, c, 6.0, 30.0)
