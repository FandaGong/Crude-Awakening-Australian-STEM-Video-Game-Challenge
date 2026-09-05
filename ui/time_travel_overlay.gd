extends CanvasLayer

## Brief full-screen transition shown whenever the robot whisks the otter
## forward in time (first when the scientist activates the time machine,
## then again after every boss is cured). Purely cosmetic - world.gd awaits
## `finished` before actually moving the player/unlocking the next gate.

signal finished

@onready var fade: ColorRect = $Fade
@onready var year_label: Label = $YearLabel
@onready var title_label: Label = $TitleLabel

func play(year: int, era_title: String) -> void:
	year_label.text = str(year)
	title_label.text = era_title
	fade.modulate.a = 0.0
	year_label.modulate.a = 0.0
	title_label.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(year_label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(0.2)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.4)
	tween.tween_property(fade, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(year_label, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(title_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		finished.emit()
		queue_free()
	)
