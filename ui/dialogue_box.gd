extends CanvasLayer
class_name DialogueBox

## Full-width, screen-space dialogue used by every story conversation.
## C either finishes the current typed line or advances to the next one.

signal finished

@export_range(10.0, 120.0, 1.0) var characters_per_second := 48.0

var _lines: PackedStringArray = []
var _line_index := 0
var _visible_characters := 0.0
var _typing := false

var _panel: Panel
var _text: Label
var _hint: Label

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -196.0
	_panel.offset_bottom = -20.0
	_panel.offset_left = 24.0
	_panel.offset_right = -24.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102331f2")
	style.border_color = Color("81d8d0")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_text = Label.new()
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 25)
	_text.add_theme_color_override("font_color", Color("eaf8f5"))
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_text)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -128.0
	_hint.offset_top = -28.0
	_hint.offset_right = -24.0
	_hint.offset_bottom = -6.0
	_hint.text = "C  continue"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color("9fd6d0"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_hint)
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
		_hint.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_visible_characters = _text.text.length()
		_text.visible_characters = -1
		_typing = false
		_hint.visible = true
		return
	_line_index += 1
	if _line_index >= _lines.size():
		visible = false
		finished.emit()
		return
	_show_current_line()

func _show_current_line() -> void:
	_text.text = _lines[_line_index]
	_visible_characters = 0.0
	_text.visible_characters = 0
	_typing = true
	_hint.visible = false
