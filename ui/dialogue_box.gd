extends CanvasLayer
class_name DialogueBox

signal finished

@export_range(10.0, 120.0, 1.0) var characters_per_second := 48.0

# --- Visual Node References ---
# Godot fetches these from your Scene Tree automatically when the game boots!
@onready var _panel: Panel = $Panel
@onready var _text: Label = $Panel/TextLabel
@onready var _hint: Label = $Panel/HintLabel

var _lines: PackedStringArray = []
var _line_index := 0
var _visible_characters := 0.0
var _typing := false

func _ready() -> void:
	# All your sizing, styling, fonts, and offsets are handled by the editor!
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_lines(lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_line_index = 0
	visible = true
	_show_current_line()

func is_open() -> bool:
	return visible

func _process(delta: float) -> void:
	if not _typing:
		return
	_visible_characters = minf(_visible_characters + characters_per_second * delta, _text.text.length())
	_text.visible_characters = int(_visible_characters)
	if _text.visible_characters >= _text.text.length():
		_typing = false
		_hint.text = "C continue    X skip"
		_hint.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("skip_dialogue"):
		get_viewport().set_input_as_handled()
		_skip_all_lines()
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_visible_characters = _text.text.length()
		_text.visible_characters = -1
		_typing = false
		_hint.text = "C continue    X skip"
		_hint.visible = true
		return
	_line_index += 1
	if _line_index >= _lines.size():
		visible = false
		finished.emit()
		return
	_show_current_line()

func _skip_all_lines() -> void:
	_typing = false
	_line_index = _lines.size()
	_lines = PackedStringArray()
	_hint.visible = false
	visible = false
	finished.emit()

func _show_current_line() -> void:
	_text.text = _lines[_line_index]
	_visible_characters = 0.0
	_text.visible_characters = 0
	_typing = true
	_hint.text = "C reveal    X skip"
	_hint.visible = true
