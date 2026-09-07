extends Control

# Robot inventory panel with 12 equip slots and 16 inventory slots

@onready var equip_slots_container: GridContainer = $inventoryPanelBg/equipSlots
@onready var grid_container: GridContainer = $inventoryPanelBg/gridContainer

@onready var details_panel: Panel = $inventoryPanelBg/DetailsPanel
@onready var item_name_label: Label = $inventoryPanelBg/DetailsPanel/SkillNameLabel
@onready var item_desc_label: Label = $inventoryPanelBg/DetailsPanel/DescriptionLabel

## How far from the cursor (in viewport pixels) the popup is placed.
@export var details_panel_mouse_offset: Vector2 = Vector2(10, 10)

# Tracks every item slot (and the details panel itself) the mouse is
# currently over, mirroring the skill tree's hover-tracking approach: the
# popup is shown the instant this set stops being empty and hidden the
# instant it goes back to empty.
var _hovered: Dictionary = {}

func _ready() -> void:
	hide() # Start hidden
	add_to_group("robot_inventory_panel")
	
	# Connect signals
	GameData.inventory_updated.connect(refresh_inventory)
	GameData.equipment_changed.connect(_on_equipment_changed)

	# Setup 12 equip slots for robot (all generic type for now)
	var equip_slots = equip_slots_container.get_children()
	for i in range(equip_slots.size()):
		var slot = equip_slots[i] as SlotUI
		slot.slot_index = i + 100  # Offset to distinguish from otter equip slots
		slot.allowed_type = ItemData.ItemType.GENERIC
		slot.robot_owned_slot = true
		slot.robot_equipment_slot = true

	# Render only robot module relics. Otter head/body/accessory gear and
	# weapons belong exclusively to the otter panel and hotbar.
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

	# Setup 16 inventory slots for robot items
	var inv_slots = grid_container.get_children()
	for i in range(inv_slots.size()):
		var slot = inv_slots[i] as SlotUI
		slot.slot_index = i + 16  # Offset to distinguish from otter inventory slots
		slot.allowed_type = ItemData.ItemType.GENERIC
		slot.robot_owned_slot = true

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

## Keeps the popup tracking the cursor while it's over a slot. Once the
## cursor moves onto the popup itself we stop repositioning it, which lets
## the mouse travel from the slot onto the popup without it sliding away.
func _process(_delta: float) -> void:
	if details_panel.visible and _is_hovering_a_slot():
		_position_details_panel(get_global_mouse_position())

func _is_hovering_a_slot() -> bool:
	for key in _hovered.keys():
		if key is SlotUI:
			return true
	return false

## Places the popup just off the cursor, clamped so it never runs off the
## edge of the viewport.
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

## Deferred so that leaving one slot and entering an adjacent one (or the
## popup) in the same input pass doesn't flicker the popup closed and
## immediately back open.
func _update_panel_visibility() -> void:
	if _hovered.is_empty():
		details_panel.hide()

func _show_item_details(data: SlotData) -> void:
	var item := data.item_data
	item_name_label.text = item.name if data.quantity <= 1 else "%s x%d" % [item.name, data.quantity]
	item_desc_label.text = item.description

func refresh_inventory() -> void:
	# Refresh robot inventory slots
	var inv_slots = grid_container.get_children()
	for i in range(inv_slots.size()):
		if i < GameData.robot_inventory_slots.size():
			(inv_slots[i] as SlotUI).set_slot_data(GameData.robot_inventory_slots[i])

func _on_equipment_changed(_slot_type: ItemData.ItemType, _item: ItemData) -> void:
	# Parameters prefixed with '_' so Godot won't throw warnings
	pass

# Re-checks whether the robot's default weapon is still sitting in one of
# its 12 equip slots (it may have been dragged to another equip slot, into
# the inventory grid, or swapped out entirely) and syncs the result to
# GameData so the robot knows whether it's allowed to fire.
