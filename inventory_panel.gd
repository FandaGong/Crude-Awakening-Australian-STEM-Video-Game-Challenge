extends Control

@onready var grid_container: GridContainer = $inventoryPanelBg/gridContainer
@onready var head_slot: SlotUI = $inventoryPanelBg/equipSlots/headSlot
@onready var body_slot: SlotUI = $inventoryPanelBg/equipSlots/bodySlot
@onready var acc_slot: SlotUI = $inventoryPanelBg/equipSlots/accSlot
@onready var otter_preview: AnimatedSprite2D = $inventoryPanelBg/mirrorContainer/otterPreview

func _ready() -> void:
	hide() # Start hidden
	
	# Configure equipment slot filter types
	head_slot.allowed_type = ItemData.ItemType.HEAD
	body_slot.allowed_type = ItemData.ItemType.BODY
	acc_slot.allowed_type = ItemData.ItemType.ACCESSORY

	# Connect signals
	GameData.inventory_updated.connect(refresh_inventory)
	GameData.equipment_changed.connect(_on_equipment_changed)

	# Assign indexes to the 16 bottom slots
	var slots = grid_container.get_children()
	for i in range(slots.size()):
		var slot = slots[i] as SlotUI
		slot.slot_index = i
		slot.allowed_type = ItemData.ItemType.GENERIC

	refresh_inventory()

func toggle_inventory() -> void:
	visible = not visible
	if visible:
		refresh_inventory()
		if otter_preview:
			otter_preview.play("idle")

func refresh_inventory() -> void:
	var slots = grid_container.get_children()
	for i in range(slots.size()):
		if i < GameData.inventory_slots.size():
			(slots[i] as SlotUI).set_slot_data(GameData.inventory_slots[i])

func _on_equipment_changed(_slot_type: ItemData.ItemType, _item: ItemData) -> void:
	# Parameters prefixed with '_' so Godot won't throw warnings
	pass

#func _unhandled_input(event: InputEvent) -> void:
#	if event.is_action_just_pressed("inventory_toggle") or event.is_action_just_pressed("ui_cancel"):
#		if visible:
#			toggle_inventory()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode: int = event.physical_keycode
		if keycode == KEY_E:
			toggle_inventory()
			get_viewport().set_input_as_handled()
			return

func _on_inventory_button_pressed() -> void:
	$".".toggle_inventory()
