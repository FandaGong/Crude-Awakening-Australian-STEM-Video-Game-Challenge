extends Area2D

@onready var speech_bubble: Label = $speechBubble
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dialogue_box: DialogueBox = get_tree().get_first_node_in_group("dialogue_box") as DialogueBox

@export var player: CharacterBody2D
@export_multiline var dialogue := "What's up, I'm Fanda, a developer of the game!"

var player_in_range := false

func _ready() -> void:
	if speech_bubble:
		speech_bubble.hide()
	if animated_sprite:
		animated_sprite.play("default")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range or not event.is_action_pressed("interact") or not dialogue_box or dialogue_box.is_open():
		return
	speech_bubble.hide()
	dialogue_box.show_lines(PackedStringArray([dialogue]))
	get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		player_in_range = true
		speech_bubble.text = "Press C to talk"
		speech_bubble.show()

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_range = false
		speech_bubble.hide()
