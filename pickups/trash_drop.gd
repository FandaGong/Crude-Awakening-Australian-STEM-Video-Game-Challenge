extends Node2D
class_name TrashDrop

## Auto-collecting trash drop, spawned when a mob is fully cured (see
## mutant_mob.gd's cureMob() and boss.gd's _die(), via Effects.spawn_trash_drop()).
##
## Lifecycle: scatters a short distance away from the mob -> settles (drifts
## slowly down if it's in water, or drops straight down onto the ground if
## it's not) -> waits a beat -> quick "absorb" pop -> flies into the HUD
## trash counter, shrinking as it travels -> increments GameData and pulses
## the counter on arrival.
##
## Uses a placeholder glowing-orb sprite (tinted per trash size) since there
## is no dedicated small/medium/large drop art yet.

@export_enum("small", "medium", "large") var trash_size: String = "small"

@onready var icon: Sprite2D = $Icon
@onready var glow: Sprite2D = $Glow

const SIZE_TINTS := {
	"small": Color(0.65, 1.0, 0.55),
	"medium": Color(0.45, 0.85, 1.0),
	"large": Color(1.0, 0.82, 0.35),
}
const SIZE_SCALES := {
	"small": 0.8,
	"medium": 1.05,
	"large": 1.35,
}

var _phase: String = "scatter"
var _in_water: bool = false
var _bob_t: float = 0.0
var _base_icon_scale: float = 1.0

func _ready() -> void:
	add_to_group("trash_drops")
	_bob_t = randf() * TAU

	var tint: Color = SIZE_TINTS.get(trash_size, Color.WHITE)
	_base_icon_scale = SIZE_SCALES.get(trash_size, 1.0)

	icon.modulate = tint
	icon.scale = Vector2.ONE * _base_icon_scale
	glow.modulate = Color(tint.r, tint.g, tint.b, 0.5)

	_in_water = _check_in_water()
	_scatter()

func _process(delta: float) -> void:
	# Gentle bob + glow pulse in every phase except mid-flight, where the
	# fly tween owns position/scale entirely.
	if _phase == "flying":
		return

	_bob_t += delta * 3.2
	icon.position.y = sin(_bob_t) * 2.0
	var pulse := 0.85 + 0.18 * sin(_bob_t * 1.4)
	glow.scale = Vector2.ONE * pulse * (_base_icon_scale * 2.1)

	if _phase == "settle_water":
		global_position.y += 10.0 * delta

func _check_in_water() -> bool:
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = global_position
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for result in space_state.intersect_point(params, 8):
		var collider = result.get("collider")
		if collider and (collider.is_in_group("water") or String(collider.name) == "waterArea"):
			return true
	return false

func _scatter() -> void:
	_phase = "scatter"
	var dir := Vector2.from_angle(randf() * TAU)
	var dist := randf_range(16.0, 40.0)
	var target := position + dir * dist

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target, randf_range(0.3, 0.4))
	tween.parallel().tween_property(self, "rotation", randf_range(-1.0, 1.0), 0.35)
	tween.tween_callback(_settle)

func _settle() -> void:
	if _in_water:
		_phase = "settle_water"
	else:
		_drop_to_ground()
	get_tree().create_timer(randf_range(0.5, 0.9)).timeout.connect(_begin_absorb)

func _drop_to_ground() -> void:
	_phase = "settle_land"
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 500))
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var result := space_state.intersect_ray(query)

	var land_y: float = global_position.y + 24.0
	if result:
		land_y = result.position.y - 6.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position:y", land_y, randf_range(0.3, 0.45))
	tween.tween_callback(func(): _phase = "idle")

func _begin_absorb() -> void:
	if _phase == "absorbing" or _phase == "flying":
		return
	_phase = "absorbing"

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.35, 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(glow, "modulate:a", 0.9, 0.1)
	tween.tween_callback(_fly_to_counter)

func _fly_to_counter() -> void:
	_phase = "flying"

	var hud_icon: Control = get_tree().root.get_node_or_null("Main/UI/HUD/largeTrash/crystalIcon")
	var hud_layer: Node = get_tree().root.get_node_or_null("Main/UI/HUD")
	if not hud_icon or not hud_layer:
		_finish_collect()
		return

	# Convert from world space into the same screen-pixel space the HUD's
	# CanvasLayer controls live in, then reparent so the flight isn't
	# affected by camera movement along the way.
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * global_position
	var old_parent := get_parent()
	if old_parent:
		old_parent.remove_child(self)
	hud_layer.add_child(self)
	position = screen_pos
	rotation = 0.0

	var target: Vector2 = hud_icon.global_position + hud_icon.size * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", scale * 0.15, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_finish_collect)

func _finish_collect() -> void:
	if GameData:
		GameData.add_trash(trash_size)
	if Effects:
		Effects.pulse_trash_counter()
	queue_free()
