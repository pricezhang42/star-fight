class_name Alien
## Shared health, shooting and death for alien ships. Used as a helper node
## so both CharacterBody2D chasers and Node2D patrollers can use it.

const BULLET := preload("res://scenes/bullet.tscn")
const BOOM_TEX := preload("res://assets/kenney_space_shooter_redux/lasers/laserRed08.png")
const ZAP := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_zap.ogg")
const SHOOT := preload("res://assets/kenney_space_shooter_redux/sounds/sfx_laser2.ogg")
const BULLET_SPEED := 430.0


static func fire(owner_node: Node2D, dir: Vector2, muzzle := 34.0) -> void:
	var b := BULLET.instantiate()
	b.setup(owner_node.global_position + dir.normalized() * muzzle, dir, false, BULLET_SPEED)
	owner_node.get_tree().current_scene.add_child(b)
	Fx.sound(owner_node.get_tree().current_scene, SHOOT, -10.0)


static func hurt_flash(sprite: CanvasItem) -> void:
	if not sprite.has_meta("base_modulate"):
		sprite.set_meta("base_modulate", sprite.modulate)
	sprite.modulate = Color(3, 3, 3)
	sprite.create_tween().tween_property(sprite, "modulate", sprite.get_meta("base_modulate"), 0.15)


static func explode(owner_node: Node2D) -> void:
	var scene := owner_node.get_tree().current_scene
	Fx.flash(scene, owner_node.global_position, BOOM_TEX, 2.2, 0.4)
	Fx.sound(scene, ZAP, -4.0)
	owner_node.queue_free()


static func find_player(node: Node) -> Node2D:
	var p := node.get_tree().get_first_node_in_group("player") as Node2D
	if p and p.alive:
		return p
	return null
