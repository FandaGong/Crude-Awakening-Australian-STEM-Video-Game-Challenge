extends Node2D

# Boss arena

signal boss_defeated(boss_id: int)

const BossScene := preload("res://bosses/boss.tscn")
const ARENA_RADIUS := 420.0

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_spawn: Marker2D = $BossSpawn
@onready var walls: Node2D = $Walls

var boss_instance: Node = null

func setup(boss_data: BossData) -> void:
	if boss_instance and is_instance_valid(boss_instance):
		boss_instance.queue_free()

	boss_instance = BossScene.instantiate()
	boss_instance.boss_data = boss_data
	add_child(boss_instance)
	boss_instance.global_position = boss_spawn.global_position
	boss_instance.defeated.connect(_on_boss_defeated)

func _on_boss_defeated(boss_id: int) -> void:
	boss_defeated.emit(boss_id)
