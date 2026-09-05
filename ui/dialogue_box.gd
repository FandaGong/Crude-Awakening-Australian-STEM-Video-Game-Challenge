extends CanvasLayer
class_name DialogueBox

## Full-width, screen-space dialogue used by every story conversation.
## C either finishes the current typed line or advances to the next one.

signal finished

@export_range(10.0, 120.0, 1.0) var characters_per_second := 48.0

# --- Dedicated Theme Asset Selectors ---
@export_group("Custom Theme Slots")
## Drag your custom Font resource (.tres) or raw font file (.ttf/.otf) here
@export var custom_font: Font

## Drag your custom background 9-patch panel stylebox (.tres resource) here
@export var patch_box_style: StyleBoxTexture

# --- NEW: 9-Patch Middle Section Extending Options ---
@export_group("9-Patch Axis Stretch Options")
## How the middle horizontal part of your texture stretches (Scale, Tile, or Stretch)
@export var horizontal_stretch_mode: StyleBoxTexture.AxisStretchMode = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
## How the middle vertical part of your texture stretches (Scale, Tile, or Stretch)
@export var vertical_stretch_mode: StyleBoxTexture.AxisStretchMode = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH

# --- NEW: Inspector Padding Sliders ---
@export_group("Text Padding Margins")
## Inner text clearance from the left edge of the patch box
@export var text_margin_left: float = 28.0
## Inner text clearance from the right edge of the patch box
@export var text_margin_right: float = 28.0
## Inner text clearance from the top edge of the patch box
@export var text_margin_top: float = 20.0
## Inner text clearance from the bottom edge of the patch box
@export var text_margin_bottom: float = 28.0

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
	
	# Aligns the box to the bottom-wide sector of the viewport screen space
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	
	# FIXED: Forces the box to run completely flush to the absolute bottom bounds of your window
	_panel.offset_top = -110.0     # Reduced height even further to save vertical space
	_panel.offset_bottom = 0.0     # Explicitly zeroed to make sure it hits the exact bottom screen edge
	_panel.offset_left = 0.0       # Extended fully horizontally to leave no side gaps
	_panel.offset_right = 0.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Applies your custom patch box resource if dropped into the inspector slot
	if patch_box_style:
		# Apply your custom chosen axis stretch modes directly to the texture resource
		patch_box_style.axis_stretch_horizontal = horizontal_stretch_mode
		patch_box_style.axis_stretch_vertical = vertical_stretch_mode
		
		# CHANGED: Added structural padding boundaries onto the custom texture resource container
		patch_box_style.content_margin_left = text_margin_left
		patch_box_style.content_margin_right = text_margin_right
		patch_box_style.content_margin_top = text_margin_top
		patch_box_style.content_margin_bottom = text_margin_bottom
		
		_panel.add_theme_stylebox_override("panel", patch_box_style)
	else:
		# Legacy StyleBoxFlat setup as a safety fallback if no patch box style is provided
		var style := StyleBoxFlat.new()
		style.bg_color = Color("102331f2")
		style.border_color = Color("81d8d0")
		style.set_border_width_all(2)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 0 
		style.corner_radius_bottom_right = 0 
		
		# CHANGED: Restored padding margins here to act as a fallback safety net
		style.content_margin_left = text_margin_left
		style.content_margin_right = text_margin_right
		style.content_margin_top = text_margin_top
		style.content_margin_bottom = text_margin_bottom
		_panel.add_theme_stylebox_override("panel", style)
		
	add_child(_panel)

	_text = Label.new()
	# CHANGED: Bumped up internal fallback layout offset (from 16 to 28) to safeguard text boundary limits
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# FIXED: Changed alignment properties from centered to Top-Left
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	
	# FIXED: Dropped down significantly to a clear, micro-sized layout format (15px)
	_text.add_theme_font_size_override("font_size", 15)
	_text.add_theme_color_override("font_color", Color("eaf8f5"))
	
	# Override the text font using your theme selector asset
	if custom_font:
		_text.add_theme_font_override("font", custom_font)
		_text.add_theme_font_size_override("font_size", 10)
		
	_panel.add_child(_text)

	_hint = Label.new()
	# Locks the prompt container safely to the bottom-right corner zone inside the patch box bounds
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	
	# Absolute control offsets ensure it remains safely inside the inner patch borders
	_hint.offset_left = -140.0
	_hint.offset_top = -28.0
	_hint.offset_right = -28.0     
	_hint.offset_bottom = -8.0     
	_hint.text = "C  continue"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color("9fd6d0"))
	
	# Apply the same custom font asset to your advance hint prompt
	if custom_font:
		_hint.add_theme_font_override("font", custom_font)
		
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
