extends Node

## Global game state: currency, boss progression, weapon shop, and inventory/equipment.
## Registered as an autoload singleton named "GameData".

# --- Signals -------------------------------------------------------------
signal crystals_changed(new_amount: int)
signal boss_unlocked(boss_id: int)
signal boss_defeated(boss_id: int)
signal weapon_purchased(weapon_id: String)
signal weapon_equipped(weapon_id: String)

signal inventory_updated
signal equipment_changed(slot_type: ItemData.ItemType, item: ItemData)

# --- Constants & Variables -----------------------------------------------
const TOTAL_BOSSES := 10
const SAVE_PATH := "user://crude_awakening_save.json"

# Progression
var crystals: int = 0
var highest_unlocked_boss: int = 1 
var defeated_bosses: Array = [] 
var owned_weapon_ids: Array = ["starter_spear"] 
var equipped_weapon_id: String = "starter_spear"

# Inventory & Equipment
var inventory_slots: Array[SlotData] = []
var equip_head: ItemData = null
var equip_body: ItemData = null
var equip_accessory: ItemData = null

func _ready() -> void:
	# Initialize 16 empty inventory slots
	inventory_slots.resize(16)
	for i in range(16):
		inventory_slots[i] = SlotData.new()
	
	load_game()

# --- Inventory Logic ------------------------------------------------------

func add_item(item: ItemData, amount: int = 1) -> bool:
	# 1. Stack into existing slots
	for slot in inventory_slots:
		if slot.item_data == item and slot.quantity < item.max_stack:
			var can_add = min(amount, item.max_stack - slot.quantity)
			slot.quantity += can_add
			amount -= can_add
			if amount == 0:
				inventory_updated.emit()
				save_game()
				return true

	# 2. Put into first empty slot
	for slot in inventory_slots:
		if slot.item_data == null:
			slot.item_data = item
			slot.quantity = amount
			inventory_updated.emit()
			save_game()
			return true

	return false # Inventory is full

func equip_item(slot_type: ItemData.ItemType, item: ItemData) -> void:
	match slot_type:
		ItemData.ItemType.HEAD:
			equip_head = item
		ItemData.ItemType.BODY:
			equip_body = item
		ItemData.ItemType.ACCESSORY:
			equip_accessory = item
	equipment_changed.emit(slot_type, item)
	save_game()

# --- Currency -------------------------------------------------------------

func add_crystals(amount: int) -> void:
	if amount <= 0: return
	crystals += amount
	crystals_changed.emit(crystals)
	save_game()

func spend_crystals(amount: int) -> bool:
	if amount <= 0 or crystals < amount: return false
	crystals -= amount
	crystals_changed.emit(crystals)
	save_game()
	return true

# --- Boss progression -------------------------------------------------------

func is_boss_unlocked(boss_id: int) -> bool: return boss_id <= highest_unlocked_boss
func is_boss_defeated(boss_id: int) -> bool: return defeated_bosses.has(boss_id)

func mark_boss_defeated(boss_id: int) -> void:
	if not defeated_bosses.has(boss_id):
		defeated_bosses.append(boss_id)
		boss_defeated.emit(boss_id)
	if boss_id >= highest_unlocked_boss and boss_id < TOTAL_BOSSES:
		highest_unlocked_boss = boss_id + 1
		boss_unlocked.emit(highest_unlocked_boss)
	save_game()

# --- Weapon shop ------------------------------------------------------------

func owns_weapon(weapon_id: String) -> bool: return owned_weapon_ids.has(weapon_id)

func purchase_weapon(weapon_id: String, cost: int) -> bool:
	if owns_weapon(weapon_id) or not spend_crystals(cost): return false
	owned_weapon_ids.append(weapon_id)
	weapon_purchased.emit(weapon_id)
	save_game()
	return true

func equip_weapon(weapon_id: String) -> void:
	if not owns_weapon(weapon_id): return
	equipped_weapon_id = weapon_id
	weapon_equipped.emit(weapon_id)
	save_game()

# --- Persistence -------------------------------------------------------------

func save_game() -> void:
	# Note: This assumes SlotData and ItemData have a way to be serialized 
	# (e.g., storing resource paths or IDs).
	var data := {
		"crystals": crystals,
		"highest_unlocked_boss": highest_unlocked_boss,
		"defeated_bosses": defeated_bosses,
		"owned_weapon_ids": owned_weapon_ids,
		"equipped_weapon_id": equipped_weapon_id,
		# You will need a custom method to serialize SlotData (e.g., using item IDs/paths)
		"inventory": serialize_inventory(),
		"equipment": {
			"head": equip_head.resource_path if equip_head else "",
			"body": equip_body.resource_path if equip_body else "",
			"accessory": equip_accessory.resource_path if equip_accessory else ""
		}
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	
	if typeof(parsed) != TYPE_DICTIONARY: return
	
	crystals = parsed.get("crystals", 0)
	highest_unlocked_boss = parsed.get("highest_unlocked_boss", 1)
	defeated_bosses = parsed.get("defeated_bosses", [])
	owned_weapon_ids = parsed.get("owned_weapon_ids", ["starter_spear"])
	equipped_weapon_id = parsed.get("equipped_weapon_id", "starter_spear")
	
	# Logic to deserialize inventory and equipment would go here
	# (Load resources via load(path) using the strings saved in save_game)

func serialize_inventory() -> Array:
	var inv_data = []
	for slot in inventory_slots:
		inv_data.append({"id": slot.item_data.resource_path if slot.item_data else "", "qty": slot.quantity})
	return inv_data

func reset_save() -> void:
	# ... (Reset variables to defaults)
	save_game()
