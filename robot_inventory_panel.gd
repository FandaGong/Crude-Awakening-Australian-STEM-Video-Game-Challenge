extends Control

# Robot inventory panel with 12 equip slots and 16 inventory slots

@onready var equip_slots_container: GridContainer = $inventoryPanelBg/equipSlots
@onready var grid_container: GridContainer = $inventoryPanelBg/gridContainer

func _ready() -> void:
	hide() # Start hidden
	
	# Connect signals
	GameData.inventory_updated.connect(refresh_inventory)
	GameData.equipment_changed.connect(_on_equipment_changed)

	# Setup 12 equip slots for robot (all generic type for now)
	var equip_slots = equip_slots_container.get_children()
	for i in range(equip_slots.size()):
		var slot = equip_slots[i] as SlotUI
		slot.slot_index = i + 100  # Offset to distinguish from otter equip slots
		slot.allowed_type = ItemData.ItemType.GENERIC

	# Setup 16 inventory slots for robot items
	var inv_slots = grid_container.get_children()
	for i in range(inv_slots.size()):
		var slot = inv_slots[i] as SlotUI
		slot.slot_index = i + 16  # Offset to distinguish from otter inventory slots
		slot.allowed_type = ItemData.ItemType.GENERIC

	refresh_inventory()

func refresh_inventory() -> void:
	# Refresh robot inventory slots
	var inv_slots = grid_container.get_children()
	for i in range(inv_slots.size()):
		if i < GameData.inventory_slots.size():
			(inv_slots[i] as SlotUI).set_slot_data(GameData.inventory_slots[i])

func _on_equipment_changed(_slot_type: ItemData.ItemType, _item: ItemData) -> void:
	# Parameters prefixed with '_' so Godot won't throw warnings
	pass
