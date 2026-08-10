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
	# Changed from current_state to currentState
	player.currentState = player.State.LAND 

func transitionToTrench() -> void:
	player.global_position = trench_spawn.global_position
	# Changed from current_state to currentState
	player.currentState = player.State.SWIMMING

func transitionToEnding() -> void:
	player.global_position = ending_spawn.global_position
	# Changed from current_state to currentState
	player.currentState = player.State.LAND
