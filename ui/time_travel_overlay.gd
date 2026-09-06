extends CanvasLayer

## Brief full-screen transition shown whenever the robot whisks the otter
## forward in time (first when the scientist activates the time machine,
## then again after every boss is cured). Purely cosmetic - world.gd awaits
## `finished` before actually moving the player/unlocking the next gate.

signal finished

@onready var fade: ColorRect = $Fade
@onready var year_label: Label = $YearLabel
@onready var title_label: Label = $TitleLabel

# How many "digits flicker" steps the year slider runs through before
# landing on the real target year, and the fastest/slowest delay between
# steps. Interpolating the per-step delay from fast to slow (rather than
# just the step count) is what sells the "spinning up, then settling"
# feel of an odometer or slot machine coming to rest.
const YEAR_SPIN_STEPS := 16
const YEAR_SPIN_FASTEST_DELAY := 0.02
const YEAR_SPIN_SLOWEST_DELAY := 0.22
const YEAR_SPIN_SCATTER := 450

func play(year: int, era_title: String) -> void:
	year_label.text = str(year)
	title_label.text = era_title
	fade.modulate.a = 0.0
	year_label.modulate.a = 0.0
	title_label.modulate.a = 0.0

	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(fade, "modulate:a", 1.0, 0.4)
	fade_in_tween.parallel().tween_property(year_label, "modulate:a", 1.0, 0.4)
	await fade_in_tween.finished

	await _spin_year_label(year)

	var tween := create_tween()
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

## Flips the year label through a handful of nearby years, starting fast
## and easing into slower and slower steps until it settles exactly on
## the real target year - like a slot machine or an odometer winding down.
func _spin_year_label(target_year: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(YEAR_SPIN_STEPS):
		var progress := float(i) / float(YEAR_SPIN_STEPS - 1)
		# Cubic ease-out: delay barely grows at first, then stretches out.
		var eased_progress := 1.0 - pow(1.0 - progress, 3.0)
		if i == YEAR_SPIN_STEPS - 1:
			year_label.text = str(target_year)
		else:
			var offset := rng.randi_range(-YEAR_SPIN_SCATTER, YEAR_SPIN_SCATTER)
			year_label.text = str(target_year + offset)
		var delay: float = lerp(YEAR_SPIN_FASTEST_DELAY, YEAR_SPIN_SLOWEST_DELAY, eased_progress)
		await get_tree().create_timer(delay).timeout
