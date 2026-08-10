@tool
extends ColorRect

@export var collision_shape: CollisionShape2D

func _ready() -> void:
	# Trigger the update automatically when resized in the editor
	item_rect_changed.connect(_update_collision)
	_update_collision()

func _update_collision() -> void:
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		return
		
	# Update size and center position
	collision_shape.shape.size = size
	collision_shape.position = position + (size / 2)
