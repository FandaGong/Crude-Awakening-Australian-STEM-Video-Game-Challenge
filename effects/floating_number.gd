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
	var magnitude := maxf(1.0, absf(amount))
	settings.font_size = clampi(14 + int(round(log(magnitude + 1.0) * 4.0)), 14, 28)
	settings.outline_size = 3
	settings.outline_color = Color(0, 0, 0, 0.9)
	var intensity := clampf(log(magnitude + 1.0) / log(101.0), 0.0, 1.0)
	var low_color := Color(0.35, 0.8, 0.45) if is_heal else Color(1.0, 0.35, 0.3)
	var high_color := Color(0.7, 1.0, 0.95) if is_heal else Color(1.0, 0.9, 0.2)
	settings.font_color = low_color.lerp(high_color, intensity)

	label.label_settings = settings
	label.text = ("+" if is_heal else "-") + (str(int(round(amount))) if magnitude >= 1.0 else "1")

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
