extends Resource
class_name BossData

@export var id: int = 1
@export var boss_name: String = "Unnamed Horror"
@export var max_health: float = 150.0
@export var drop_item_paths: Array[String] = []
@export var depth_meters: int = 100
@export var bullet_speed_mult: float = 1.0
@export var pattern_interval: float = 1.5 # seconds between attack volleys
@export var color: Color = Color(0.8, 0.2, 0.2)

# Boss attack pattern
@export var boss_type: String = "generic"
@export var body_damage: float = 0.0 # contact damage, used by crab/whale

# Whale blowhole cure
@export var curable_by_normal_means: bool = true
