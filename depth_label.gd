extends Label

@export var player: CharacterBody2D
@export var waterSurfaceY: float = 400.0 # Adjust this to match the Y coordinate of your water line

func _process(_delta: float) -> void:
	if player:
		# Only calculate depth if the player is below the water surface level
		if player.global_position.y > waterSurfaceY:
			var calculatedDepth = (player.global_position.y - waterSurfaceY) / 10.0
			text = "Depth: " + str(int(calculatedDepth)) + " (m)"
		else:
			text = "Depth: 0 (m)"
