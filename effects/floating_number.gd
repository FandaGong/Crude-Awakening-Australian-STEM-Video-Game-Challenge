extends Node2D

## Small floating combat-text popup used for both damage and healing/curing
## feedback. Red "-N" for damage, green "+N" for healing. Purely cosmetic:
## spawned by Effects.show_number(), animates upward while fading out, then
## frees itself. See autoloads/effects.gd for the spawn helper.

@onready var label: Label = $Label

func setup(amount: float, is_heal: bool) -> void:
	var font := load("res://assets/fonts/VCR_OSD_MONO_1.001.ttf")

	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = 14
	settings.outline_size = 3
	settings.outline_color = Color(0, 0, 0, 0.9)
	settings.font_color = Color(0.35, 1.0, 0.45) if is_heal else Color(1.0, 0.35, 0.3)

	label.label_settings = settings
	label.text = ("+" if is_heal else "-") + str(int(round(amount)))

	# Small random horizontal scatter so stacked hits don't fully overlap.
	position.x += randf_range(-8.0, 8.0)
	scale = Vector2(0.5, 0.5)
	z_index = 200

	var rise := randf_range(28.0, 40.0)
	var start_y := position.y

	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var rise_tween := create_tween()
	rise_tween.tween_property(self, "position:y", start_y - rise, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var fade := create_tween()
	fade.tween_interval(0.45)
	fade.tween_property(label, "modulate:a", 0.0, 0.3)
	fade.tween_callback(queue_free)
