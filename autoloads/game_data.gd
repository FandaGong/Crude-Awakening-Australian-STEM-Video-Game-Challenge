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

signal compendium_data_changed(new_amount: int)
signal skill_unlocked(skill_id: String)
signal robot_unlocked_changed(unlocked: bool)

# --- Constants & Variables -----------------------------------------------
const TOTAL_BOSSES := 10
const SAVE_PATH := "user://crude_awakening_save.json"

# Progression (Otter)
var crystals: int = 0
var highest_unlocked_boss: int = 1 
var defeated_bosses: Array = [] 
var owned_weapon_ids: Array = ["starter_spear"] 
var equipped_weapon_id: String = "starter_spear"

# Progression (Robot & Skills)
var is_robot_unlocked: bool = false:
	set(value):
		is_robot_unlocked = value
		robot_unlocked_changed.emit(value)

var compendium_data: int = 0:
	set(value):
		compendium_data = max(0, value)
		compendium_data_changed.emit(compendium_data)

var unlocked_skills: Dictionary = {}
var skill_database: Dictionary = {}

# Inventory & Equipment (Resources used by the UI)
var inventory_slots: Array[SlotData] = []
var equip_head: ItemData = null
var equip_body: ItemData = null
var equip_accessory: ItemData = null
var equip_robot_module: ItemData = null

# --- Backwards-Compatible ID Helpers for Player & Robot Scripts ---
# These automatically retrieve the string id (e.g. "lure_headband") from the equipped resource
var equip_head_id: String:
	get: return equip_head.id if (equip_head and "id" in equip_head) else ""

var equip_body_id: String:
	get: return equip_body.id if (equip_body and "id" in equip_body) else ""

var equip_accessory_id: String:
	get: return equip_accessory.id if (equip_accessory and "id" in equip_accessory) else ""

var equip_robot_module_id: String:
	get: return equip_robot_module.id if (equip_robot_module and "id" in equip_robot_module) else ""

# --- Active Hotbar Abilities (3 slots) ---
var active_abilities: Array[String] = ["jelly_stinger", "crab_pincer", "pearlescent_volley"]

# --- Global Effect Timers ---
var bubble_booster_timer: float = 0.0

# --- Lifecycle -----------------------------------------------------------

func _ready() -> void:
	# Initialize 16 empty inventory slots
	inventory_slots.resize(16)
	for i in range(16):
		inventory_slots[i] = SlotData.new()
	
	_init_skill_database()
	load_game()

func _process(delta: float) -> void:
	if bubble_booster_timer > 0.0:
		bubble_booster_timer = max(0.0, bubble_booster_timer - delta)

# --- Inventory & Equipping Logic -----------------------------------------

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
			# Handle wetsuit air capacity changes dynamically
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("update_max_air_capacity"):
				player.update_max_air_capacity()
		ItemData.ItemType.ACCESSORY:
			equip_accessory = item
		ItemData.ItemType.WEAPON:
			if item and "id" in item:
				equip_weapon(item.id)
	
	equipment_changed.emit(slot_type, item)
	save_game()

func equip_gear(slot_type: String, item_id: String) -> void:
	# String fallback method for direct assignments
	var path = "res://resources/items/%s.tres" % item_id
	if ResourceLoader.exists(path):
		var item: ItemData = load(path)
		match slot_type:
			"head": equip_item(ItemData.ItemType.HEAD, item)
			"body": equip_item(ItemData.ItemType.BODY, item)
			"accessory": equip_item(ItemData.ItemType.ACCESSORY, item)
			"robot":
				equip_robot_module = item
				inventory_updated.emit()
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

# --- Robot Skill Tree Database ---------------------------------------------

func _init_skill_database() -> void:
	# --- 1. TARGETING & AI ---
	_register_skill("target_1", "Multi-Threat Scanner", "Robot prioritizes targeting mobs closest to the Otter.", SkillNodeData.Branch.TARGETING, 50, "")
	_register_skill("target_2", "Predictive Lock-On", "Curing projectiles gain slight homing capabilities.", SkillNodeData.Branch.TARGETING, 100, "target_1")
	_register_skill("target_3", "Priority Protocols", "Unlocks UI targeting priority toggles (Fast, Boss, Low-HP).", SkillNodeData.Branch.TARGETING, 150, "target_2")
	_register_skill("target_4", "Sovereign Eye", "[KEYSTONE] Doubles fire rate against mobs within 2 tiles of Otter.", SkillNodeData.Branch.TARGETING, 300, "target_3", true)

	# --- 2. OTTER-ROBOT SYNERGY ---
	_register_skill("synergy_1", "Guardian Relay", "Otter takes 15% less damage while performing physical skills.", SkillNodeData.Branch.SYNERGY, 50, "")
	_register_skill("synergy_2", "Stun Exploiter", "+25% curing output against stunned/slowed/blinded mobs.", SkillNodeData.Branch.SYNERGY, 100, "synergy_1")
	_register_skill("synergy_3", "Oxygen Siphon Array", "Fully cured mobs drop a Micro-Bubble (+15 Air).", SkillNodeData.Branch.SYNERGY, 150, "synergy_2")
	_register_skill("synergy_4", "Rescue Protocol", "[KEYSTONE] Emits 4-tile shockwave when Otter HP < 20% (60s CD).", SkillNodeData.Branch.SYNERGY, 300, "synergy_3", true)

	# --- 3. COMPENDIUM & DATA ---
	_register_skill("comp_1", "Database Calibration", "+15% cure speed against previously recorded species.", SkillNodeData.Branch.COMPENDIUM, 50, "")
	_register_skill("comp_2", "Bio-Analysis Engine", "Displays mob Cure % (0-100%), speed, and attack range HUD.", SkillNodeData.Branch.COMPENDIUM, 100, "comp_1")
	_register_skill("comp_3", "Data Harvesting", "Fully curing a Boss awards +50% bonus Compendium Data.", SkillNodeData.Branch.COMPENDIUM, 150, "comp_2")
	_register_skill("comp_4", "Universal Translator", "[KEYSTONE] Every 10% Compendium completion grants +1% speed to all modules.", SkillNodeData.Branch.COMPENDIUM, 300, "comp_3", true)

	# --- 4. OVERHEAT & POWER ---
	_register_skill("heat_1", "Heat Sink Vents", "Unlocks Overheat Gauge (+30% beam speed for 5s at max heat).", SkillNodeData.Branch.OVERHEAT, 50, "")
	_register_skill("heat_2", "Rapid Venting", "Reduces Overheat cooldown duration by 30%.", SkillNodeData.Branch.OVERHEAT, 100, "heat_1")
	_register_skill("heat_3", "Thermal Discharge", "Entering Overheat triggers a 3-tile warmth pulse (-40% mob speed).", SkillNodeData.Branch.OVERHEAT, 150, "heat_2")
	_register_skill("heat_4", "Supercharged Reactor", "[KEYSTONE] All equipped module passive stats doubled during Overheat.", SkillNodeData.Branch.OVERHEAT, 300, "heat_3", true)

func _register_skill(id: String, title: String, desc: String, branch: SkillNodeData.Branch, cost: int, req_id: String, keystone: bool = false) -> void:
	var node = SkillNodeData.new()
	node.id = id
	node.title = title
	node.description = desc
	node.branch = branch
	node.cost = cost
	node.required_node_id = req_id
	node.is_keystone = keystone
	skill_database[id] = node

func has_skill(skill_id: String) -> bool:
	return is_robot_unlocked and unlocked_skills.get(skill_id, false)

func can_unlock(skill_id: String) -> bool:
	if not is_robot_unlocked or not skill_database.has(skill_id):
		return false
	if has_skill(skill_id):
		return false
	var node: SkillNodeData = skill_database[skill_id]
	if compendium_data < node.cost:
		return false
	if node.required_node_id != "" and not has_skill(node.required_node_id):
		return false
	return true

func unlock_skill(skill_id: String) -> bool:
	if not can_unlock(skill_id):
		return false
	var node: SkillNodeData = skill_database[skill_id]
	compendium_data -= node.cost
	unlocked_skills[skill_id] = true
	skill_unlocked.emit(skill_id)
	save_game()
	return true

# --- Persistence -------------------------------------------------------------

func save_game() -> void:
	var data := {
		"crystals": crystals,
		"highest_unlocked_boss": highest_unlocked_boss,
		"defeated_bosses": defeated_bosses,
		"owned_weapon_ids": owned_weapon_ids,
		"equipped_weapon_id": equipped_weapon_id,
		
		# Robot & Skill Tree Data
		"is_robot_unlocked": is_robot_unlocked,
		"compendium_data": compendium_data,
		"unlocked_skills": unlocked_skills,
		"active_abilities": active_abilities,
		
		# Inventory Serialization
		"inventory": serialize_inventory(),
		"equipment": {
			"head": equip_head.resource_path if equip_head else "",
			"body": equip_body.resource_path if equip_body else "",
			"accessory": equip_accessory.resource_path if equip_accessory else "",
			"robot_module": equip_robot_module.resource_path if equip_robot_module else ""
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
	
	# Load Robot & Skill Tree properties
	is_robot_unlocked = parsed.get("is_robot_unlocked", false)
	compendium_data = parsed.get("compendium_data", 0)
	unlocked_skills = parsed.get("unlocked_skills", {})
	active_abilities = parsed.get("active_abilities", ["jelly_stinger", "crab_pincer", "pearlescent_volley"])
	
	# Deserialize equipment resources
	var equip_data = parsed.get("equipment", {})
	var head_path = equip_data.get("head", "")
	if head_path != "" and ResourceLoader.exists(head_path):
		equip_head = load(head_path)
	
	var body_path = equip_data.get("body", "")
	if body_path != "" and ResourceLoader.exists(body_path):
		equip_body = load(body_path)
	
	var acc_path = equip_data.get("accessory", "")
	if acc_path != "" and ResourceLoader.exists(acc_path):
		equip_accessory = load(acc_path)

	var rob_path = equip_data.get("robot_module", "")
	if rob_path != "" and ResourceLoader.exists(rob_path):
		equip_robot_module = load(rob_path)
	
	# Deserialize inventory
	var inv_list = parsed.get("inventory", [])
	for i in range(min(inv_list.size(), inventory_slots.size())):
		var slot_entry = inv_list[i]
		var item_path = slot_entry.get("id", "")
		if item_path != "" and ResourceLoader.exists(item_path):
			inventory_slots[i].item_data = load(item_path)
			inventory_slots[i].quantity = slot_entry.get("qty", 1)
		else:
			inventory_slots[i].item_data = null
			inventory_slots[i].quantity = 0

func serialize_inventory() -> Array:
	var inv_data = []
	for slot in inventory_slots:
		inv_data.append({
			"id": slot.item_data.resource_path if slot.item_data else "", 
			"qty": slot.quantity
		})
	return inv_data

func reset_save() -> void:
	crystals = 0
	highest_unlocked_boss = 1
	defeated_bosses = []
	owned_weapon_ids = ["starter_spear"]
	equipped_weapon_id = "starter_spear"
	is_robot_unlocked = false
	compendium_data = 0
	unlocked_skills = {}
	active_abilities = ["jelly_stinger", "crab_pincer", "pearlescent_volley"]
	
	equip_head = null
	equip_body = null
	equip_accessory = null
	equip_robot_module = null
	
	for slot in inventory_slots:
		slot.item_data = null
		slot.quantity = 0
		
	save_game()
