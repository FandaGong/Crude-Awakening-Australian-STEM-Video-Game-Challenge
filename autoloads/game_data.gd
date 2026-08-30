extends Node

## Global game state: currency, boss progression, and the weapon shop.
## Registered as an autoload singleton named "GameData".

signal crystals_changed(new_amount: int)
signal boss_unlocked(boss_id: int)
signal boss_defeated(boss_id: int)
signal weapon_purchased(weapon_id: String)
signal weapon_equipped(weapon_id: String)

const TOTAL_BOSSES := 10
const SAVE_PATH := "user://crude_awakening_save.json"

var crystals: int = 0
var highest_unlocked_boss: int = 1 # boss ids are 1-based
var defeated_bosses: Array = [] # array of boss ids defeated
var owned_weapon_ids: Array = ["starter_spear"] # everyone starts with a basic weapon
var equipped_weapon_id: String = "starter_spear"

func _ready() -> void:
	load_game()

# --- Currency -------------------------------------------------------------

func add_crystals(amount: int) -> void:
	if amount <= 0:
		return
	crystals += amount
	crystals_changed.emit(crystals)
	save_game()

func spend_crystals(amount: int) -> bool:
	if amount <= 0 or crystals < amount:
		return false
	crystals -= amount
	crystals_changed.emit(crystals)
	save_game()
	return true

# --- Boss progression -------------------------------------------------------

func is_boss_unlocked(boss_id: int) -> bool:
	return boss_id <= highest_unlocked_boss

func is_boss_defeated(boss_id: int) -> bool:
	return defeated_bosses.has(boss_id)

func mark_boss_defeated(boss_id: int) -> void:
	if not defeated_bosses.has(boss_id):
		defeated_bosses.append(boss_id)
		boss_defeated.emit(boss_id)
	if boss_id >= highest_unlocked_boss and boss_id < TOTAL_BOSSES:
		highest_unlocked_boss = boss_id + 1
		boss_unlocked.emit(highest_unlocked_boss)
	save_game()

# --- Weapon shop ------------------------------------------------------------

func owns_weapon(weapon_id: String) -> bool:
	return owned_weapon_ids.has(weapon_id)

func purchase_weapon(weapon_id: String, cost: int) -> bool:
	if owns_weapon(weapon_id):
		return false
	if not spend_crystals(cost):
		return false
	owned_weapon_ids.append(weapon_id)
	weapon_purchased.emit(weapon_id)
	save_game()
	return true

func equip_weapon(weapon_id: String) -> void:
	if not owns_weapon(weapon_id):
		return
	equipped_weapon_id = weapon_id
	weapon_equipped.emit(weapon_id)
	save_game()

# --- Persistence -------------------------------------------------------------

func save_game() -> void:
	var data := {
		"crystals": crystals,
		"highest_unlocked_boss": highest_unlocked_boss,
		"defeated_bosses": defeated_bosses,
		"owned_weapon_ids": owned_weapon_ids,
		"equipped_weapon_id": equipped_weapon_id,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	crystals = parsed.get("crystals", 0)
	highest_unlocked_boss = parsed.get("highest_unlocked_boss", 1)
	defeated_bosses = parsed.get("defeated_bosses", [])
	owned_weapon_ids = parsed.get("owned_weapon_ids", ["starter_spear"])
	equipped_weapon_id = parsed.get("equipped_weapon_id", "starter_spear")

func reset_save() -> void:
	crystals = 0
	highest_unlocked_boss = 1
	defeated_bosses = []
	owned_weapon_ids = ["starter_spear"]
	equipped_weapon_id = "starter_spear"
	save_game()
