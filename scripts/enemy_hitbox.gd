extends Area2D
## Damages the player while overlapping. Attach to an Area2D on any alien.


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_hit"):
			body.take_hit(global_position)
