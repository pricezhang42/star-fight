extends Node2D
## Darth (player 2): an alien astronaut that runs along a fixed rectangular
## track around the edge of the screen (arrow keys), throws a comet at the
## mouse every few seconds (left click), and picks up a random item every few
## seconds that can be used with right click (mouse wheel / Shift to switch).

signal hits_changed(hits: int)
signal cooldown_changed(ready_fraction: float)
signal items_changed(items: Array, selected: int)

const COMET := preload("res://scenes/comet.tscn")
const FLASH_BANG := preload("res://scripts/flash_bang.gd")
const LASER := preload("res://scripts/laser_beam.gd")
const HUNTER := preload("res://scenes/hunter.tscn")
const PICKUP_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_shieldUp.ogg")
const USE_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_zap.ogg")

enum Item { CHAOS, FLASH_BANG, HUNTER, LASER, GIANT }
const ITEM_NAMES := ["CHAOS", "FLASH", "HUNTER", "LASER", "GIANT"]

@export var item_interval := 5.0
@export var max_items := 3
@export var chaos_seconds := 2.0
@export var giant_seconds := 3.0

@export var speed := 900.0 ## world pixels per second along the track
## Gap between the track and the screen edge, in screen pixels.
@export var inset := 50.0
@export var throw_cooldown := 4.0
@export var comet_speed := 560.0

var hits := 0
## Position along the track, 0..1 (clockwise from the top-left corner).
var track_pos := -1.0 ## set on the first frame to the middle of the left edge
var _cooldown := 1.5
var _track_local := Rect2()
var items: Array[int] = []
var selected := 0
var _item_timer := 5.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var aim: Line2D = $Aim
@onready var throw_sound: AudioStreamPlayer = $ThrowSound


func _process(delta: float) -> void:
	var rect := _track_rect()
	if track_pos < 0.0:
		var w := rect.size.x
		var h := rect.size.y
		track_pos = (2.0 * w + 1.5 * h) / (2.0 * (w + h))
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

	# Items.
	_item_timer -= delta
	if _item_timer <= 0.0:
		_item_timer = item_interval
		if items.size() < max_items:
			items.append(randi() % Item.size())
			Fx.sound(get_tree().current_scene, PICKUP_SOUND, -6.0)
			_items_updated()
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
## next edge turns onto it.
func _step_along_track(rect: Rect2, input: Vector2, dist: float) -> void:
	var perimeter := 2.0 * (rect.size.x + rect.size.y)
	var step := dist / perimeter
	var here := _point_on(rect, track_pos)
	var best := 0.0
	var best_score := 0.3 # needs to point at least roughly the right way
	for dir in [1.0, -1.0]:
		var ahead := _point_on(rect, wrapf(track_pos + dir * 0.002, 0.0, 1.0))
		var score := (ahead - here).normalized().dot(input.normalized())
		if score > best_score:
			best_score = score
			best = dir
	if best == 0.0:
		return
	# Stop exactly at a corner instead of overshooting onto the next edge,
	# so the player can choose which way to turn there.
	var w := rect.size.x
	var corners := [0.0, w / perimeter, 0.5, 0.5 + w / perimeter, 1.0]
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
	track_pos = wrapf(target, 0.0, 1.0)


## Point at fraction t (0..1) of the way round the rectangle, clockwise from
## the top-left corner.
func _point_on(rect: Rect2, t: float) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	var d := t * 2.0 * (w + h)
	if d < w:
		return rect.position + Vector2(d, 0)
	d -= w
	if d < h:
		return rect.position + Vector2(w, d)
	d -= h
	if d < w:
		return rect.position + Vector2(w - d, h)
	d -= w
	return rect.position + Vector2(0, h - d)


func _draw() -> void:
	# Faint dashed outline of the track.
	var r := _track_local
	var c := Color(0.5, 1.0, 0.6, 0.25)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], c, 6.0, 30.0)
