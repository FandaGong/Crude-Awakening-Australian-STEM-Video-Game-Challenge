extends Area2D

## The scientist's time machine. Locked until the robot has been given to
## the otter. Every jump - the first trip out of the lab, and every trip
## back after a level's boss has been cured and the otter has been returned
## here - goes through this same _activate(). It advances StoryManager to
## the next era and sends the otter to that era's hand-drawn level
## (world.gd/enter_level). Once the sixth boss (the Kraken/AI) is cured and
## the otter steps in here one more time, there is no next era left, so it
## sends the otter out into the restored, sunlit ending instead.

signal activated

const TimeTravelOverlay := preload("res://ui/time_travel_overlay.tscn")

@onready var prompt: Label = $Prompt
var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false
	StoryManager.robot_given.connect(func(): _refresh_prompt())

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and GameData.is_robot_unlocked and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_activate()

func _activate() -> void:
	if prompt:
		prompt.visible = false
	var overlay := TimeTravelOverlay.instantiate()
	get_tree().current_scene.add_child(overlay)
	StoryManager.advance_to_next_era()
	var world := get_tree().get_first_node_in_group("world")

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

func _refresh_prompt() -> void:
	if player_in_range and prompt:
		prompt.visible = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if prompt and GameData.is_robot_unlocked:
			prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if prompt:
			prompt.visible = false
