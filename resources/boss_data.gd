extends Resource
class_name BossData

@export var id: int = 1
@export var boss_name: String = "Unnamed Horror"
@export var max_health: float = 150.0
@export var crystal_reward: int = 50
@export var depth_meters: int = 100
@export var bullet_speed_mult: float = 1.0
@export var pattern_interval: float = 1.5 # seconds between attack volleys
@export var color: Color = Color(0.8, 0.2, 0.2)
