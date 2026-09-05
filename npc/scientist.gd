extends Area2D

## Placed in the 2126 wasteland. The otter meets the scientist here after
## following the progression arrows; he explains what happened to the earth
## and assigns his companion robot to accompany the otter 100 years into the
## past. Interacting once grants the robot and unlocks the skill tree/UI -
## everything downstream (the time machine, the dive tunnel gates) checks
## GameData.is_robot_unlocked before it will do anything.

signal dialogue_finished

@onready var prompt: Label = $Prompt
@onready var dialogue_box: DialogueBox = get_tree().get_first_node_in_group("dialogue_box") as DialogueBox

const DIALOGUE := [
	"You're standing in 2126. Ninety-nine percent of life is gone. Smoke has swallowed the sky, and the poisoned ponds are all that remain.",
	"A century of corporate extraction, unchecked machines, and delayed action led here. I built this robot to trace the moments when the timeline broke.",
	"It will guide you through six critical turning points, from the e-waste flood to the Industrial AI takeover.",
	"Take the robot. Use the time machine to return to a greener world and prevent this future from ever happening.",
]

var player_in_range: bool = false
var _line_index: int = 0
var _talking: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false
	if dialogue_box and not dialogue_box.finished.is_connected(_on_dialogue_finished):
		dialogue_box.finished.connect(_on_dialogue_finished)

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range or not event.is_action_pressed("interact"):
		return
	if GameData.is_robot_unlocked:
		if GameData.time_revival_pending and not _talking:
			_talking = true
			GameData.time_revival_pending = false
			dialogue_box.show_lines(PackedStringArray(["You came earlier than you would have without dying, as expected. Time travel is a remarkable safety net. Come on, give it another try."]))
			get_viewport().set_input_as_handled()
		return
	if not _talking:
		_talking = true
		if prompt:
			prompt.visible = false
		if dialogue_box:
			dialogue_box.show_lines(PackedStringArray(DIALOGUE))
			get_viewport().set_input_as_handled()

func _on_dialogue_finished() -> void:
	if not _talking:
		return
	_talking = false
	if not GameData.is_robot_unlocked:
		StoryManager.robot_was_given()
	dialogue_finished.emit()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if prompt and (not GameData.is_robot_unlocked or GameData.time_revival_pending):
			prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if prompt:
			prompt.visible = false
