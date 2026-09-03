extends Area2D

# Make sure this name matches the exact name of the Label in your Scene dock!
@onready var speech_bubble: Label = $speechBubble 
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var player: CharacterBody2D

func _ready() -> void:
	# Safely hide the bubble on start if it exists
	if speech_bubble:
		speech_bubble.hide()
	
	# Play the default animation for the NPC sprite
	if animated_sprite:
		animated_sprite.play("default")
	
	# Connect signals for when player enters/exits
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
		
func _on_body_entered(body: Node2D) -> void:
	if body == player:
		speech_bubble.text = "The toxic oil is suffocating us...\nPlease find the Dev up ahead!"
		speech_bubble.show()

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		speech_bubble.hide()
