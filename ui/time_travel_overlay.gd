extends CanvasLayer

## Brief full-screen transition shown whenever the robot whisks the otter
## forward in time (first when the scientist activates the time machine,
## then again after every boss is cured). Purely cosmetic - world.gd awaits
## `finished` before actually moving the player/unlocking the next gate.

signal finished

@onready var fade: ColorRect = $Fade
@onready var year_label: Label = $YearLabel
@onready var title_label: Label = $TitleLabel
@onready var skip_label: Label = $SkipLabel

# The timeline always begins in the present day, then advances one year at a
# time toward the selected historical turning point. Each change slows down
# as it nears its destination.
const CURRENT_YEAR := 2026
const YEAR_SPIN_FASTEST_DELAY := 0.02
const YEAR_SPIN_SLOWEST_DELAY := 0.22
var _finished := false
var _active_tween: Tween

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip_time_travel"):
		get_viewport().set_input_as_handled()
		_skip()

func play(year: int, era_title: String) -> void:
	year_label.text = str(CURRENT_YEAR)
	title_label.text = era_title
	fade.modulate.a = 0.0
	year_label.modulate.a = 0.0
	title_label.modulate.a = 0.0
	skip_label.modulate.a = 0.0

	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(fade, "modulate:a", 1.0, 0.4)
	fade_in_tween.parallel().tween_property(year_label, "modulate:a", 1.0, 0.4)
	fade_in_tween.parallel().tween_property(skip_label, "modulate:a", 1.0, 0.4)
	await fade_in_tween.finished

	await _spin_year_label(year)

	_active_tween = create_tween()
	_active_tween.tween_interval(0.2)
	_active_tween.tween_property(title_label, "modulate:a", 1.0, 0.5)
	_active_tween.tween_interval(1.4)
	_active_tween.tween_property(fade, "modulate:a", 0.0, 0.4)
	_active_tween.parallel().tween_property(year_label, "modulate:a", 0.0, 0.4)
	_active_tween.parallel().tween_property(title_label, "modulate:a", 0.0, 0.4)
	_active_tween.parallel().tween_property(skip_label, "modulate:a", 0.0, 0.4)
	_active_tween.tween_callback(_finish)

func _skip() -> void:
	if _finished:
		return
	if _active_tween:
		_active_tween.kill()
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	finished.emit()
	queue_free()

## Advances the real calendar from 2026 through every intervening year,
## beginning rapidly and progressively easing to a stop at the destination.
func _spin_year_label(target_year: int) -> void:
	if target_year <= CURRENT_YEAR:
		year_label.text = str(target_year)
		return
	var total_steps := target_year - CURRENT_YEAR
	for year in range(CURRENT_YEAR + 1, target_year + 1):
		year_label.text = str(year)
		if year == target_year:
			break
		var progress := float(year - CURRENT_YEAR) / float(total_steps)
		# Cubic ease-out keeps early years fast and lets the final years linger.
		var eased_progress := 1.0 - pow(1.0 - progress, 3.0)
		var delay: float = lerp(YEAR_SPIN_FASTEST_DELAY, YEAR_SPIN_SLOWEST_DELAY, eased_progress)
		await get_tree().create_timer(delay).timeout
