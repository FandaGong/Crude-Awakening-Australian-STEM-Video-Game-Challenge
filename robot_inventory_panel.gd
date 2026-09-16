extends Control

# Robot inventory

@export var equip_slots_container: GridContainer
@export var grid_container: GridContainer

@export var details_panel: Panel
@export var item_name_label: Label
@export var item_desc_label: Label

# Details popup offset
@export var details_panel_mouse_offset: Vector2 = Vector2(10, 10)

# Hovered controls
var _hovered: Dictionary = {}

func _ready() -> void:
	hide() # Start hidden
	add_to_group("robot_inventory_panel")
	# The robot stores sixteen items in a two-row, eight-column tray.
	grid_container.columns = 8
	
	# Signals
	GameData.inventory_updated.connect(refresh_inventory)
	GameData.equipment_changed.connect(_on_equipment_changed)

	# Equipment slots
	var equip_slots = equip_slots_container.get_children()
	for i in range(equip_slots.size()):
		var slot = equip_slots[i] as SlotUI
		slot.slot_index = i + 100  # Offset to distinguish from otter equip slots

	# Robot modules
	var equipped_items: Array[ItemData] = []
	for module in GameData.get_equipped_robot_module_items():
		equipped_items.append(module)
	for i in range(min(equipped_items.size(), equip_slots.size())):
		var equipped_item := equipped_items[i]
		if not equipped_item:
			continue
		var slot_data := SlotData.new()
		slot_data.item_data = equipped_item
		slot_data.quantity = 1
		(equip_slots[i] as SlotUI).set_slot_data(slot_data)

	# Inventory slots
	var inv_slots = grid_container.get_children()
	for i in range(inv_slots.size()):
		var slot = inv_slots[i] as SlotUI
		slot.slot_index = i + 16  # Offset to distinguish from otter inventory slots

	refresh_inventory()

	details_panel.mouse_entered.connect(_on_panel_hover_entered)
	details_panel.mouse_exited.connect(_on_panel_hover_exited)
	details_panel.hide()

	for slot in equip_slots:
		_connect_slot_hover(slot as SlotUI)
	for slot in inv_slots:
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
	# Inventory slots
	var inv_slots = grid_container.get_children()
	for i in range(inv_slots.size()):
		if i < GameData.robot_inventory_slots.size():
			(inv_slots[i] as SlotUI).set_slot_data(GameData.robot_inventory_slots[i])

func _on_equipment_changed(_slot_type: ItemData.ItemType, _item: ItemData) -> void:
	# Signal placeholder
	pass

# Robot weapon state
