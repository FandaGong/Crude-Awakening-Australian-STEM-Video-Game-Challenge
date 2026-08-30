extends Node2D

const ArenaScene := preload("res://arenas/boss_arena.tscn")
const ARENA_OFFSET := Vector2(6000, 0)

@onready var pond_scene: Node2D = $pondScene
@onready var trench_scene: Node2D = $trenchScene
@onready var ending_scene: Node2D = $endingScene
@onready var dive_tunnel: Node2D = $diveTunnel

@onready var pond_spawn: Marker2D = $pondScene/pondSpawn
@onready var trench_spawn: Marker2D = $trenchScene/trenchSpawn
@onready var ending_spawn: Marker2D = $endingScene/endingSpawn

@onready var player: CharacterBody2D = $player

var current_spawn_position: Vector2 = Vector2.ZERO
var current_boss_arena: Node = null
var current_boss_data: BossData = null

func _ready() -> void:
	add_to_group("world")
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
	teleport_player_to_pond()

# --- Overworld areas --------------------------------------------------------

func teleport_player_to_pond() -> void:
	_clear_active_boss_arena()
	current_spawn_position = pond_spawn.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.LAND

func transitionToTrench() -> void:
	_clear_active_boss_arena()
	current_spawn_position = trench_spawn.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.SWIMMING

func transitionToEnding() -> void:
	_clear_active_boss_arena()
	current_spawn_position = ending_spawn.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.LAND

func enter_dive_tunnel() -> void:
	_clear_active_boss_arena()
	current_spawn_position = dive_tunnel.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.SWIMMING

# --- Boss arenas -------------------------------------------------------------

func enter_boss_arena(boss_id: int) -> void:
	var path := "res://resources/bosses/boss_%02d.tres" % boss_id
	if not ResourceLoader.exists(path):
		return

	current_boss_data = load(path)
	_clear_active_boss_arena()

	current_boss_arena = ArenaScene.instantiate()
	add_child(current_boss_arena)
	current_boss_arena.global_position = ARENA_OFFSET
	current_boss_arena.setup(current_boss_data)
	current_boss_arena.boss_defeated.connect(_on_arena_boss_defeated)

	player.global_position = current_boss_arena.global_position + current_boss_arena.player_spawn.position
	player.currentState = player.State.SWIMMING
	current_spawn_position = player.global_position

func _on_arena_boss_defeated(boss_id: int, _crystal_reward: int) -> void:
	await get_tree().create_timer(1.5).timeout
	_return_to_tunnel_from_boss(boss_id)

func _return_to_tunnel_from_boss(boss_id: int) -> void:
	_clear_active_boss_arena()
	var gate_pos: Vector2 = dive_tunnel.boss_gate_positions.get(boss_id, Vector2.ZERO)
	player.global_position = dive_tunnel.global_position + gate_pos + Vector2(0, 90)
	player.currentState = player.State.SWIMMING
	current_spawn_position = player.global_position

func _clear_active_boss_arena() -> void:
	if current_boss_arena and is_instance_valid(current_boss_arena):
		current_boss_arena.queue_free()
	current_boss_arena = null

# --- Shop --------------------------------------------------------------------

func open_shop() -> void:
	get_tree().call_group("ui_controller", "open_shop")

# --- Death / respawn -----------------------------------------------------------

func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	# Dying mid-bossfight resets that boss's health rather than ejecting you
	# all the way back to the tunnel entrance.
	if current_boss_arena and is_instance_valid(current_boss_arena) and current_boss_data:
		current_boss_arena.setup(current_boss_data)
	player.respawn(current_spawn_position)
