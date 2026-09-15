extends Area2D

# Time machine

signal activated

const TimeTravelOverlay := preload("res://ui/time_travel_overlay.tscn")
const BlackHoleEffect := preload("res://effects/black_hole.tscn")

# Spawn animation
const SCALE_TWEEN_DURATION := 0.35

@onready var prompt: Label = $Prompt
@onready var visual: Node2D = $AnimatedSprite2D
var player_in_range: bool = false

# Return machine
@export var is_return_machine: bool = false
var _return_enabled: bool = false

# Activation state
var _busy: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false
	StoryManager.robot_given.connect(func(): _refresh_prompt())

func _can_interact() -> bool:
	if not GameData.is_robot_unlocked:
		return false
	return (not is_return_machine) or _return_enabled

# Enable return
func enable_return() -> void:
	if not is_return_machine or _return_enabled:
		return
	_return_enabled = true
	_refresh_prompt()

# Spawn effect
func play_spawn_effect() -> void:
	await _play_grow_effect()

func _unhandled_input(event: InputEvent) -> void:
	if not _can_activate(event):
		return
	get_viewport().set_input_as_handled()
	_activate()

func _can_activate(event: InputEvent) -> bool:
	if _busy or not player_in_range:
		return false
	if not _can_interact():
		return false
	return event.is_action_pressed("interact")

func _activate() -> void:
	if _busy or not _can_interact():
		return
	_busy = true
	if prompt:
		prompt.visible = false

	var world := get_tree().get_first_node_in_group("world")
	var player_node: Node2D = world.player if world else null

	# Departure effect
	await _play_black_hole_departure(player_node)

	if is_return_machine:
		activated.emit()
		if world and world.has_method("return_to_lab"):
			world.return_to_lab()
		# One-way return machine
		queue_free()
		return

	# Era progression
	var current_boss_id := StoryManager.boss_id_for_current_era()
	var era_in_progress: bool = (
		StoryManager.current_era_index >= 0
		and current_boss_id != -1
		and not GameData.is_boss_defeated(current_boss_id)
	)

	var overlay := TimeTravelOverlay.instantiate()
	get_tree().current_scene.add_child(overlay)

	if era_in_progress:
		# Resume current era
		var era: Dictionary = StoryManager.ERAS[StoryManager.current_era_index]
		overlay.play(era.year, era.title)
		await overlay.finished
		if world and world.has_method("enter_level"):
			world.enter_level(StoryManager.current_era_index)
	else:
		StoryManager.advance_to_next_era()
		if StoryManager.current_era_index >= StoryManager.ERAS.size():
			# Return home
			overlay.play(StoryManager.HOME_YEAR, "The timeline is finally clear.")
			await overlay.finished
			if world and world.has_method("transitionToEnding"):
				world.transitionToEnding()
		else:
			var era: Dictionary = StoryManager.ERAS[StoryManager.current_era_index]
			overlay.play(era.year, era.title)
			await overlay.finished
			if world and world.has_method("enter_level"):
				world.enter_level(StoryManager.current_era_index)

	activated.emit()
	# Reset lab machine
	await _play_grow_effect()
	_busy = false
	_refresh_prompt()

# Black hole departure
func _play_black_hole_departure(player_node: Node2D) -> void:
	var hole := BlackHoleEffect.instantiate()
	get_tree().current_scene.add_child(hole)
	hole.global_position = global_position

	var targets: Array = []
	var saved_transforms: Array = []
	if visual:
		targets.append(visual)
		saved_transforms.append([visual.scale, visual.rotation])
	if player_node:
		targets.append(player_node)
		saved_transforms.append([player_node.scale, player_node.rotation])
		player_node.visible = false

	await hole.grow()
	await hole.consume(targets)
	await hole.shrink_and_free()

	# Restore player
	for i in targets.size():
		var target = targets[i]
		if not is_instance_valid(target):
			continue
		if target == player_node:
			target.scale = saved_transforms[i][0]
			target.rotation = saved_transforms[i][1]

func _play_grow_effect() -> void:
	if not visual:
		return
	visual.scale = Vector2.ZERO
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", Vector2.ONE, SCALE_TWEEN_DURATION)
	await tween.finished

func _refresh_prompt() -> void:
	if _busy:
		return
	if player_in_range and prompt and _can_interact():
		prompt.visible = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if not _busy and prompt and _can_interact():
			prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if prompt:
			prompt.visible = false
