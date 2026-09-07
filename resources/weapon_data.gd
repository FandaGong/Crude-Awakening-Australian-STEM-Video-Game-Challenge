extends Resource
class_name WeaponData

@export var id: String = "starter_spear"
@export var weapon_name: String = "Heal Laser"
@export var description: String = "The robot's default curing laser, fired through the Bone Spear emitter."
@export var cost: int = 0
@export var damage: float = 10.0
@export var fire_rate: float = 0.4 # seconds between shots
@export var bullet_speed: float = 500.0
@export var color: Color = Color(0.9, 0.9, 0.9)
