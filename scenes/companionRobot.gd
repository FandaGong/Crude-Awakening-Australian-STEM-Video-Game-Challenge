extends Node2D

@export var player: CharacterBody2D
@export var followSpeed: float = 6.0
@export var hoverSpeed: float = 3.5
@export var hoverAmplitude: float = 12.0

var timePassed: float = 0.0

func _physics_process(delta: float) -> void:
	# Keep hidden if the player hasn't unlocked the robot yet
	if not player or not player.hasRobotCompanion:
		hide()
		return
		
	show()
	timePassed += delta
	
	# Calculate target offset (top-right of player)
	var horizontalOffset = 35.0
	if player.sprite.flip_h:
		horizontalOffset = -35.0 # Flip to top-left if player faces left
		
	var targetPosition = player.global_position + Vector2(horizontalOffset, -35.0)
	
	# Smoothly glide to the target position
	global_position = global_position.lerp(targetPosition, followSpeed * delta)
	
	# Add a gentle floating wave effect
	global_position.y += sin(timePassed * hoverSpeed) * hoverAmplitude * delta
