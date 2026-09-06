extends Node2D

## Small reusable "black hole" visual used at both ends of a time jump:
## - On departure (npc/time_machine.gd): grows into view, swirls + shrinks
##   the otter and the time machine's own sprite into itself, then shrinks
##   away.
## - On arrival back at the lab (world.gd/return_to_lab): grows into view,
##   the otter appears and hops out of it, then it shrinks and disappears.
##
## The visual itself lives on the AnimatedSprite2D child below - drop your
## black-hole spin/swirl frames into its SpriteFrames resource (an animation
## named "default"). If no frames are assigned yet this still works, it's
## just invisible, so the timing/logic can be wired up before the art lands.

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

## Grows the hole from nothing up to full size at its current position.
func grow() -> void:
	scale = Vector2.ZERO
	modulate.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, GROW_DURATION)
	await tween.finished

## Shrinks the hole away to nothing and frees it. Call last.
func shrink_and_free() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, SHRINK_DURATION)
	await tween.finished
	if is_instance_valid(self):
		queue_free()

## Swirls the given CanvasItem/Node2D targets (e.g. the otter, the time
## machine's sprite) into this hole's position - spinning and shrinking them
## down to nothing as they're pulled in. Does not touch this hole's own
## scale, and does not restore the targets afterward; the caller is
## responsible for putting each target's scale/rotation back once it's
## repositioned elsewhere.
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
