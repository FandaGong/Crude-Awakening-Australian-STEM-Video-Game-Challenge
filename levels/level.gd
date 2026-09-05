extends Node2D

## One hand-drawn Historical Turning Point level.
##
## Drag PlayerSpawn, BossSpawn, TraderSpawn, and MobSpawnCenter (all Marker2D nodes) around
## in the editor to place them wherever you like on top of whatever terrain
## you paint into the Ground tile map layer.
##
## The trader stands here permanently from the moment the level loads - it's
## instanced once, at TraderSpawn's position, in _ready() below. The boss is
## instanced separately by world.gd only after this level's preloaded field
## mobs have all been cured.

signal mobs_cleared

const MerchantScene := preload("res://npc/merchant.tscn")
const MutantMobScene := preload("res://mutantMob.tscn")
const AirBubbleScene := preload("res://pickups/air_bubble.tscn")

@export_range(1, 30, 1) var mob_count := 8
@export_range(0, 10, 1) var sponges_per_level := 2
@export_range(0, 10, 1) var bubbles_per_level := 3
@export var mob_spawn_size := Vector2(1100, 460)
@export var mob_type: MutantMob.MobType = MutantMob.MobType.SHELL

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_spawn: Marker2D = $BossSpawn
@onready var trader_spawn: Marker2D = $TraderSpawn
@onready var mob_spawn_center: Marker2D = $MobSpawnCenter
@onready var water_collision: CollisionShape2D = $waterArea/CollisionShape2D

var _remaining_mobs := 0

func set_mobs_active(active: bool) -> void:
	for mob in get_tree().get_nodes_in_group("corrupted_mobs"):
		if mob.get_parent() == self:
			mob.set("encounter_active", active)

func _ready() -> void:
	if trader_spawn:
		var merchant := MerchantScene.instantiate()
		add_child(merchant)
		merchant.global_position = trader_spawn.global_position
		merchant.interacted.connect(_on_merchant_interacted)
	_spawn_preloaded_mobs()

func _spawn_preloaded_mobs() -> void:
	_remaining_mobs = mob_count + sponges_per_level
	for i in range(mob_count):
		_spawn_level_mob(mob_type)
	for i in range(sponges_per_level):
		_spawn_level_mob(MutantMob.MobType.SPONGE)
	for i in range(bubbles_per_level):
		var bubble := AirBubbleScene.instantiate()
		add_child(bubble)
		bubble.global_position = _random_spawn_position()

func _spawn_level_mob(type: MutantMob.MobType) -> void:
	var mob := MutantMobScene.instantiate()
	mob.mob_type = type
	mob.trash_size = ["small", "medium", "large"][randi_range(0, 2)]
	add_child(mob)
	mob.global_position = _random_spawn_position()
	mob.cured.connect(_on_mob_cured)

func _random_spawn_position() -> Vector2:
	var half_size := mob_spawn_size * 0.5
	return mob_spawn_center.global_position + Vector2(
		randf_range(-half_size.x, half_size.x), randf_range(-half_size.y, half_size.y)
	)

func _on_mob_cured(_mob: MutantMob) -> void:
	_remaining_mobs = max(0, _remaining_mobs - 1)
	if _remaining_mobs == 0:
		mobs_cleared.emit()

func _on_merchant_interacted() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("open_shop"):
		world.open_shop()
