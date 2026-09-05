extends Node

## Small, stateless helper for shared visual feedback that several scripts
## need (player, mobs, bosses): floating damage/heal numbers, spawning a
## mob's trash drop(s), and pulsing the HUD trash counter. Autoloaded as
## `Effects` (see project.godot). Nothing here holds gameplay state.

const FloatingNumberScene := preload("res://effects/floating_number.tscn")
const TrashDropScene := preload("res://pickups/trash_drop.tscn")

## Spawns a floating "+N" (green, healing/curing) or "-N" (red, damage)
## number at a world position.
func show_number(world_pos: Vector2, amount: float, is_heal: bool) -> void:
	if amount <= 0.0:
		return
	var scene := get_tree().current_scene
	if not scene:
		return
	var n := FloatingNumberScene.instantiate()
	scene.add_child(n)
	n.global_position = world_pos
	n.setup(amount, is_heal)

## Spawns `count` trash pickups of `trash_size` at `origin` (typically a
## just-cured mob). Each drop scatters outward, settles, then flies into
## the HUD trash counter on its own and pulses it on arrival.
func spawn_trash_drop(origin: Vector2, trash_size: String, count: int = 1) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	for i in range(max(1, count)):
		var drop := TrashDropScene.instantiate()
		drop.trash_size = trash_size
		scene.add_child(drop)
		drop.global_position = origin

## Bounces + flashes the HUD trash counter icon. Called by each trash drop
## the instant it's absorbed into the counter.
func pulse_trash_counter() -> void:
	var icon: CanvasItem = get_tree().root.get_node_or_null("Main/UI/HUD/largeTrash/crystalIcon")
	if not icon:
		return

	var base_scale: Vector2 = icon.get_meta("_effects_base_scale", icon.scale)
	icon.set_meta("_effects_base_scale", base_scale)
	var bounce := create_tween()
	bounce.tween_property(icon, "scale", base_scale * 1.6, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(icon, "scale", base_scale, 0.22) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var base_modulate: Color = icon.get_meta("_effects_base_modulate", icon.modulate)
	icon.set_meta("_effects_base_modulate", base_modulate)
	icon.modulate = Color(1.6, 1.6, 1.2, base_modulate.a)
	var flash := create_tween()
	flash.tween_property(icon, "modulate", base_modulate, 0.3)
