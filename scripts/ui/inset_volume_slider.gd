extends HSlider

## Compact settings slider whose handle lives inside the track rather than
## hanging outside it. Drawing it here also lets a value of 100% fill the
## complete width of the bar.

const BAR_HEIGHT := 10.0
const KNOB_RADIUS := 4.0
const TRACK_COLOR := Color("263944")
const FILL_COLOR := Color("55b7bd")
const KNOB_COLOR := Color.WHITE

var _track_style := StyleBoxFlat.new()
var _fill_style := StyleBoxFlat.new()

func _ready() -> void:
	_track_style.bg_color = TRACK_COLOR
	_track_style.corner_radius_top_left = 5
	_track_style.corner_radius_top_right = 5
	_track_style.corner_radius_bottom_left = 5
	_track_style.corner_radius_bottom_right = 5
	_fill_style.bg_color = FILL_COLOR
	_fill_style.corner_radius_top_left = 5
	_fill_style.corner_radius_top_right = 5
	_fill_style.corner_radius_bottom_left = 5
	_fill_style.corner_radius_bottom_right = 5

	# Hide Godot's default grabber and track; this control draws its own
	# compact versions while retaining HSlider's normal input behavior.
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("slider", empty_style)
	add_theme_stylebox_override("grabber_area", empty_style)
	add_theme_stylebox_override("grabber_area_highlight", empty_style)
	var transparent_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	transparent_image.fill(Color.TRANSPARENT)
	var transparent_icon := ImageTexture.create_from_image(transparent_image)
	add_theme_icon_override("grabber", transparent_icon)
	add_theme_icon_override("grabber_highlight", transparent_icon)
	add_theme_icon_override("grabber_disabled", transparent_icon)
	value_changed.connect(func(_value: float): queue_redraw())
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var bar := Rect2(0.0, (size.y - BAR_HEIGHT) * 0.5, size.x, BAR_HEIGHT)
	draw_style_box(_track_style, bar)

	var percent := 0.0 if is_zero_approx(max_value - min_value) else clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)
	if percent > 0.0:
		# At maximum the filled rect is exactly the bar width.
		draw_style_box(_fill_style, Rect2(bar.position, Vector2(bar.size.x * percent, bar.size.y)))

	var knob_x := lerpf(bar.position.x + KNOB_RADIUS, bar.end.x - KNOB_RADIUS, percent)
	draw_circle(Vector2(knob_x, bar.get_center().y), KNOB_RADIUS, KNOB_COLOR)
