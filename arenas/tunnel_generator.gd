extends Node2D

## Builds the single dive tunnel the player swims down to reach every boss.
## It reads all 10 BossData resources and places a "gate" at each boss's
## depth, plus a merchant roughly halfway between consecutive gates. This is
## built at runtime so adding an 11th boss is just adding another .tres file
## and bumping GameData.TOTAL_BOSSES — no hand-edited level geometry needed.

const MerchantScene := preload("res://npc/merchant.tscn")
const PIXELS_PER_METER := 2.0
const TUNNEL_WIDTH := 220.0
const BOTTOM_PADDING := 500.0

# boss_id -> local Vector2 position of that boss's gate within the tunnel
var boss_gate_positions: Dictionary = {}

@onready var world: Node2D = get_parent()

func _ready() -> void:
	var boss_list := _load_all_boss_data()
	if boss_list.is_empty():
		return
	_build_shaft_visual(boss_list)
	_spawn_boss_gates(boss_list)
	_spawn_merchants(boss_list)

func _load_all_boss_data() -> Array:
	var list: Array = []
	for i in range(1, GameData.TOTAL_BOSSES + 1):
		var path := "res://resources/bosses/boss_%02d.tres" % i
		if ResourceLoader.exists(path):
			list.append(load(path))
	return list

func _depth_to_y(depth_meters: int) -> float:
	return float(depth_meters) * PIXELS_PER_METER

func _build_shaft_visual(boss_list: Array) -> void:
	var max_depth: float = _depth_to_y(boss_list[boss_list.size() - 1].depth_meters) + BOTTOM_PADDING
	var half_width := TUNNEL_WIDTH / 2.0

	var left_wall := Polygon2D.new()
	left_wall.color = Color(0.08, 0.11, 0.16)
	left_wall.polygon = PackedVector2Array([
		Vector2(-half_width - 24, -50), Vector2(-half_width, -50),
		Vector2(-half_width, max_depth), Vector2(-half_width - 24, max_depth),
	])
	add_child(left_wall)

	var right_wall := Polygon2D.new()
	right_wall.color = Color(0.08, 0.11, 0.16)
	right_wall.polygon = PackedVector2Array([
		Vector2(half_width, -50), Vector2(half_width + 24, -50),
		Vector2(half_width + 24, max_depth), Vector2(half_width, max_depth),
	])
	add_child(right_wall)

	var backdrop := Polygon2D.new()
	backdrop.color = Color(0.03, 0.06, 0.1)
	backdrop.polygon = PackedVector2Array([
		Vector2(-half_width, -50), Vector2(half_width, -50),
		Vector2(half_width, max_depth), Vector2(-half_width, max_depth),
	])
	add_child(backdrop)
	move_child(backdrop, 0) # draw behind the walls

	# The whole tunnel counts as water, so the player is always swimming here
	var water := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TUNNEL_WIDTH, max_depth + 50.0)
	shape.shape = rect
	shape.position = Vector2(0, (max_depth - 50.0) / 2.0)
	water.add_child(shape)
	water.body_entered.connect(_on_tunnel_water_entered)
	add_child(water)

func _on_tunnel_water_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.currentState = body.State.SWIMMING

func _spawn_boss_gates(boss_list: Array) -> void:
	for boss_data in boss_list:
		var y := _depth_to_y(boss_data.depth_meters)
		boss_gate_positions[boss_data.id] = Vector2(0, y)

		var gate := Area2D.new()
		gate.position = Vector2(0, y)
		add_child(gate)

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TUNNEL_WIDTH, 30)
		shape.shape = rect
		gate.add_child(shape)

		var visual := Polygon2D.new()
		visual.color = boss_data.color
		var hw := TUNNEL_WIDTH / 2.0
		visual.polygon = PackedVector2Array([
			Vector2(-hw, -8), Vector2(hw, -8), Vector2(hw, 8), Vector2(-hw, 8),
		])
		gate.add_child(visual)

		var label := Label.new()
		label.text = "%s\n(%d m)" % [boss_data.boss_name, boss_data.depth_meters]
		label.position = Vector2(-hw - 4, -40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		gate.add_child(label)

		gate.body_entered.connect(_on_gate_body_entered.bind(boss_data.id))

func _on_gate_body_entered(body: Node2D, boss_id: int) -> void:
	if not body.is_in_group("player"):
		return
	if not GameData.is_boss_unlocked(boss_id):
		return
	if world.has_method("enter_boss_arena"):
		world.enter_boss_arena(boss_id)

func _spawn_merchants(boss_list: Array) -> void:
	# One merchant just before the very first gate, then one between each pair
	var first_y := _depth_to_y(boss_list[0].depth_meters)
	_place_merchant(first_y * 0.5)

	for i in range(boss_list.size() - 1):
		var y_start := _depth_to_y(boss_list[i].depth_meters)
		var y_end := _depth_to_y(boss_list[i + 1].depth_meters)
		_place_merchant((y_start + y_end) / 2.0)

func _place_merchant(y: float) -> void:
	var merchant := MerchantScene.instantiate()
	add_child(merchant)
	merchant.position = Vector2(0, y)
	merchant.interacted.connect(_on_merchant_interacted)

func _on_merchant_interacted() -> void:
	if world.has_method("open_shop"):
		world.open_shop()
