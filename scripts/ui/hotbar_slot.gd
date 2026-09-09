extends "res://scripts/ui/button_dim_fx.gd"
class_name HotbarSlotUI

## One of the 3 active-ability hotbar slots. Keeps the existing hover/press
## dimming behavior from button_dim_fx.gd and adds two things on top:
## - displaying the icon of whichever ability currently occupies this slot
## - accepting an ItemData dragged in from the inventory grid (SlotUI),
##   letting the player choose which unlocked ability sits in which slot.

## 0-based index into GameData.active_abilities / player.activeSlotIndex.
@export var slot_index: int = 0

@onready var icon_rect: TextureRect = get_node_or_null("Icon")

func _ready() -> void:
	super._ready()
	GameData.hotbar_abilities_changed.connect(_refresh_icon)
	_refresh_icon()

func _refresh_icon() -> void:
	if not icon_rect:
		return
	var item := _get_assigned_item()
	if item and item.icon:
		icon_rect.texture = item.icon
		icon_rect.show()
	else:
		icon_rect.texture = null
		icon_rect.hide()

func _get_assigned_item() -> ItemData:
	return GameData.get_hotbar_item(slot_index)

# --- Drag & drop: hotbar slots are movable inventory locations ---

func _get_drag_data(_at_position: Vector2) -> Variant:
	var item := _get_assigned_item()
	if not item:
		return null
	var preview := TextureRect.new()
	preview.texture = item.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = size
	set_drag_preview(preview)
	return {"source_hotbar_index": slot_index, "slot_data": null}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var source_hotbar_index := _source_hotbar_index(data)
	if source_hotbar_index >= 0:
		return source_hotbar_index != slot_index
	return _dragged_inventory_slot(data) != null

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_hotbar_index := _source_hotbar_index(data)
	if source_hotbar_index >= 0:
		GameData.swap_hotbar_slots(source_hotbar_index, slot_index)
		return
	var source_slot := _dragged_inventory_slot(data)
	if source_slot:
		GameData.move_inventory_to_hotbar(slot_index, source_slot.slot_data)

## Active abilities and otter weapons can be assigned here. Robot gear stays
## in the robot inventory and cannot occupy an otter hotbar slot.
func _dragged_ability_item(data: Variant) -> ItemData:
	var source_hotbar_index := _source_hotbar_index(data)
	if source_hotbar_index >= 0:
		return GameData.get_hotbar_item(source_hotbar_index)
	var source_slot := _dragged_inventory_slot(data)
	if not source_slot:
		return null
	var slot_data: SlotData = source_slot.slot_data
	if not slot_data or not slot_data.item_data:
		return null
	var item: ItemData = slot_data.item_data
	return item if GameData.is_hotbar_compatible(item) else null

func _dragged_inventory_slot(data: Variant) -> SlotUI:
	if data is SlotUI:
		return data if data.hotbar_slot_index < 0 else null
	if data is Dictionary:
		var source := data.get("source_slot") as SlotUI
		return source if source and source.hotbar_slot_index < 0 else null
	return null

func _source_hotbar_index(data: Variant) -> int:
	if data is Dictionary:
		return int(data.get("source_hotbar_index", -1))
	if data is SlotUI:
		return data.hotbar_slot_index
	return -1
