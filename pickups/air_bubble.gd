extends Area2D

## Stationary environment pickup (design doc: "bubbles have no body dmg.
## when touched they pop and provide a full bar of air"). Spawned freely in
## every level. The companion robot's Baleen Resonance Core module pulls
## nearby members of the "air_bubbles" group toward the player.

## "Environment Drop: Bubbles" - popping a bubble has a small chance to pop
## loose a physical Bubble Booster Charm alongside the air refill.
const BUBBLE_BOOSTER_CHARM_PATH := "res://resources/items/bubble_booster_charm.tres"
const BUBBLE_BOOSTER_DROP_CHANCE := 0.1
@export var air_amount: float = 100.0

func _ready() -> void:
	add_to_group("air_bubbles")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("recoverAir"):
			body.currentAir = min(body.maxAir, body.currentAir + air_amount)
		if body.has_method("pop_air_bubble"):
			body.pop_air_bubble() # triggers Bubble Booster Charm, if equipped
		_maybe_drop_booster_charm()
		queue_free()

func _maybe_drop_booster_charm() -> void:
	if not Effects or randf() > BUBBLE_BOOSTER_DROP_CHANCE:
		return
	if not ResourceLoader.exists(BUBBLE_BOOSTER_CHARM_PATH):
		return
	Effects.spawn_item_drop(global_position, load(BUBBLE_BOOSTER_CHARM_PATH))
