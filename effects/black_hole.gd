extends Node2D

# Time travel effect

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const GROW_DURATION := 0.4
const SHRINK_DURATION := 0.35
const SWIRL_DURATION := 0.5
const SWIRL_SPINS := 3.0

func _ready() -> void:
	scale = Vector2.ZERO
	modulate.a = 1.0
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("default"):
		sprite.play("default")

# Grow effect
func grow() -> void:
	scale = Vector2.ZERO
	modulate.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, GROW_DURATION)
	await tween.finished

# Shrink effect
func shrink_and_free() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, SHRINK_DURATION)
	await tween.finished
	if is_instance_valid(self):
		queue_free()

# Pull targets inward
func consume(targets: Array) -> void:
	var last_tween: Tween = null
	for target in targets:
		if not is_instance_valid(target):
			continue
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(target, "global_position", global_position, SWIRL_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(target, "scale", Vector2.ZERO, SWIRL_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(target, "rotation", target.rotation + TAU * SWIRL_SPINS, SWIRL_DURATION) \
			.set_trans(Tween.TRANS_LINEAR)
		last_tween = t
	if last_tween:
		await last_tween.finished
