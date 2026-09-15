extends Area2D

# Air bubble pickup
# Baleen Core pickup target
# Bubble Booster Charm chance
const BUBBLE_BOOSTER_CHARM_PATH := "res://resources/items/bubble_booster_charm.tres"
const BUBBLE_BOOSTER_DROP_CHANCE := 0.1
@export var air_amount: float = 100.0

const BUBBLE_SHEET_PATH := "res://assets/sprites/mobs/bubble.png"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("air_bubbles")
	sprite.play()

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
