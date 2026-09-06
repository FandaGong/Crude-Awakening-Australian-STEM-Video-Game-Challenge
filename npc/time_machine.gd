extends Area2D

## The scientist's time machine. Locked until the robot has been given to
## the otter. Every jump - the first trip out of the lab, and every trip
## back after a level's boss has been cured and the otter has been returned
## here - goes through this same _activate(). It advances StoryManager to
## the next era and sends the otter to that era's hand-drawn level
## (world.gd/enter_level). Once the sixth boss (the Kraken/AI) is cured and
## the otter steps in here one more time, there is no next era left, so it
## sends the otter out into the restored, sunlit ending instead.
##
## world.gd also drops one of these into each hand-drawn level, right on
## top of the otter's spawn point (see enter_level()/_spawn_level_time_machine()),
## with is_return_machine set to true. That copy stays inert - no prompt, no
## response to 'interact' - until its level's boss is cured, at which point
## world.gd calls enable_return() on it. Only then does using it send the
## otter home to labReturnSpawn, replacing what used to be an instant,
## automatic teleport.

signal activated

const TimeTravelOverlay := preload("res://ui/time_travel_overlay.tscn")
const BlackHoleEffect := preload("res://effects/black_hole.tscn")

# How long the grow/shrink pop takes. Kept short so it reads as a quick
# "zap" rather than a slow animation the player has to wait through.
const SCALE_TWEEN_DURATION := 0.35

@onready var prompt: Label = $Prompt
@onready var visual: Node2D = $AnimatedSprite2D
var player_in_range: bool = false

# Set by world.gd on the copies it drops into each hand-drawn level. A
# return machine only ever sends the otter back to the lab - it never
# advances StoryManager - and it stays inert until enable_return() is
# called once that level's boss is cured.
@export var is_return_machine: bool = false
var _return_enabled: bool = false

# True for the whole duration of an activation - from the moment 'C' is
# pressed until the level (or ending) has actually been entered. Blocks
# re-entrant _activate() calls, which is what let mashing 'C' during the
# fade cutscene fire advance_to_next_era() more than once and skip levels.
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

## Called by world.gd once the level this machine sits in has had its boss
## cured, turning the previously-inert return machine on.
func enable_return() -> void:
	if not is_return_machine or _return_enabled:
		return
	_return_enabled = true
	_refresh_prompt()

## Called by world.gd right after instancing this machine at the otter's
## spawn point for a level, so it visibly grows into place alongside them
## instead of just popping in at full size.
func play_spawn_effect() -> void:
	await _play_grow_effect()

func _unhandled_input(event: InputEvent) -> void:
	if _busy or not player_in_range or not _can_interact():
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_activate()

func _activate() -> void:
	if _busy or not _can_interact():
		return
	_busy = true
	if prompt:
		prompt.visible = false

	var world := get_tree().get_first_node_in_group("world")
	var player_node: Node2D = world.player if world else null

	# Whichever kind of trip this is, the otter and the machine itself get
	# swirled down into a small black hole as it fires up.
	await _play_black_hole_departure(player_node)

	if is_return_machine:
		activated.emit()
		if world and world.has_method("return_to_lab"):
			world.return_to_lab()
		# This copy only ever makes one trip - the level it lives in won't
		# be re-entered once its boss is cured - so it can go for good.
		queue_free()
		return

	# Only step forward to a brand-new Historical Turning Point once the one
	# the otter is currently on has actually been cured. Without this check,
	# stepping in here again after dying mid-level (or before ever finishing
	# it) would advance the era counter anyway and skip the unfinished level.
	var current_boss_id := StoryManager.boss_id_for_current_era()
	var era_in_progress: bool = (
		StoryManager.current_era_index >= 0
		and current_boss_id != -1
		and not GameData.is_boss_defeated(current_boss_id)
	)

	var overlay := TimeTravelOverlay.instantiate()
	get_tree().current_scene.add_child(overlay)

	if era_in_progress:
		# Ride the machine right back to the same unfinished era instead of
		# the next one.
		var era: Dictionary = StoryManager.ERAS[StoryManager.current_era_index]
		overlay.play(era.year, era.title)
		await overlay.finished
		if world and world.has_method("enter_level"):
			world.enter_level(StoryManager.current_era_index)
	else:
		StoryManager.advance_to_next_era()
		if StoryManager.current_era_index >= StoryManager.ERAS.size():
			# All six Historical Turning Points are cured - ride home for good.
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
	# The lab machine stays put and gets used again for the next era, so
	# pop it back to full size, ready to go.
	await _play_grow_effect()
	_busy = false
	_refresh_prompt()

## Grows a small black hole at this machine's position, swirls the otter
## and this machine's own sprite down into it, then shrinks the hole away.
## Runs at the start of every activation, whichever kind of trip it is.
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

	await hole.grow()
	await hole.consume(targets)
	await hole.shrink_and_free()

	# The otter needs to be visible/normal-sized again the instant it
	# reappears elsewhere; the machine's own sprite stays hidden (scale
	# zero) until _play_grow_effect() pops it back in, or - for a
	# return machine - it's freed for good a moment later anyway.
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
