extends TextureButton

# Hover brightness
@export var hover_brightness: float = 0.88
# Press brightness
@export var press_brightness: float = 0.7
# Fade duration
@export var tween_time: float = 0.08


func _ready() -> void:
	# Signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	# Mouse state
	focus_entered.connect(_on_mouse_entered)
	focus_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if disabled:
		return
	_animate_to_brightness(hover_brightness)


func _on_mouse_exited() -> void:
	if disabled:
		return
	_animate_to_brightness(1.0)  # Full brightness when not hovered.


func _on_button_down() -> void:
	if disabled:
		return
	_animate_to_brightness(press_brightness)


func _on_button_up() -> void:
	if disabled:
		return
	# Hover state
	var is_still_hovering: bool = get_global_rect().has_point(get_global_mouse_position())
	var target_brightness: float = 0
	if is_still_hovering == true: target_brightness = hover_brightness
	_animate_to_brightness(target_brightness)


func _animate_to_brightness(brightness: float) -> void:
	# Smooth fade
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate", Color(brightness, brightness, brightness, 1.0), tween_time)
