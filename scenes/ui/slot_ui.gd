class_name SlotUI
extends PanelContainer

signal slot_clicked(slot_ui: SlotUI)

@onready var icon_rect: TextureRect = $Icon if has_node("Icon") else get_node_or_null("icon")
@onready var count_label: Label = $CountLabel if has_node("CountLabel") else get_node_or_null("Countlabel")

@export var allowed_type: ItemData.ItemType = ItemData.ItemType.GENERIC
var slot_index: int = -1
var slot_data: SlotData

func _ready() -> void:
	gui_input.connect(_on_gui_input)
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
	return self

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is SlotUI:
		var dragged_item = data.slot_data.item_data
		if not dragged_item:
			return false
		if allowed_type != ItemData.ItemType.GENERIC:
			return dragged_item.item_type == allowed_type
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is SlotUI and data != self:
		var temp_item = slot_data.item_data if slot_data else null
		var temp_qty = slot_data.quantity if slot_data else 0

		if not slot_data:
			slot_data = SlotData.new()

		slot_data.item_data = data.slot_data.item_data
		slot_data.quantity = data.slot_data.quantity

		data.slot_data.item_data = temp_item
		data.slot_data.quantity = temp_qty

		set_slot_data(slot_data)
		data.set_slot_data(data.slot_data)
		GameData.inventory_updated.emit()
