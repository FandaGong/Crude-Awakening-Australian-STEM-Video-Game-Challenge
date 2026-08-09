extends Node2D

# References to our sub-scenes
@onready var pond_scene: Node2D = $pondScene
@onready var trench_scene: Node2D = $trenchScene
@onready var ending_scene: Node2D = $endingScene

# References to our spawn markers
@onready var pond_spawn: Marker2D = $pondScene/pondSpawn
@onready var trench_spawn: Marker2D = $trenchScene/trenchSpawn
@onready var ending_spawn: Marker2D = $endingScene/endingSpawn

# Reference to the player
@onready var player: CharacterBody2D = $player

func _ready() -> void:
	# Start by placing the player at the very beginning of the game
	teleport_player_to_pond()

func teleport_player_to_pond() -> void:
	player.global_position = pond_spawn.global_position
	player.current_state = player.State.LAND

func transition_to_trench() -> void:
	# Teleport the player to the top of the trench
	player.global_position = trench_spawn.global_position
	# Switch their state to swimming so they can navigate the descent
	player.current_state = player.State.SWIMMING

func transition_to_ending() -> void:
	# Teleport the player to the peaceful village
	player.global_position = ending_spawn.global_position
	# Switch their state back to land movement so they can walk to the chair
	player.current_state = player.State.LAND


func _on_pond_to_trench_trigger_body_entered(body: Node2D) -> void:
	# Make sure only the player activates the transition
	if body == player:
		transition_to_trench()
