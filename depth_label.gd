extends Label

@export var player: CharacterBody2D
@export var waterSurfaceY: float = 2100.0 # Adjust this to match the Y coordinate of your water line

func _process(_delta: float) -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.current_level_index >= 0:
		var level = world.level_nodes[world.current_level_index]
		var remaining_mobs: int = level.get_remaining_mobs() if level else 0
		var boss_id: int = world.current_level_index + 1
		var remaining_bosses := 0 if GameData.is_boss_defeated(boss_id) else 1
		text = "Mobs: %d  Bosses: %d" % [remaining_mobs, remaining_bosses]
		return
	text = "Mobs: 0  Bosses: 0"
