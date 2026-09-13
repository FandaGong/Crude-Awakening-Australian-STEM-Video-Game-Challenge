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
const HealingPadScene := preload("res://effects/healing_pad.tscn")

@export_range(1, 30, 1) var mob_count := 8
## Maximum number of ambient air bubbles this level may have at once.
@export_range(1, 30, 1) var bubbles_per_level := 12
@export_range(1.0, 120.0, 1.0, "suffix:s") var bubble_spawn_interval := 20.0
@export var mob_spawn_size := Vector2(1100, 460)
@export var mob_type: MutantMob.MobType = MutantMob.MobType.SHELL
## Levels 5 and 6 contain Whale/Kraken bosses, not matching field mobs. Their
## regular encounters use a shuffled mix of the four earlier creature types.
@export var randomize_field_mobs := false

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_spawn: Marker2D = $BossSpawn
@onready var mob_spawn_center: Marker2D = $MobSpawnCenter
@onready var ground: TileMapLayer = get_node_or_null("Ground")
@onready var water_collision: CollisionShape2D = get_node_or_null("waterArea/CollisionShape2D")

## Random spawn positions get re-rolled up to this many times if they land
## on a solid (wall/terrain) tile before giving up and using the last roll.
const MAX_SPAWN_ATTEMPTS := 80
const MOB_SPAWN_CLEARANCE := 28.0

var _remaining_mobs := 0
var _encounter_spawned := false
var _bubble_spawn_timer := 20.0

## Ground cell data is kept outside node_2d.tscn and supplied by World only
## while this historical level is active.
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
	# World loads this level's collision tile data only when the level becomes
	# active. Spawning here would validate positions against an empty TileMap.
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

## Called by World immediately after the active level's tile data is loaded.
func ensure_encounter_spawned() -> void:
	if _encounter_spawned:
		return
	_encounter_spawned = true
	_spawn_preloaded_mobs()

func _spawn_preloaded_mobs() -> void:
	_remaining_mobs = mob_count
	if randomize_field_mobs:
		# Whale and Kraken are boss-only. Replace both the level's normal
		# creature batch with earlier named creatures.
		for i in range(_remaining_mobs):
			_spawn_level_mob(_random_previous_mob_type())
	else:
		for i in range(mob_count):
			_spawn_level_mob(mob_type)
	for i in range(2):
		var pad := HealingPadScene.instantiate()
		add_child(pad)
		pad.global_position = _random_spawn_position()

func _random_previous_mob_type() -> MutantMob.MobType:
	return [
		MutantMob.MobType.SHELL,
		MutantMob.MobType.JELLYFISH,
		MutantMob.MobType.CRAB,
		MutantMob.MobType.ANGLERFISH,
	][randi_range(0, 3)]

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
	# Never return a known invalid point. Search progressively wider rings from
	# the encounter center, then use the player entry marker as a safe fallback.
	for radius in range(32, 1025, 32):
		for angle_index in range(16):
			candidate = mob_spawn_center.global_position + Vector2.from_angle(TAU * angle_index / 16.0) * radius
			if not _is_inside_wall(candidate):
				return candidate
	return player_spawn.global_position

## Bubbles use the level's water collision rectangle rather than the smaller
## mob encounter area, so they can appear anywhere across the playable map.
func _random_bubble_spawn_position() -> Vector2:
	if water_collision and water_collision.shape is RectangleShape2D:
		var size := (water_collision.shape as RectangleShape2D).size
		for attempt in range(MAX_SPAWN_ATTEMPTS):
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

## True if the given global position lands on a Ground tile that has
## collision (i.e. a wall/solid terrain tile, as opposed to open water,
## which has no tile there at all).
func _is_inside_wall(global_pos: Vector2) -> bool:
	if not ground:
		return false
	# Validate the full mob footprint, not just its center tile, so wide art
	# and colliders cannot overlap a nearby wall on spawn.
	for offset in [
		Vector2.ZERO,
		Vector2(MOB_SPAWN_CLEARANCE, 0.0), Vector2(-MOB_SPAWN_CLEARANCE, 0.0),
		Vector2(0.0, MOB_SPAWN_CLEARANCE), Vector2(0.0, -MOB_SPAWN_CLEARANCE),
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

## True once every preloaded field mob has already been cured. Used when
## re-entering a level (e.g. after dying to its boss) to tell whether the
## one-shot mobs_cleared signal has already fired and won't fire again.
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
