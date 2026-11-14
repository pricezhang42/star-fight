class_name PowerUps
## The power-up items: names and icons, shared by pickups, ships and the HUD.

enum Kind { LASER, SHRINK, MISSILE, CHAOS, GRENADE }

const NAMES := ["LASER", "SHRINK", "MISSILE", "CHAOS", "GRENADE"]
const ICONS := [
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupRed_bolt.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/pill_green.png"),
	preload("res://assets/kenney_space_shooter_extension/spaceMissiles_004.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupYellow_bolt.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupBlue_star.png"),
]
const MAX_HELD := 2


static func random_kind() -> int:
	return randi() % Kind.size()
