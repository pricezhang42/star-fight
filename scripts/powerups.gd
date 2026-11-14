class_name PowerUps
## The power-up items: names and icons, shared by pickups, ships and the HUD.

enum Kind { LASER, SHRINK, MISSILE, CHAOS, GRENADE, SHIELD }

const NAMES := ["LASER", "SHRINK", "MISSILE", "CHAOS", "GRENADE", "SHIELD"]
const ICONS := [
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupRed_bolt.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/pill_green.png"),
	preload("res://assets/kenney_space_shooter_extension/spaceMissiles_004.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupYellow_bolt.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/powerupBlue_star.png"),
	preload("res://assets/kenney_space_shooter_redux/powerups/shield_gold.png"),
]

## Weapon pickups change the basic laser as soon as they're collected, for
## 20 s. NONE is the normal laser.
enum Weapon { NONE, RAPID, ROCKET }
const WEAPON_NAMES := ["LASER", "RAPID LASER", "ROCKET"]
const WEAPON_ICONS := [
	null,
	preload("res://assets/kenney_space_shooter_redux/powerups/bolt_gold.png"),
	preload("res://assets/kenney_space_shooter_extension/spaceMissiles_001.png"),
]
## Share of map capsules that are weapons rather than held power-ups.
const WEAPON_CHANCE := 0.25
const MAX_HELD := 2


static func random_kind() -> int:
	return randi() % Kind.size()


static func random_weapon() -> int:
	return 1 + randi() % (Weapon.size() - 1)
