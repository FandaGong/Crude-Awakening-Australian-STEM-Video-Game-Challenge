extends Area2D

@onready var speech_bubble: Label = $speechBubble
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player_inside: bool = false
var has_given_potion: bool = false

# Exported variables so we don't hardcode paths
@export var player: CharacterBody2D
@export var forest_spawn: Marker2D

func _ready() -> void:
	speech_bubble.hide()
	
	# Play the default animation for the NPC sprite
	if animated_sprite:
		animated_sprite.play("default")

func _on_body_entered(body: Node2D) -> void:
	if body == player and not has_given_potion:
		player_inside = true
		# Award robot immediately and tell player to press space
		player.hasRobotCompanion = true
		speech_bubble.text = "The Scientist gave you the robot companion!\n(Press SPACE to continue)"
		speech_bubble.show()
func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player_inside = false
		speech_bubble.hide()

func _process(_delta: float) -> void:
	# ui_accept is mapped to Spacebar / Enter by default in Godot
	if player_inside and Input.is_action_just_pressed("ui_accept"):
		give_potion_and_teleport()

func give_potion_and_teleport() -> void:
	has_given_potion = true
	player_inside = false
	speech_bubble.hide()
	
	# Enable shooting controls here once you make weapons!
	
	# Teleport the player directly to the forest beach spawn point
	if player and forest_spawn:
		player.global_position = forest_spawn.global_position
		print("Player teleported to the Beach Forest!")
