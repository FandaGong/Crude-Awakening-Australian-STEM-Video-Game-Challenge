extends TextureButton

## Attach this script to any Button to give it a quick "dimming" tween
## on hover and press, so menus feel responsive without needing custom art.

@export var hoverBrightness: float = 0.88
@export var pressBrightness: float = 0.7
@export var tweenTime: float = 0.08

func _ready() -> void:
	# Connect the signals to our local methods
	mouse_entered.connect(_onMouseEntered)
	mouse_exited.connect(_onMouseExited)
	button_down.connect(_onButtonDown)
	button_up.connect(_onButtonUp)
	focus_entered.connect(_onMouseEntered)
	focus_exited.connect(_onMouseExited)

func _onMouseEntered() -> void:
	if disabled:
		return
	_dimTo(hoverBrightness)

func _onMouseExited() -> void:
	if disabled:
		return
	_dimTo(1.0)

func _onButtonDown() -> void:
	if disabled:
		return
	_dimTo(pressBrightness)

func _onButtonUp() -> void:
	if disabled:
		return
	# Settle on the hover shade if still hovering, otherwise return to full brightness
	var stillHovering := get_global_rect().has_point(get_global_mouse_position())
	_dimTo(hoverBrightness if stillHovering else 1.0)

func _dimTo(brightness: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate", Color(brightness, brightness, brightness, 1.0), tweenTime)
