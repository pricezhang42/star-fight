@tool
extends StaticBody2D
## A clump of asteroids scattered inside a circle. Regenerates live in the
## editor. For a strip of asteroids use MeteorWall (rotate it for diagonals).

@export var radius := 150.0:
	set(v):
		radius = v
		_rebuild()
@export var count := 10:
	set(v):
		count = v
		_rebuild()
@export var rock_scale := 0.8:
	set(v):
		rock_scale = v
		_rebuild()
@export var random_seed := 1:
	set(v):
		random_seed = v
		_rebuild()

const TEXTURES := [
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_big1.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_big2.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_big3.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_big4.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorBrown_med1.png"),
	preload("res://assets/kenney_space_shooter_redux/meteors/meteorGrey_med1.png"),
]
const ROCK := preload("res://scenes/rock.tscn")
const BIG_RADIUS := 42.0
const MED_RADIUS := 20.0


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
	var placed: Array[Vector3] = [] # x, y, radius
	var tries := 0
	while placed.size() < count and tries < count * 40:
		tries += 1
		var idx := rng.randi() % TEXTURES.size()
		var s := rock_scale * rng.randf_range(0.8, 1.15)
		var r := (BIG_RADIUS if idx < 4 else MED_RADIUS) * s
		var pos := Vector2.RIGHT.rotated(rng.randf() * TAU) * sqrt(rng.randf()) * radius
		var ok := true
		for p in placed:
			if pos.distance_to(Vector2(p.x, p.y)) < (r + p.z) * 0.85:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector3(pos.x, pos.y, r))
		if not Engine.is_editor_hint():
			# In game every rock is its own physics object (see rock.gd).
			var rock := ROCK.instantiate()
			rock.texture = TEXTURES[idx]
			rock.position = pos
			rock.rotation = rng.randf() * TAU
			rock.sprite_scale = s
			rock.radius = r * 0.9
			rock.hp = 3 if idx < 4 else 1
			rock.set_meta("generated", true)
			add_child(rock)
			continue
		var spr := Sprite2D.new()
		spr.texture = TEXTURES[idx]
		spr.position = pos
		spr.rotation = rng.randf() * TAU
		spr.scale = Vector2(s, s)
		spr.set_meta("generated", true)
		add_child(spr)
		var shape := CircleShape2D.new()
		shape.radius = r * 0.9
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = pos
		cs.set_meta("generated", true)
		add_child(cs)
