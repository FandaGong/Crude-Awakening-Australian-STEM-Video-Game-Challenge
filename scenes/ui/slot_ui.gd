class_name SlotUI
extends PanelContainer

signal slot_clicked(slot_ui: SlotUI)

@export_category("Slot Type")
@export var allowed_type: ItemData.ItemType = ItemData.ItemType.GENERIC
@export var robot_owned_slot: bool = false
@export var robot_equipment_slot: bool = false
@export var hotbar_slot_index: int = -1

@export_category("References")
@export var icon_rect_path: NodePath = ^"Icon"
@export var count_label_path: NodePath = ^"CountLabel"
@export_global_dir var item_resource_dir: String = "res://resources/items/"

@onready var icon_rect: TextureRect = get_node_or_null(icon_rect_path) as TextureRect
@onready var count_label: Label = get_node_or_null(count_label_path) as Label

var slot_index: int = -1
var slot_data: SlotData

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if hotbar_slot_index >= 0:
		GameData.hotbar_abilities_changed.connect(_refresh_hotbar_item)
	if slot_data:
		set_slot_data(slot_data)

func set_slot_data(data: SlotData) -> void:
	slot_data = data

	var has_item := slot_data and slot_data.item_data
	if icon_rect:
		icon_rect.texture = slot_data.item_data.icon if has_item else null
		icon_rect.visible = has_item
	if count_label:
		count_label.text = str(slot_data.quantity) if has_item and slot_data.quantity > 1 else ""

	if hotbar_slot_index >= 0:
		_refresh_hotbar_item()

func _refresh_hotbar_item() -> void:
	if hotbar_slot_index < 0 or not icon_rect:
		return
	if hotbar_slot_index >= GameData.active_abilities.size():
		icon_rect.texture = null
		icon_rect.hide()
		return
	var item_id: String = GameData.active_abilities[hotbar_slot_index]
	var path := "%s%s.tres" % [item_resource_dir, item_id]
	if item_id != "" and ResourceLoader.exists(path):
		var item: ItemData = load(path)
		icon_rect.texture = item.icon
		icon_rect.show()
	else:
		icon_rect.texture = null
		icon_rect.hide()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(self)

# Drag and drop

func _get_drag_data(_at_position: Vector2) -> Variant:
	var dragged_item: ItemData = GameData.get_hotbar_item(hotbar_slot_index) if hotbar_slot_index >= 0 else (slot_data.item_data if slot_data else null)
	if not dragged_item:
		return null
	var preview := TextureRect.new()
	preview.texture = dragged_item.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = size
	preview.size = size
	# Offset the preview by half a slot so the cursor holds the item at its centre.
	preview.position = -size * 0.5
	set_drag_preview(preview)
	return {"source_slot": self, "slot_data": slot_data, "source_hotbar_index": hotbar_slot_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if hotbar_slot_index >= 0:
		return _get_hotbar_item(data) != null or _get_source_hotbar_index(data) >= 0

	if _get_source_hotbar_index(data) >= 0:
		return not robot_owned_slot and not robot_equipment_slot and allowed_type == ItemData.ItemType.GENERIC

	var source_slot := _get_source_slot(data)
	if not source_slot or not source_slot.slot_data or not source_slot.slot_data.item_data:
		return false

	var dragged_item: ItemData = source_slot.slot_data.item_data
	if not _is_robot_compatible(dragged_item, source_slot):
		return false
	if allowed_type != ItemData.ItemType.GENERIC:
		return dragged_item.item_type == allowed_type
	return true

func _is_robot_compatible(dragged_item: ItemData, source_slot: SlotUI) -> bool:
	var must_be_robot_item: bool = robot_owned_slot or robot_equipment_slot or source_slot.robot_owned_slot or source_slot.robot_equipment_slot
	if not must_be_robot_item:
		return true
	return GameData._is_robot_item(dragged_item)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if hotbar_slot_index >= 0:
		var source_hotbar_index := _get_source_hotbar_index(data)
		if source_hotbar_index >= 0:
			GameData.swap_hotbar_slots(source_hotbar_index, hotbar_slot_index)
			return
		var source_slot := _get_source_slot(data)
		if source_slot:
			GameData.move_inventory_to_hotbar(hotbar_slot_index, source_slot.slot_data)
		return

	var source_hotbar_index := _get_source_hotbar_index(data)
	if source_hotbar_index >= 0:
		if GameData.move_hotbar_to_inventory(source_hotbar_index, slot_data):
			set_slot_data(slot_data)
			GameData.save_game()
		return

	var source_slot := _get_source_slot(data)
	if source_slot and source_slot != self:
		_swap_item_data(source_slot)
		_finish_slot_swap(source_slot)

func _swap_item_data(source_slot: SlotUI) -> void:
	if not slot_data:
		slot_data = SlotData.new()
	var temp_item := slot_data.item_data
	var temp_qty := slot_data.quantity
	slot_data.item_data = source_slot.slot_data.item_data
	slot_data.quantity = source_slot.slot_data.quantity
	source_slot.slot_data.item_data = temp_item
	source_slot.slot_data.quantity = temp_qty

func _finish_slot_swap(source_slot: SlotUI) -> void:
	set_slot_data(slot_data)
	source_slot.set_slot_data(source_slot.slot_data)
	if robot_owned_slot or source_slot.robot_owned_slot:
		GameData.sync_robot_equipment_from_ui()
	else:
		GameData.sync_inventory_slot_equipment(slot_index, allowed_type, slot_data.item_data)
		GameData.sync_inventory_slot_equipment(source_slot.slot_index, source_slot.allowed_type, source_slot.slot_data.item_data)
	GameData.inventory_updated.emit()
	GameData.save_game()

func _get_hotbar_item(data: Variant) -> ItemData:
	var source_hotbar_index := _get_source_hotbar_index(data)
	if source_hotbar_index >= 0:
		return GameData.get_hotbar_item(source_hotbar_index)
	var source_slot := _get_source_slot(data)
	if not source_slot or not source_slot.slot_data or not source_slot.slot_data.item_data:
		return null
	var item: ItemData = source_slot.slot_data.item_data
	return item if GameData.is_hotbar_compatible(item) else null

func _get_source_slot(data: Variant) -> SlotUI:
	if data is SlotUI:
		return data
	if data is Dictionary:
		return data.get("source_slot") as SlotUI
	return null

func _get_source_hotbar_index(data: Variant) -> int:
	if data is Dictionary:
		return int(data.get("source_hotbar_index", -1))
	if data is SlotUI:
		return data.hotbar_slot_index
	return -1
