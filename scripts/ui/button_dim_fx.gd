extends TextureButton

## Attach this script to any Button to give it a quick "dimming" tween
## on hover and press, so menus feel responsive without needing custom art.

@export var scale_multiplier: float = 3.0
@export var hover_brightness: float = 0.88
@export var press_brightness: float = 0.7
@export var tween_time: float = 0.08

func _ready() -> void:
	# --- Container Scaling & Hitbox Setup ---
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	if texture_normal:
		custom_minimum_size = texture_normal.get_size() * scale_multiplier
	# ----------------------------------------

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	focus_entered.connect(_on_mouse_entered)
	focus_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if disabled:
		return
	_dim_to(hover_brightness)

func _on_mouse_exited() -> void:
	if disabled:
		return
	_dim_to(1.0)

func _on_button_down() -> void:
	if disabled:
		return
	_dim_to(press_brightness)

func _on_button_up() -> void:
	if disabled:
		return
	# If the cursor is still over the button after release, settle on the
	# hover shade instead of snapping straight back to full brightness.
	var still_hovering := get_global_rect().has_point(get_global_mouse_position())
	_dim_to(hover_brightness if still_hovering else 1.0)

func _dim_to(brightness: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate", Color(brightness, brightness, brightness, 1.0), tween_time)
