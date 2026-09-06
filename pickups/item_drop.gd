extends Node2D
class_name ItemDrop

## Physical, collectible drop for a real ItemData (gear, robot module, charm,
## ability materials, etc.), spawned when a mob/boss is cured (see
## mutant_mob.gd's cureMob(), boss.gd's _die(), and pickups/air_bubble.gd via
## Effects.spawn_item_drop()).
##
## Unlike TrashDrop (which auto-collects itself into the HUD counter the
## moment it settles), an ItemDrop just sits there once it settles - the
## otter has to actually swim/walk over to it to collect it. To make sure
## nothing genuinely valuable gets lost, though, an uncollected drop
## teleports itself straight into the robot's inventory after LIFETIME
## seconds, or immediately if the level changes first.
##
## Lifecycle: scatters a short distance away from the mob -> settles
## (drifts slowly down if it's in water, or drops straight down onto the
## ground if it's not, exactly like the player's own environment
## interactions) -> waits to be walked over -> quick "absorb" pop and a fly
## toward whoever collected it -> GameData.add_item().

const LIFETIME := 60.0
const PICKUP_RADIUS := 22.0

const FALLBACK_TINTS := {
	ItemData.ItemType.GENERIC: Color(1.0, 0.85, 0.35),
	ItemData.ItemType.HEAD: Color(0.55, 0.9, 1.0),
	ItemData.ItemType.BODY: Color(1.0, 0.55, 0.3),
	ItemData.ItemType.ACCESSORY: Color(0.75, 0.55, 1.0),
	ItemData.ItemType.WEAPON: Color(1.0, 0.4, 0.4),
}

@onready var icon: Sprite2D = $Icon
@onready var glow: Sprite2D = $Glow
@onready var pickup_area: Area2D = $PickupArea

var item_data: ItemData = null

var _phase: String = "scatter" # scatter -> settle_water/settle_land -> idle -> collecting
var _in_water: bool = false
var _bob_t: float = 0.0
var _lifetime_left: float = LIFETIME
var _collected: bool = false

## Must be called right after instancing, before or after adding to the
## tree - both work since the visuals are applied in _ready() once
## item_data is known.
func setup(item: ItemData) -> void:
	item_data = item
	if is_node_ready():
		_apply_visuals()

func _ready() -> void:
	add_to_group("item_drops")
	_bob_t = randf() * TAU
	_apply_visuals()

	pickup_area.body_entered.connect(_on_pickup_area_body_entered)
	Effects.level_will_change.connect(_on_level_will_change)

	_in_water = _check_in_water()
	_scatter()

func _apply_visuals() -> void:
	if not icon or not item_data:
		return
	if item_data.icon:
		icon.texture = item_data.icon
		icon.modulate = Color.WHITE
		glow.modulate = Color(1.0, 1.0, 1.0, 0.35)
	else:
		# No dedicated art yet for this item - fall back to a tinted glowing
		# orb (same placeholder approach TrashDrop uses), tinted by slot so
		# gear, charms, weapons, and robot modules read as visually distinct.
		var tint: Color = FALLBACK_TINTS.get(item_data.item_type, Color.WHITE)
		icon.modulate = tint
		glow.modulate = Color(tint.r, tint.g, tint.b, 0.55)

func _process(delta: float) -> void:
	if _phase == "flying" or _phase == "collecting":
		return

	_bob_t += delta * 3.2
	icon.position.y = sin(_bob_t) * 2.0
	var pulse := 0.85 + 0.18 * sin(_bob_t * 1.4)
	glow.scale = Vector2.ONE * pulse * 2.1

	if _phase == "settle_water":
		global_position.y += 10.0 * delta

	# Only start counting down the drop's lifetime once it has actually
	# settled somewhere - the brief scatter/settle animation shouldn't eat
	# into the minute the player has to notice and grab it.
	if _phase == "idle":
		_lifetime_left -= delta
		if _lifetime_left <= 0.0:
			_teleport_to_robot()

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

# --- Collection -------------------------------------------------------------

func _on_pickup_area_body_entered(body: Node2D) -> void:
	if _collected or _phase == "scatter":
		return
	if body.is_in_group("player"):
		_collect_to_inventory()

func _on_level_will_change() -> void:
	if _collected:
		return
	_teleport_to_robot()

func _collect_to_inventory() -> void:
	if _collected:
		return
	_collected = true
	_phase = "collecting"

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.3, 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(glow, "modulate:a", 0.9, 0.08)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_collect)

## Uncollected drops don't just vanish after LIFETIME seconds or on a level
## change - they're whisked away into the robot's inventory with a little
## warp-out flourish so it reads as "the robot grabbed that for you" rather
## than "the game ate your loot".
func _teleport_to_robot() -> void:
	if _collected:
		return
	_collected = true
	_phase = "collecting"

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(icon, "scale", icon.scale * 0.2, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(glow, "scale", glow.scale * 2.0, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(glow, "modulate:a", 0.0, 0.35)
	tween.tween_property(self, "rotation", rotation + TAU, 0.35)
	tween.chain().tween_callback(_finish_collect)

func _finish_collect() -> void:
	if item_data and GameData:
		GameData.add_item(item_data)
	queue_free()
