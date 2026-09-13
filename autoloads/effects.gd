extends Node

## Small, stateless helper for shared visual feedback that several scripts
## need (player, mobs, bosses): floating damage/heal numbers, spawning item
## drops, and pulsing the HUD Compendium Data counter.
## Autoloaded as `Effects` (see project.godot). Nothing here holds gameplay
## state beyond the `level_will_change` broadcast below.

## Emitted by world.gd right before it moves the otter to a different level,
## boss arena, or overworld area. Any still-uncollected ItemDrop listens for
## this and immediately teleports itself into the robot's inventory rather
## than being left behind and lost.
signal level_will_change

const FloatingNumberScene := preload("res://effects/floating_number.tscn")
const ItemDropScene := preload("res://pickups/item_drop.tscn")
const AirBubbleScene := preload("res://pickups/air_bubble.tscn")
const BubbleTrailScene := preload("res://effects/bubble_trail.tscn")

var effects_enabled := true

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

## Spawns a physical, collectible drop for a real ItemData (gear, robot
## module, charm, ability, etc.) at `origin` - typically a just-cured mob or
## boss. Each drop scatters outward like a trash drop, settles according to
## its surroundings (sinks if in water, drops onto the ground if not), and
## then waits to be walked over. Uncollected drops teleport themselves into
## the robot's inventory after a minute or if the level changes first -
## see pickups/item_drop.gd.
func spawn_item_drop(origin: Vector2, item: ItemData, count: int = 1) -> void:
	if not item:
		return
	var scene := get_tree().current_scene
	if not scene:
		return
	for i in range(max(1, count)):
		var drop := ItemDropScene.instantiate()
		# ItemDrop begins scattering in _ready(), so configure it before it
		# enters the tree. Otherwise it scatters from the scene origin.
		drop.setup(item)
		drop.global_position = origin
		scene.add_child(drop)

func spawn_air_bubble(origin: Vector2, air_amount: float = 100.0) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var bubble := AirBubbleScene.instantiate()
	scene.add_child(bubble)
	bubble.global_position = origin
	bubble.air_amount = air_amount

func spawn_bubble_trail(origin: Vector2) -> void:
	if not effects_enabled:
		return
	var scene := get_tree().current_scene
	if not scene:
		return
	var trail := BubbleTrailScene.instantiate()
	scene.add_child(trail)
	trail.global_position = origin
	trail.setup()

func set_effects_enabled(enabled: bool) -> void:
	effects_enabled = enabled

## Called by world.gd immediately before any transition that moves the otter
## away from the area a drop might be sitting in.
func notify_level_changing() -> void:
	level_will_change.emit()

## Bounces + flashes the HUD Compendium Data icon when a reward is credited.
func pulse_compendium_counter() -> void:
	var icon: CanvasItem = get_tree().root.get_node_or_null("Main/UI/HUD/compendiumDataDisplay/compendiumIcon")
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
