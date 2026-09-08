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
	if slot_index < 0 or slot_index >= GameData.active_abilities.size():
		return null
	var ability_id: String = GameData.active_abilities[slot_index]
	if ability_id == "":
		return null
	var path := "res://resources/items/%s.tres" % ability_id
	if ResourceLoader.exists(path):
		return load(path)
	return null

# --- Drag & drop: accept ability items dragged from an inventory slot ---

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var item := _dragged_ability_item(data)
	return item != null

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var item := _dragged_ability_item(data)
	if item:
		GameData.set_hotbar_ability(slot_index, item.id)

## Active abilities and otter weapons can be assigned here. Robot gear stays
## in the robot inventory and cannot occupy an otter hotbar slot.
func _dragged_ability_item(data: Variant) -> ItemData:
	var slot_data: SlotData = null
	if data is SlotUI:
		slot_data = data.slot_data
	elif data is Dictionary:
		slot_data = data.get("slot_data") as SlotData
	else:
		return null
	if not slot_data or not slot_data.item_data:
		return null
	var item: ItemData = slot_data.item_data
	if item.item_type == ItemData.ItemType.WEAPON:
		return item
	if item.id in GameData.ABILITY_ITEM_IDS and GameData.active_abilities.has(item.id):
		return item
	return null
