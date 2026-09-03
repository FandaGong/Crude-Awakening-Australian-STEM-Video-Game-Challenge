extends Control

@onready var grid_container: GridContainer = $inventoryPanelBg/gridContainer
@onready var head_slot: SlotUI = $inventoryPanelBg/equipSlots/headSlot
@onready var body_slot: SlotUI = $inventoryPanelBg/equipSlots/bodySlot
@onready var acc_slot: SlotUI = $inventoryPanelBg/equipSlots/accSlot

func _ready() -> void:
	hide() # Start hidden
	
	# Configure equipment slot filter types
	head_slot.allowed_type = ItemData.ItemType.HEAD
	body_slot.allowed_type = ItemData.ItemType.BODY
	acc_slot.allowed_type = ItemData.ItemType.ACCESSORY

	# Connect signals
	GameData.inventory_updated.connect(refresh_inventory)
	GameData.equipment_changed.connect(_on_equipment_changed)

	# Assign indexes to the 16 bottom slots for otter inventory
	var slots = grid_container.get_children()
	for i in range(slots.size()):
		var slot = slots[i] as SlotUI
		slot.slot_index = i
		slot.allowed_type = ItemData.ItemType.GENERIC

	refresh_inventory()

func refresh_inventory() -> void:
	var slots = grid_container.get_children()
	for i in range(slots.size()):
		if i < GameData.inventory_slots.size():
			(slots[i] as SlotUI).set_slot_data(GameData.inventory_slots[i])

func _on_equipment_changed(_slot_type: ItemData.ItemType, _item: ItemData) -> void:
	# Parameters prefixed with '_' so Godot won't throw warnings
	pass
