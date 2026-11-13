@tool
extends StaticBody2D
## A solid planet. Flying into it costs a life and bounces the ship off.
## Satellites can be added as children (see satellite.gd).

@export var radius := 170.0:
	set(v):
		radius = v
		_apply()
@export var texture: Texture2D:
	set(v):
		texture = v
		_apply()
@export var spin_speed := 0.05
## How much of the picture's width the planet disc covers.
const DISC_FRACTION := 0.86


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		$Sprite2D.rotation += spin_speed * delta


func _apply() -> void:
	if not is_inside_tree():
		return
	var sprite: Sprite2D = $Sprite2D
	sprite.texture = texture
	if texture:
		var s := radius * 2.0 / (texture.get_width() * DISC_FRACTION)
		sprite.scale = Vector2(s, s)
	var shape := CircleShape2D.new()
	shape.radius = radius * 0.95
	$CollisionShape2D.shape = shape
