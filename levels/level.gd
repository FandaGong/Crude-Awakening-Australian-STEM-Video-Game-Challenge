extends Node2D

## One hand-drawn Historical Turning Point level.
##
## Drag PlayerSpawn, BossSpawn, and MobSpawnCenter (all Marker2D nodes) around
## in the editor to place them wherever you like on top of whatever terrain
## you paint into the Ground tile map layer.
##
## The boss is instanced separately by world.gd only after this level's
## preloaded field mobs have all been cured.

signal mobs_cleared

const MutantMobScene := preload("res://mutantMob.tscn")
const AirBubbleScene := preload("res://pickups/air_bubble.tscn")

@export_range(1, 30, 1) var mob_count := 8
@export_range(0, 10, 1) var sponges_per_level := 2
@export_range(0, 10, 1) var bubbles_per_level := 3
@export var mob_spawn_size := Vector2(1100, 460)
@export var mob_type: MutantMob.MobType = MutantMob.MobType.SHELL

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_spawn: Marker2D = $BossSpawn
@onready var mob_spawn_center: Marker2D = $MobSpawnCenter
@onready var water_collision: CollisionShape2D = $waterArea/CollisionShape2D
@onready var ground: TileMapLayer = get_node_or_null("Ground")

## Random spawn positions get re-rolled up to this many times if they land
## on a solid (wall/terrain) tile before giving up and using the last roll.
const MAX_SPAWN_ATTEMPTS := 20

var _remaining_mobs := 0

func set_mobs_active(active: bool) -> void:
	for mob in get_tree().get_nodes_in_group("corrupted_mobs"):
		if mob.get_parent() == self:
			mob.set("encounter_active", active)

func _ready() -> void:
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
	var candidate := mob_spawn_center.global_position
	for attempt in range(MAX_SPAWN_ATTEMPTS):
		candidate = mob_spawn_center.global_position + Vector2(
			randf_range(-half_size.x, half_size.x), randf_range(-half_size.y, half_size.y)
		)
		if not _is_inside_wall(candidate):
			return candidate
	# Couldn't find a clear spot after MAX_SPAWN_ATTEMPTS tries (very cramped
	# level) - fall back to the last roll rather than spawning at dead center
	# every time.
	return candidate

## True if the given global position lands on a Ground tile that has
## collision (i.e. a wall/solid terrain tile, as opposed to open water,
## which has no tile there at all).
func _is_inside_wall(global_pos: Vector2) -> bool:
	if not ground:
		return false
	var cell := ground.local_to_map(ground.to_local(global_pos))
	var tile_data := ground.get_cell_tile_data(cell)
	if not tile_data:
		return false
	return tile_data.get_collision_polygons_count(0) > 0

func _on_mob_cured(_mob: MutantMob) -> void:
	_remaining_mobs = max(0, _remaining_mobs - 1)
	if _remaining_mobs == 0:
		mobs_cleared.emit()

## True once every preloaded field mob has already been cured. Used when
## re-entering a level (e.g. after dying to its boss) to tell whether the
## one-shot mobs_cleared signal has already fired and won't fire again.
func mobs_already_cleared() -> bool:
	return _remaining_mobs <= 0

func reset_encounter() -> void:
	for child in get_children():
		if child is MutantMob:
			child.free()
	_remaining_mobs = mob_count + sponges_per_level
	_spawn_preloaded_mobs()
	set_mobs_active(false)
