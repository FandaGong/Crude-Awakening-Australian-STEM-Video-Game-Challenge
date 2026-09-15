extends Control

@export var grid_container: GridContainer
@export var head_slot: SlotUI
@export var body_slot: SlotUI
@export var acc_slot: SlotUI

@export var details_panel: Panel
@export var item_name_label: Label
@export var item_desc_label: Label

# Details popup offset
@export var details_panel_mouse_offset: Vector2 = Vector2(10, 10)

# Hovered controls
var _hovered: Dictionary = {}

func _ready() -> void:
	hide() # Start hidden

	# Signals
	GameData.inventory_updated.connect(refresh_inventory)
	GameData.equipment_changed.connect(_on_equipment_changed)

	# Inventory slots
	var slots = grid_container.get_children()
	for i in range(slots.size()):
		var slot = slots[i] as SlotUI
		slot.slot_index = i

	refresh_inventory()

	details_panel.mouse_entered.connect(_on_panel_hover_entered)
	details_panel.mouse_exited.connect(_on_panel_hover_exited)
	details_panel.hide()

	_connect_slot_hover(head_slot)
	_connect_slot_hover(body_slot)
	_connect_slot_hover(acc_slot)
	for slot in slots:
		_connect_slot_hover(slot as SlotUI)

func _connect_slot_hover(slot: SlotUI) -> void:
	slot.mouse_entered.connect(_on_slot_hover_entered.bind(slot))
	slot.mouse_exited.connect(_on_slot_hover_exited.bind(slot))

# Details popup position
func _process(_delta: float) -> void:
	if details_panel.visible and _is_hovering_a_slot():
		_position_details_panel(get_global_mouse_position())

func _is_hovering_a_slot() -> bool:
	for key in _hovered.keys():
		if key is SlotUI:
			return true
	return false

# Clamp to viewport
func _position_details_panel(global_mouse_pos: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := details_panel.size
	var target := global_mouse_pos + details_panel_mouse_offset
	target.x = clamp(target.x, 0.0, max(0.0, viewport_size.x - panel_size.x))
	target.y = clamp(target.y, 0.0, max(0.0, viewport_size.y - panel_size.y))
	details_panel.global_position = target

func _on_slot_hover_entered(slot: SlotUI) -> void:
	if not (slot.slot_data and slot.slot_data.item_data):
		return
	_hovered[slot] = true
	_show_item_details(slot.slot_data)
	_position_details_panel(get_global_mouse_position())
	details_panel.show()

func _on_slot_hover_exited(slot: SlotUI) -> void:
	_hovered.erase(slot)
	call_deferred("_update_panel_visibility")

func _on_panel_hover_entered() -> void:
	_hovered[details_panel] = true

func _on_panel_hover_exited() -> void:
	_hovered.erase(details_panel)
	call_deferred("_update_panel_visibility")

# Prevent hover flicker
func _update_panel_visibility() -> void:
	if _hovered.is_empty():
		details_panel.hide()

func _show_item_details(data: SlotData) -> void:
	var item := data.item_data
	item_name_label.text = item.name if data.quantity <= 1 else "%s x%d" % [item.name, data.quantity]
	item_desc_label.text = item.description

func refresh_inventory() -> void:
	var slots = grid_container.get_children()
	for i in range(slots.size()):
		if i < GameData.otter_inventory_slots.size():
			(slots[i] as SlotUI).set_slot_data(GameData.otter_inventory_slots[i])

func _on_equipment_changed(_slot_type: ItemData.ItemType, _item: ItemData) -> void:
	# Signal placeholder
	pass
