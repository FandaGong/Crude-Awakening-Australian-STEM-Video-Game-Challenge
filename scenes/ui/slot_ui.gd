class_name SlotUI
extends PanelContainer

signal slot_clicked(slot_ui: SlotUI)

@onready var icon_rect: TextureRect = $Icon if has_node("Icon") else get_node_or_null("icon")
@onready var count_label: Label = $CountLabel if has_node("CountLabel") else get_node_or_null("Countlabel")

@export var allowed_type: ItemData.ItemType = ItemData.ItemType.GENERIC
@export var robot_owned_slot: bool = false
@export var robot_equipment_slot: bool = false
@export var hotbar_slot_index: int = -1
var slot_index: int = -1
var slot_data: SlotData

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if hotbar_slot_index >= 0:
		GameData.hotbar_abilities_changed.connect(_refresh_hotbar_item)
	# Initial draw if data was set before ready
	if slot_data:
		set_slot_data(slot_data)

func set_slot_data(data: SlotData) -> void:
	slot_data = data
	
	# Fallback if nodes are not ready yet
	if not icon_rect:
		icon_rect = $Icon if has_node("Icon") else get_node_or_null("icon")
	if not count_label:
		count_label = $CountLabel if has_node("CountLabel") else get_node_or_null("Countlabel")
	
	if slot_data and slot_data.item_data:
		if icon_rect:
			icon_rect.texture = slot_data.item_data.icon
			icon_rect.show()
		if count_label:
			count_label.text = str(slot_data.quantity) if slot_data.quantity > 1 else ""
	else:
		if icon_rect:
			icon_rect.texture = null
			icon_rect.hide()
		if count_label:
			count_label.text = ""
	if hotbar_slot_index >= 0:
		_refresh_hotbar_item()

func _refresh_hotbar_item() -> void:
	if hotbar_slot_index < 0 or not icon_rect:
		return
	if hotbar_slot_index >= GameData.active_abilities.size():
		icon_rect.texture = null
		return
	var item_id: String = GameData.active_abilities[hotbar_slot_index]
	var path := "res://resources/items/%s.tres" % item_id
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

# --- DRAG AND DROP ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not slot_data or not slot_data.item_data:
		return null
	var preview = TextureRect.new()
	preview.texture = slot_data.item_data.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = size
	set_drag_preview(preview)
	return {"source_slot": self, "slot_data": slot_data}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if hotbar_slot_index >= 0:
		return _get_hotbar_item(data) != null
	var source_slot := _get_source_slot(data)
	if source_slot:
		var dragged_item = source_slot.slot_data.item_data
		if not dragged_item:
			return false
		if robot_owned_slot != source_slot.robot_owned_slot:
			if robot_owned_slot and not GameData._is_robot_item(dragged_item):
				return false
			if not robot_owned_slot and GameData._is_robot_item(dragged_item):
				return false
		if robot_owned_slot and not GameData._is_robot_item(dragged_item):
			return false
		if robot_equipment_slot and not GameData._is_robot_item(dragged_item):
			return false
		if source_slot.robot_equipment_slot and not GameData._is_robot_item(dragged_item):
			return false
		if allowed_type != ItemData.ItemType.GENERIC:
			return dragged_item.item_type == allowed_type
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if hotbar_slot_index >= 0:
		var hotbar_item := _get_hotbar_item(data)
		if hotbar_item:
			GameData.set_hotbar_ability(hotbar_slot_index, hotbar_item.id)
		return
	var source_slot := _get_source_slot(data)
	if source_slot and source_slot != self:
		var temp_item = slot_data.item_data if slot_data else null
		var temp_qty = slot_data.quantity if slot_data else 0

		if not slot_data:
			slot_data = SlotData.new()

		slot_data.item_data = source_slot.slot_data.item_data
		slot_data.quantity = source_slot.slot_data.quantity

		source_slot.slot_data.item_data = temp_item
		source_slot.slot_data.quantity = temp_qty

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
	var source_slot := _get_source_slot(data)
	if not source_slot or not source_slot.slot_data or not source_slot.slot_data.item_data:
		return null
	var item: ItemData = source_slot.slot_data.item_data
	if item.item_type == ItemData.ItemType.WEAPON:
		return item
	if item.id in GameData.ABILITY_ITEM_IDS and GameData.active_abilities.has(item.id):
		return item
	return null

func _get_source_slot(data: Variant) -> SlotUI:
	if data is SlotUI:
		return data
	if data is Dictionary:
		return data.get("source_slot") as SlotUI
	return null
