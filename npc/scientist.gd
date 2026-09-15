extends Area2D

# Scientist encounter

signal dialogue_finished

@export_category("Dialogue")
@export_multiline var dialogue_lines: Array[String] = [
	"You're standing in 2126. Ninety-nine percent of life is gone. Smoke has swallowed the sky, and the poisoned ponds are all that remain.",
	"A century of corporate extraction, unchecked machines, and delayed action led here. I built this robot to trace the moments when the timeline broke.",
	"It will guide you through six critical turning points, from the e-waste flood to the Industrial AI takeover.",
	"The creatures and bosses you meet are corrupted, not ordinary enemies. The robot heals them from 0% to 100% instead of damaging them.",
	"When a mob or boss reaches 100% health, it is fully restored and the timeline is repaired. That recovery awards Compendium Data immediately.",
	"Watch the boss bar: it begins empty and fills as the robot cures the boss. Keep the beam on it until the bar is completely full.",
	"Take the robot. Use the time machine to return to a greener world and prevent this future from ever happening.",
]

@export_multiline var robot_follow_line: String = "Robot: Follow me. The time machine is this way."

@export_category("References")
@export var prompt_path: NodePath = ^"Prompt"
@export var body_sprite_path: NodePath = ^"Body"
@export var robot_sprite_path: NodePath = ^"Robot"

@export var player_group: StringName = &"player"
@export var dialogue_box_group: StringName = &"dialogue_box"
@export var world_group: StringName = &"world"

@export_category("Interaction")
@export var interact_action: StringName = &"interact"
@export var idle_animation: StringName = &"default"

@onready var prompt: Label = get_node_or_null(prompt_path) as Label
@onready var body_sprite: AnimatedSprite2D = get_node_or_null(body_sprite_path) as AnimatedSprite2D
@onready var robot_sprite: AnimatedSprite2D = get_node_or_null(robot_sprite_path) as AnimatedSprite2D
@onready var dialogue_box: DialogueBox = get_tree().get_first_node_in_group(dialogue_box_group) as DialogueBox

var player_in_range: bool = false
var _talking: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if body_sprite:
		body_sprite.play(idle_animation)
	if robot_sprite:
		robot_sprite.play(idle_animation)
	GameData.robot_unlocked_changed.connect(_on_robot_unlocked_changed)
	_on_robot_unlocked_changed(GameData.is_robot_unlocked)
	if prompt:
		prompt.visible = false
	if dialogue_box and not dialogue_box.finished.is_connected(_on_dialogue_finished):
		dialogue_box.finished.connect(_on_dialogue_finished)

func _on_robot_unlocked_changed(unlocked: bool) -> void:
	if not robot_sprite:
		return
	robot_sprite.visible = not unlocked
	if not unlocked:
		robot_sprite.play(idle_animation)

func _unhandled_input(event: InputEvent) -> void:
	if not _can_start_dialogue(event):
		return
	_talking = true
	if prompt:
		prompt.visible = false
	dialogue_box.show_lines(PackedStringArray(dialogue_lines))
	get_viewport().set_input_as_handled()

func _can_start_dialogue(event: InputEvent) -> bool:
	if not player_in_range or GameData.is_robot_unlocked or _talking:
		return false
	if dialogue_box == null or dialogue_box.is_open():
		return false
	return event.is_action_pressed(interact_action)

func _on_dialogue_finished() -> void:
	if not _talking:
		return
	_talking = false
	if not GameData.is_robot_unlocked:
		_give_robot_to_player()
	dialogue_finished.emit()

func _give_robot_to_player() -> void:
	StoryManager.robot_was_given()
	var world := get_tree().get_first_node_in_group(world_group)
	if not (world and world.has_method("guide_player_to_time_machine")):
		return
	if dialogue_box:
		dialogue_box.show_lines(PackedStringArray([robot_follow_line]))
		dialogue_box.finished.connect(world.guide_player_to_time_machine, CONNECT_ONE_SHOT)
	else:
		world.guide_player_to_time_machine()

func _on_body_entered(body: Node2D) -> void:
	_set_player_in_range(body, true)

func _on_body_exited(body: Node2D) -> void:
	_set_player_in_range(body, false)

func _set_player_in_range(body: Node2D, in_range: bool) -> void:
	if not body.is_in_group(player_group):
		return
	player_in_range = in_range
	if prompt:
		prompt.visible = in_range and not GameData.is_robot_unlocked
