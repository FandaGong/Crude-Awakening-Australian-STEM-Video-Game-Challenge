extends Resource
class_name BossData

@export var id: int = 1
@export var boss_name: String = "Unnamed Horror"
@export var max_health: float = 150.0
@export var crystal_reward: int = 50
@export var drop_item_paths: Array[String] = []
@export var depth_meters: int = 100
@export var bullet_speed_mult: float = 1.0
@export var pattern_interval: float = 1.5 # seconds between attack volleys
@export var color: Color = Color(0.8, 0.2, 0.2)

## Which scripted attack pattern this boss uses. "generic" keeps the old
## radial/aimed/spiral bullet-hell so the existing ten bosses are untouched.
## Set to "shell", "jellyfish", "crab", "anglerfish", "whale", or "kraken"
## to get the specific fight described in the design doc.
@export var boss_type: String = "generic"
@export var body_damage: float = 0.0 # contact damage, used by crab/whale

## Blue Whale can't be cured by the normal curing beam/abilities at all -
## it has to be cured by swimming through its blowhole (see boss.gd).
@export var curable_by_normal_means: bool = true
