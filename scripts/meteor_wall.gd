@tool
extends StaticBody2D
## A line of meteors that acts as a barrier. Optionally leaves a gap the
## player can fly through. Regenerates live in the editor when edited.

@export var length := 1200.0:
	set(v):
		length = v
		_rebuild()
@export var vertical := true:
	set(v):
		vertical = v
		_rebuild()
## Distance along the wall where the gap is centred.
@export var gap_center := 600.0:
	set(v):
		gap_center = v
		_rebuild()
## Clear space in the gap. 0 = solid wall.
@export var gap_size := 0.0:
	set(v):
		gap_size = v
		_rebuild()
@export var spacing := 72.0:
	set(v):
		spacing = maxf(v, 20.0)
		_rebuild()
@export var rock_scale := 0.85:
	set(v):
		rock_scale = v
		_rebuild()
@export var brown := false:
	set(v):
		brown = v
		_rebuild()
@export var random_seed := 1:
	set(v):
		random_seed = v
		_rebuild()

const GREY := [
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_big1.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_big2.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_big3.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_big4.png"),
]
const BROWN := [
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_big1.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_big2.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_big3.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_big4.png"),
]
const ROCK_RADIUS := 42.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("generated"):
			remove_child(c)
			c.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var textures: Array = BROWN if brown else GREY
	var radius := ROCK_RADIUS * rock_scale
	var t := 0.0
	while t <= length + 0.1:
		var in_gap := gap_size > 0.0 and absf(t - gap_center) < gap_size * 0.5 + radius
		if not in_gap:
			var jitter := rng.randf_range(-8.0, 8.0)
			var pos := Vector2(jitter, t) if vertical else Vector2(t, jitter)
			var s := rock_scale * rng.randf_range(0.9, 1.1)

			var spr := Sprite2D.new()
			spr.texture = textures[rng.randi() % textures.size()]
			spr.position = pos
			spr.rotation = rng.randf() * TAU
			spr.scale = Vector2(s, s)
			spr.set_meta("generated", true)
			add_child(spr)

			var shape := CircleShape2D.new()
			shape.radius = ROCK_RADIUS * s * 0.9
			var cs := CollisionShape2D.new()
			cs.shape = shape
			cs.position = pos
			cs.set_meta("generated", true)
			add_child(cs)
		t += spacing
