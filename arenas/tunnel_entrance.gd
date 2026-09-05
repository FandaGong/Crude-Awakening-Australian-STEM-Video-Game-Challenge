extends Area2D

## Placed in the Trench. Swimming into it sends the player into the dive
## tunnel, which is where all 6 bossfights and the merchants live.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not GameData.is_robot_unlocked:
		return # the otter has no way to cure anything down there yet
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("enter_dive_tunnel"):
		world.enter_dive_tunnel()
