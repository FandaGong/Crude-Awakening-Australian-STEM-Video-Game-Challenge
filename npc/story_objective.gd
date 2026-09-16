extends Area2D
class_name StoryObjective

signal completed(objective: StoryObjective)

@export var prompt_text := "Interact"
@export var completion_lines: PackedStringArray = []
@export var disable_animation := &"off"
@export var inventory_item: ItemData

@onready var prompt: Label = $Prompt
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var _player_in_range := false
var _completed := false
var _available := false

func _ready() -> void:
	add_to_group("story_objectives")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.text = prompt_text
	set_available(false)

func set_available(available: bool) -> void:
	_available = available
	visible = available
	monitoring = available
	prompt.visible = false
	if available:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		_player_in_range = player != null and overlaps_body(player)
		prompt.visible = _player_in_range

func _unhandled_input(event: InputEvent) -> void:
	if not _available or _completed or not _player_in_range or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_completed = true
	prompt.visible = false
	if inventory_item and not GameData.add_item(inventory_item):
		push_warning("Robot inventory is full; %s could not be stored." % inventory_item.name)
	if sprite and not disable_animation.is_empty() and sprite.sprite_frames.has_animation(disable_animation):
		sprite.play(disable_animation)
	completed.emit(self)

func _on_body_entered(body: Node2D) -> void:
	if _available and body.is_in_group("player") and not _completed:
		_player_in_range = true
		prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		prompt.visible = false
