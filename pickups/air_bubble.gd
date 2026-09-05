extends Area2D

## Stationary environment pickup (design doc: "bubbles have no body dmg.
## when touched they pop and provide a full bar of air"). Spawned freely in
## every level. The companion robot's Baleen Resonance Core module pulls
## nearby members of the "air_bubbles" group toward the player.

func _ready() -> void:
	add_to_group("air_bubbles")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("recoverAir"):
			body.currentAir = body.maxAir
		if body.has_method("pop_air_bubble"):
			body.pop_air_bubble() # triggers Bubble Booster Charm, if equipped
		queue_free()
