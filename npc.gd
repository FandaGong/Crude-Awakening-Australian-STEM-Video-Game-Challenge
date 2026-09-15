extends Area2D

# Ambient NPC
@export var speech_bubble: Label
@export var animated_sprite: AnimatedSprite2D
@onready var dialogue_box: DialogueBox = get_tree().get_first_node_in_group("dialogue_box") as DialogueBox

@export var player: CharacterBody2D
@export_multiline var dialogue := "The toxic oil is suffocating us...\nPlease find the scientist up ahead!"
@export var interact_prompt := "Press C to talk"

var player_in_range := false

func _ready() -> void:
	if speech_bubble:
		speech_bubble.hide()
	if animated_sprite:
		animated_sprite.play("default")

func _unhandled_input(event: InputEvent) -> void:
	if not _can_start_dialogue(event):
		return
	speech_bubble.hide()
	dialogue_box.show_lines(PackedStringArray([dialogue]))
	get_viewport().set_input_as_handled()

func _can_start_dialogue(event: InputEvent) -> bool:
	if not player_in_range:
		return false
	if not event.is_action_pressed("interact"):
		return false
	if not dialogue_box:
		return false
	return not dialogue_box.is_open()

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		player_in_range = true
		speech_bubble.text = interact_prompt
		speech_bubble.show()

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_range = false
		speech_bubble.hide()
