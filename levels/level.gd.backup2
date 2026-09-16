extends Node2D

# Historical level

signal mobs_cleared

const MutantMobScene := preload("res://mutantMob.tscn")
const AirBubbleScene := preload("res://pickups/air_bubble.tscn")
const HealingPadScene := preload("res://effects/healing_pad.tscn")

@export_range(1, 30, 1) var mob_count := 8
@export_range(1, 30, 1) var bubbles_per_level := 12
@export_range(1.0, 120.0, 1.0, "suffix:s") var bubble_spawn_interval := 20.0
@export var mob_spawn_size := Vector2(1100, 460)
@export var mob_type: MutantMob.MobType = MutantMob.MobType.SHELL
@export var randomize_field_mobs := false
@export var previous_mob_types: Array[MutantMob.MobType] = [
	MutantMob.MobType.SHELL,
	MutantMob.MobType.JELLYFISH,
	MutantMob.MobType.CRAB,
	MutantMob.MobType.ANGLERFISH,
]

# Spawn settings
@export var max_spawn_attempts: int = 80
@export var mob_spawn_clearance: float = 28.0

# Scene nodes
@export var player_spawn: Marker2D
@export var boss_spawn: Marker2D
@export var mob_spawn_center: Marker2D
@export var ground: TileMapLayer
@export var water_collision: CollisionShape2D

var _remaining_mobs := 0
var _encounter_spawned := false
var _bubble_spawn_timer := 20.0

# Active tilemap data
func load_tilemap_data(tile_data: PackedByteArray) -> void:
	if ground:
		ground.tile_map_data = tile_data

func unload_tilemap_data() -> void:
	if ground:
		ground.tile_map_data = PackedByteArray()

func set_mobs_active(active: bool) -> void:
	for mob in get_tree().get_nodes_in_group("corrupted_mobs"):
		if mob.get_parent() == self:
			mob.set("encounter_active", active)

func _ready() -> void:
	_bubble_spawn_timer = bubble_spawn_interval

func _process(delta: float) -> void:
	if not _encounter_spawned or not _is_current_level():
		return
	_bubble_spawn_timer -= delta
	if _bubble_spawn_timer > 0.0:
		return
	_bubble_spawn_timer = bubble_spawn_interval
	if _ambient_bubble_count() < bubbles_per_level:
		_spawn_ambient_bubble()

# Level setup
func ensure_encounter_spawned() -> void:
	if _encounter_spawned:
		return
	_encounter_spawned = true
	_spawn_preloaded_mobs()

func _spawn_preloaded_mobs() -> void:
	_remaining_mobs = mob_count
	if randomize_field_mobs:
		for i in range(_remaining_mobs):
			_spawn_level_mob(_random_previous_mob_type())
	else:
		for i in range(mob_count):
			_spawn_level_mob(mob_type)
	var pad := HealingPadScene.instantiate()
	add_child(pad)
	pad.global_position = _random_spawn_position()

func _random_previous_mob_type() -> MutantMob.MobType:
	return previous_mob_types[randi_range(0, previous_mob_types.size() - 1)]

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
	for attempt in range(max_spawn_attempts):
		candidate = mob_spawn_center.global_position + Vector2(
			randf_range(-half_size.x, half_size.x), randf_range(-half_size.y, half_size.y)
		)
		if not _is_inside_wall(candidate):
			return candidate
	for radius in range(32, 1025, 32):
		for angle_index in range(16):
			candidate = mob_spawn_center.global_position + Vector2.from_angle(TAU * angle_index / 16.0) * radius
			if not _is_inside_wall(candidate):
				return candidate
	return player_spawn.global_position

# Bubble spawn area
func _random_bubble_spawn_position() -> Vector2:
	if water_collision and water_collision.shape is RectangleShape2D:
		var size := (water_collision.shape as RectangleShape2D).size
		for attempt in range(max_spawn_attempts):
			var candidate := water_collision.to_global(Vector2(
				randf_range(-size.x * 0.5, size.x * 0.5),
				randf_range(-size.y * 0.5, size.y * 0.5)
			))
			if not _is_inside_wall(candidate):
				return candidate
	return _random_spawn_position()

func _spawn_ambient_bubble() -> void:
	var bubble := AirBubbleScene.instantiate()
	add_child(bubble)
	bubble.global_position = _random_bubble_spawn_position()

func _ambient_bubble_count() -> int:
	var count := 0
	for child in get_children():
		if child.is_in_group("air_bubbles"):
			count += 1
	return count

func _is_current_level() -> bool:
	var world := get_tree().get_first_node_in_group("world")
	return world != null and world.current_level_index >= 0 \
		and world.current_level_index < world.level_nodes.size() \
		and world.level_nodes[world.current_level_index] == self

# Solid ground check
func _is_inside_wall(global_pos: Vector2) -> bool:
	if not ground:
		return false
	for offset in [
		Vector2.ZERO,
		Vector2(mob_spawn_clearance, 0.0), Vector2(-mob_spawn_clearance, 0.0),
		Vector2(0.0, mob_spawn_clearance), Vector2(0.0, -mob_spawn_clearance),
	]:
		var cell := ground.local_to_map(ground.to_local(global_pos + offset))
		var tile_data := ground.get_cell_tile_data(cell)
		if tile_data and tile_data.get_collision_polygons_count(0) > 0:
			return true
	return false

func _on_mob_cured(_mob: MutantMob) -> void:
	_remaining_mobs = max(0, _remaining_mobs - 1)
	if _remaining_mobs == 0:
		mobs_cleared.emit()

# Field mobs cleared
func mobs_already_cleared() -> bool:
	return _remaining_mobs <= 0

func get_remaining_mobs() -> int:
	return _remaining_mobs

func reset_encounter() -> void:
	for child in get_children():
		if child is MutantMob or child.is_in_group("healing_pads"):
			child.free()
	_remaining_mobs = mob_count
	_encounter_spawned = true
	_spawn_preloaded_mobs()
	set_mobs_active(false)
