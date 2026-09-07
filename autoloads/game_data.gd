extends Node

## Global game state: currency, boss progression, weapon shop, and inventory/equipment.
## Registered as an autoload singleton named "GameData".

# --- Signals -------------------------------------------------------------
signal boss_unlocked(boss_id: int)
signal boss_defeated(boss_id: int)
signal weapon_equipped(weapon_id: String)

signal inventory_updated
signal equipment_changed(slot_type: ItemData.ItemType, item: ItemData)

signal compendium_data_changed(new_amount: int)
signal skill_unlocked(skill_id: String)
signal robot_unlocked_changed(unlocked: bool)
signal hotbar_abilities_changed

# --- Constants & Variables -----------------------------------------------
const TOTAL_BOSSES := 6 # the six Historical Turning Points: Crab, Jellyfish, Shell, Anglerfish, Whale, Kraken
const SAVE_PATH := "user://crude_awakening_save.json"
const PERSIST_SESSION := false

# Progression (Otter)
var highest_unlocked_boss: int = 1 
var defeated_bosses: Array = [] 
var owned_weapon_ids: Array = ["starter_spear"] 
var equipped_weapon_id: String = "starter_spear"

# Progression (Robot & Skills)
var is_robot_unlocked: bool = false:
	set(value):
		is_robot_unlocked = value
		robot_unlocked_changed.emit(value)

## Compendium Data: the robot's single research/upgrade currency. Earned
## both by fully curing mobs/bosses (see mutant_mob.gd, boss.gd) and by
## collecting recyclable trash debris (see add_trash() below - small/medium/
## large pieces are worth 1/3/5). Spent unlocking robot skill tree nodes.
var compendium_data: int = 0:
	set(value):
		compendium_data = max(0, value)
		compendium_data_changed.emit(compendium_data)

var unlocked_skills: Dictionary = {}
var skill_database: Dictionary = {}

# Inventory & Equipment (Resources used by the UI)
var otter_inventory_slots: Array[SlotData] = []
var robot_inventory_slots: Array[SlotData] = []
var inventory_slots: Array[SlotData]:
	get: return otter_inventory_slots
var equip_head: ItemData = null
var equip_body: ItemData = null
var equip_accessory: ItemData = null
var equip_robot_module: ItemData = null
var equipped_robot_module_ids: Array[String] = []
var photonic_spotlight_position: Vector2 = Vector2.ZERO

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

# Item ids that represent a mouse-aimed hotbar ability rather than a
# stackable/equippable item. Collecting one of these (see item_drop.gd)
# unlocks it for the hotbar in addition to sitting in the inventory as a
# keepsake - see add_item() below.
const ABILITY_ITEM_IDS := ["jelly_stinger", "crab_pincer", "pearlescent_volley", "abyssal_flare"]
const ROBOT_ITEM_IDS := [
	"baleen_core", "beak_sovereign", "geothermal_core", "overcharge_prism",
	"static_modulator", "photonic_beacon"
]

# --- Global Effect Timers ---
var bubble_booster_timer: float = 0.0
var time_revival_pending: bool = false

# --- Lifecycle -----------------------------------------------------------

func _ready() -> void:
	# Initialize independent otter and robot inventories.
	otter_inventory_slots.resize(16)
	robot_inventory_slots.resize(16)
	for i in range(16):
		otter_inventory_slots[i] = SlotData.new()
		robot_inventory_slots[i] = SlotData.new()
	
	_init_skill_database()
	load_game()

func _process(delta: float) -> void:
	if bubble_booster_timer > 0.0:
		bubble_booster_timer = max(0.0, bubble_booster_timer - delta)

# --- Inventory & Equipping Logic -----------------------------------------

func add_item(item: ItemData, amount: int = 1) -> bool:
	var target_inventory := robot_inventory_slots if _is_robot_item(item) else otter_inventory_slots
	if item and item.id == "photonic_beacon":
		var player = get_tree().get_first_node_in_group("player")
		if player:
			photonic_spotlight_position = player.global_position
	# Ability items unlock the matching mouse-aimed hotbar ability the first
	# time they're collected (e.g. Abyssal Flare from the Abyssal Anglerfish).
	# They still fall through and take up an inventory slot too, same as any
	# other collected item.
	if item and "id" in item and item.id in ABILITY_ITEM_IDS and not active_abilities.has(item.id):
		active_abilities.append(item.id)
		save_game()

	# Weapons never stack - each copy takes its own slot, regardless of
	# whatever max_stack happens to be set on the resource.
	var effective_max_stack: int = 1 if (item and item.item_type == ItemData.ItemType.WEAPON) else item.max_stack

	# 1. Stack into existing slots
	for slot in target_inventory:
		if slot.item_data == item and slot.quantity < effective_max_stack:
			var can_add = min(amount, effective_max_stack - slot.quantity)
			slot.quantity += can_add
			amount -= can_add
			if amount == 0:
				inventory_updated.emit()
				save_game()
				return true

	# 2. Put into empty slot(s). Weapons (effective_max_stack == 1) may need
	# more than one empty slot if amount > 1, since each copy is its own item.
	for slot in target_inventory:
		if slot.item_data == null:
			var give: int = min(amount, effective_max_stack)
			slot.item_data = item
			slot.quantity = give
			amount -= give
			if amount == 0:
				inventory_updated.emit()
				save_game()
				return true

	return false # Inventory is full

func _is_robot_item(item: ItemData) -> bool:
	return item != null and item.id in ROBOT_ITEM_IDS

func sync_robot_equipment_from_ui() -> void:
	var panel = get_tree().get_first_node_in_group("robot_inventory_panel")
	if not panel:
		return
	var new_module: ItemData = null
	var new_module_ids: Array[String] = []
	for slot_node in panel.equip_slots_container.get_children():
		var slot = slot_node as SlotUI
		if not slot or not slot.slot_data or not slot.slot_data.item_data:
			continue
		var item: ItemData = slot.slot_data.item_data
		if item.id not in ROBOT_ITEM_IDS:
			continue
		new_module = item
		new_module_ids.append(item.id)
	equip_robot_module = new_module
	equipped_robot_module_ids = new_module_ids
	equipment_changed.emit(ItemData.ItemType.GENERIC, null)
	save_game()

func equip_item(slot_type: ItemData.ItemType, item: ItemData) -> void:
	# All wearable and robot upgrades are powered, identified, and installed by
	# the companion robot. Keep the pre-robot wasteland sequence upgrade-free,
	# including calls that bypass the inventory UI.
	if not is_robot_unlocked:
		return
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
	if not is_robot_unlocked:
		return
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
				if not equipped_robot_module_ids.has(item.id):
					equipped_robot_module_ids.append(item.id)
				inventory_updated.emit()
				save_game()

func sync_inventory_slot_equipment(_slot_index: int, allowed_type: ItemData.ItemType, item: ItemData) -> void:
	if allowed_type == ItemData.ItemType.GENERIC:
		return
	match allowed_type:
		ItemData.ItemType.HEAD:
			equip_head = item
		ItemData.ItemType.BODY:
			equip_body = item
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("update_max_air_capacity"):
				player.update_max_air_capacity()
		ItemData.ItemType.ACCESSORY:
			equip_accessory = item
	equipment_changed.emit(allowed_type, item)
	save_game()

func get_cure_multiplier(target: Node) -> float:
	var multiplier := 1.0
	if has_skill("comp_1"):
		multiplier += 0.15
	if has_skill("synergy_2") and target:
		for status_name in ["stun_timer", "slow_timer", "blind_timer"]:
			var status_value = target.get(status_name)
			if status_value != null and float(status_value) > 0.0:
				multiplier += 0.25
				break
	return multiplier

func get_module_speed_multiplier() -> float:
	if not has_skill("comp_4"):
		return 1.0
	var completion_steps := int(round(float(defeated_bosses.size()) / float(TOTAL_BOSSES) * 10.0))
	return 1.0 + completion_steps * 0.01

func has_item(item_id: String) -> bool:
	for slot in otter_inventory_slots + robot_inventory_slots:
		if slot.item_data and slot.item_data.id == item_id and slot.quantity > 0:
			return true
	return false

func has_robot_module(module_id: String) -> bool:
	return equipped_robot_module_ids.has(module_id) or equip_robot_module_id == module_id

func get_equipped_robot_module_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for module_id in equipped_robot_module_ids:
		var path := "res://resources/items/%s.tres" % module_id
		if ResourceLoader.exists(path):
			result.append(load(path))
	if result.is_empty() and equip_robot_module:
		result.append(equip_robot_module)
	return result

# --- Hotbar -----------------------------------------------------------

## Assigns an already-unlocked ability to one of the 3 hotbar slots (0-2),
## e.g. via dragging its item from the inventory grid onto a hotbar slot.
## Safe no-op if the slot index or ability id is invalid.
func set_hotbar_ability(slot_index: int, ability_id: String) -> void:
	if slot_index < 0 or slot_index > 2:
		return
	var is_weapon := false
	var item_path := "res://resources/items/%s.tres" % ability_id
	if ResourceLoader.exists(item_path):
		var item: ItemData = load(item_path)
		is_weapon = item.item_type == ItemData.ItemType.WEAPON
	if not (ability_id in ABILITY_ITEM_IDS or is_weapon):
		return
	if not is_weapon and not active_abilities.has(ability_id):
		return
	while active_abilities.size() <= slot_index:
		active_abilities.append("")
	active_abilities[slot_index] = ability_id
	hotbar_abilities_changed.emit()
	save_game()

# --- Currency -------------------------------------------------------------

func add_trash(size: String = "small") -> void:
	var token_value: int = int({"small": 1, "medium": 3, "large": 5}.get(size, 1))
	compendium_data += token_value
	save_game()

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

# --- Weapons ------------------------------------------------------------
# Weapons are no longer bought from a merchant - they're found as WEAPON-type
# ItemData drops in the world and equipped straight from the inventory (see
# equip_item() above). owned_weapon_ids/owns_weapon are kept only so
# equipping stays tracked/saved the same way gear does.

func owns_weapon(weapon_id: String) -> bool: return owned_weapon_ids.has(weapon_id)

func equip_weapon(weapon_id: String) -> void:
	if not is_robot_unlocked:
		return
	if not owns_weapon(weapon_id):
		owned_weapon_ids.append(weapon_id)
	equipped_weapon_id = weapon_id
	weapon_equipped.emit(weapon_id)
	save_game()

# Looks up the ItemData representation of the currently equipped weapon so it
# can be displayed as an icon (e.g. in the robot's equip inventory). Weapons
# are otherwise tracked purely by WeaponData/id string, so this is just a
# display-facing bridge between the two systems.
func get_equipped_weapon_item() -> ItemData:
	var path := "res://resources/items/%s.tres" % equipped_weapon_id
	if ResourceLoader.exists(path):
		return load(path)
	return null

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
	if not PERSIST_SESSION:
		return
	var data := {
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
		"otter_inventory": serialize_slots(otter_inventory_slots),
		"robot_inventory": serialize_slots(robot_inventory_slots),
		"equipment": {
			"head": equip_head.resource_path if equip_head else "",
			"body": equip_body.resource_path if equip_body else "",
			"accessory": equip_accessory.resource_path if equip_accessory else "",
			"robot_module": equip_robot_module.resource_path if equip_robot_module else "",
			"robot_modules": equipped_robot_module_ids
		}
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not PERSIST_SESSION:
		return
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	
	if typeof(parsed) != TYPE_DICTIONARY: return
	
	highest_unlocked_boss = parsed.get("highest_unlocked_boss", 1)
	defeated_bosses = parsed.get("defeated_bosses", [])
	owned_weapon_ids = parsed.get("owned_weapon_ids", ["starter_spear"])
	equipped_weapon_id = parsed.get("equipped_weapon_id", "starter_spear")
	
	# Load Robot & Skill Tree properties
	is_robot_unlocked = parsed.get("is_robot_unlocked", false)
	compendium_data = parsed.get("compendium_data", 0)
	unlocked_skills = parsed.get("unlocked_skills", {})
	# JSON arrays are untyped at runtime. Rebuild the typed Array[String]
	# explicitly so older save files cannot cause a load-time type error.
	active_abilities.clear()
	var saved_abilities: Array = parsed.get("active_abilities", ["jelly_stinger", "crab_pincer", "pearlescent_volley"])
	for ability in saved_abilities:
		if ability is String:
			active_abilities.append(ability)
	
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
	equipped_robot_module_ids.clear()
	for module_id in equip_data.get("robot_modules", []):
		if module_id is String:
			equipped_robot_module_ids.append(module_id)
	if equipped_robot_module_ids.is_empty() and equip_robot_module:
		equipped_robot_module_ids.append(equip_robot_module.id)
	
	# Deserialize independent inventories. Older saves used one inventory and
	# are treated as otter inventory so no collected items disappear.
	var old_inventory = parsed.get("inventory", [])
	_deserialize_slots(parsed.get("otter_inventory", old_inventory), otter_inventory_slots)
	_deserialize_slots(parsed.get("robot_inventory", []), robot_inventory_slots)

func _deserialize_slots(entries: Array, slots: Array[SlotData]) -> void:
	for i in range(min(entries.size(), slots.size())):
		var slot_entry = entries[i]
		var item_path = slot_entry.get("id", "")
		if item_path != "" and ResourceLoader.exists(item_path):
			slots[i].item_data = load(item_path)
			slots[i].quantity = slot_entry.get("qty", 1)
		else:
			slots[i].item_data = null
			slots[i].quantity = 0

func serialize_slots(slots: Array[SlotData]) -> Array:
	var inv_data = []
	for slot in slots:
		inv_data.append({
			"id": slot.item_data.resource_path if slot.item_data else "",
			"qty": slot.quantity
		})
	return inv_data

func serialize_inventory() -> Array:
	return serialize_slots(otter_inventory_slots)

func reset_save() -> void:
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
	equipped_robot_module_ids.clear()
	
	for slot in otter_inventory_slots + robot_inventory_slots:
		slot.item_data = null
		slot.quantity = 0
		
	save_game()
