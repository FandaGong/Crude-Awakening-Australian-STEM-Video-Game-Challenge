extends Node

# Shared visual effects

signal level_will_change

const FloatingNumberScene := preload("res://effects/floating_number.tscn")
const ItemDropScene := preload("res://pickups/item_drop.tscn")
const AirBubbleScene := preload("res://pickups/air_bubble.tscn")
const BubbleTrailScene := preload("res://effects/bubble_trail.tscn")
const COMBAT_NUMBER_INTERVAL := 0.35

var effects_enabled := true
var _pending_combat_numbers: Dictionary = {}

func _process(delta: float) -> void:
	for key in _pending_combat_numbers.keys():
		var number: Dictionary = _pending_combat_numbers[key]
		number.time_left -= delta
		if number.time_left > 0.0:
			_pending_combat_numbers[key] = number
			continue
		_show_combat_number(number.position, number.amount, number.is_heal)
		_pending_combat_numbers.erase(key)

func show_number(world_pos: Vector2, amount: float, is_heal: bool, source: Node2D = null) -> void:
	if amount <= 0.0:
		return
	if not source:
		_show_combat_number(world_pos, amount, is_heal)
		return

	var key := "%s:%s" % [source.get_instance_id(), "heal" if is_heal else "damage"]
	var number: Dictionary = _pending_combat_numbers.get(key, {
		"amount": 0.0,
		"position": world_pos,
		"is_heal": is_heal,
		"time_left": COMBAT_NUMBER_INTERVAL,
	})
	number.amount += amount
	number.position = world_pos
	_pending_combat_numbers[key] = number

func _show_combat_number(world_pos: Vector2, amount: float, is_heal: bool) -> void:
	if amount <= 0.0:
		return
	var scene := get_tree().current_scene
	if not scene:
		return
	var n := FloatingNumberScene.instantiate()
	scene.add_child(n)
	n.global_position = world_pos
	n.setup(amount, is_heal)

func spawn_item_drop(origin: Vector2, item: ItemData, count: int = 1) -> void:
	if not item:
		return
	var scene := get_tree().current_scene
	if not scene:
		return
	for i in range(max(1, count)):
		var drop := ItemDropScene.instantiate()
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

func notify_level_changing() -> void:
	level_will_change.emit()

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
