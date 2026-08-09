extends Area2D

# Make sure this name matches the exact name of the Label in your Scene dock!
@onready var speech_bubble: Label = $speechBubble 

func _ready() -> void:
	# Safely hide the bubble on start if it exists
	if speech_bubble:
		speech_bubble.hide()

# This is the exact function name Godot generated when you connected the signal
func _on_struggling_animal_body_entered(body: Node2D) -> void:
	# Using 'body' here checks if the player touched it, fixing the warning!
	if body.name == "Player":
		if speech_bubble:
			speech_bubble.show()

# This is the exact function name Godot generated when you connected the signal
func _on_struggling_animal_body_exited(body: Node2D) -> void:
	# Using 'body' here checks if the player left, fixing the warning!
	if body.name == "Player":
		if speech_bubble:
			speech_bubble.hide()
