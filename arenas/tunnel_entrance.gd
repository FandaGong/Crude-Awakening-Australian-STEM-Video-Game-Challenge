extends Area2D

## Placed in the Trench. Swimming into it sends the player into the dive
## tunnel, which is where all 10 bossfights and the merchants live.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("enter_dive_tunnel"):
		world.enter_dive_tunnel()
