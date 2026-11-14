extends Area2D
## A power-up floating on the map. The first ship to fly through it takes it,
## as long as that ship has a free slot (otherwise it stays put).
## A weapon capsule (red, "WEAPON" tag) applies to the ship's basic laser right
## away for 20 s instead and doesn't use a slot.

const CAPSULE := preload("res://assets/kenney_space_shooter_redux/powerups/powerupYellow.png")
const WEAPON_CAPSULE := preload("res://assets/kenney_space_shooter_redux/powerups/powerupRed.png")
const FONT := preload("res://assets/kenney_space_shooter_redux/fonts/kenvector_future.ttf")
const PICKUP_SOUND := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_shieldUp.ogg")

var kind := 0
## A PowerUps.Weapon value for a weapon capsule, or -1 for a held power-up.
var weapon := -1
var _t := 0.0
var _body: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # ships
	var shape := CircleShape2D.new()
	shape.radius = 55.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_body = Sprite2D.new()
	_body.texture = WEAPON_CAPSULE if weapon > 0 else CAPSULE
	_body.scale = Vector2.ONE * 2.6
	add_child(_body)
	var icon := Sprite2D.new()
	icon.texture = PowerUps.WEAPON_ICONS[weapon] if weapon > 0 else PowerUps.ICONS[kind]
	icon.scale = Vector2.ONE * (24.0 / maxf(icon.texture.get_width(), icon.texture.get_height()))
	_body.add_child(icon)
	var label := Label.new()
	label.text = ("WEAPON: " + PowerUps.WEAPON_NAMES[weapon]) if weapon > 0 else PowerUps.NAMES[kind]
	var ls := LabelSettings.new()
	ls.font = FONT
	ls.font_size = 30
	ls.outline_size = 6
	ls.outline_color = Color.BLACK
	label.label_settings = ls
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(400, 40)
	label.position = Vector2(-200, 48)
	add_child(label)


func _physics_process(delta: float) -> void:
	_t += delta
	# Always upright, gently bobbing, whatever the level node's rotation is.
	global_rotation = 0.0
	_body.rotation = sin(_t * 2.5) * 0.2
	_body.scale = Vector2.ONE * (2.6 + 0.15 * sin(_t * 4.0))
	for body in get_overlapping_bodies():
		if not (body.is_in_group("player") and body.alive):
			continue
		var taken: bool = body.set_weapon(weapon) if weapon > 0 else body.add_item(kind)
		if taken:
			var scene := get_tree().current_scene
			Fx.sound(scene, PICKUP_SOUND, -6.0)
			Fx.flash(scene, global_position, CAPSULE, 4.0, 0.3)
			queue_free()
			return
