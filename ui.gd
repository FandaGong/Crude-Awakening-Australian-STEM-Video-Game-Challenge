extends CanvasLayer

enum UIState { TITLE, LEVEL_SELECT, PLAYING, PAUSED, SETTINGS, SHOP }

var current_state: UIState = UIState.TITLE
var state_before_settings: UIState = UIState.TITLE
var state_before_shop: UIState = UIState.PLAYING

@onready var title_screen: Control = $titleScreen
@onready var level_select: Control = $levelSelect
@onready var settings_menu: Control = $settingsMenu
@onready var pause_menu: Control = $pauseMenu
@onready var shop_menu: Control = $shopMenu
@onready var hud: Control = $HUD

@onready var boss_list_container: VBoxContainer = $levelSelect/Panel/bossScroll/bossListContainer
@onready var level_select_crystal_label: Label = $levelSelect/Panel/crystalLabel
@onready var weapon_list_container: VBoxContainer = $shopMenu/Panel/weaponScroll/weaponListContainer
@onready var shop_crystal_label: Label = $shopMenu/Panel/crystalLabel
@onready var hud_crystal_label: Label = $HUD/currencyPanel/crystalLabel

const ButtonDimFxScript := preload("res://scripts/ui/button_dim_fx.gd")

# References relative to this UI node
@onready var player: CharacterBody2D = $"../World/player"
@onready var world: Node2D = $"../World"

func _ready() -> void:
	add_to_group("ui_controller")
	GameData.crystals_changed.connect(_on_crystals_changed)
	_update_crystal_labels(GameData.crystals)
	_set_state(UIState.TITLE)

func _on_crystals_changed(new_amount: int) -> void:
	_update_crystal_labels(new_amount)

func _update_crystal_labels(amount: int) -> void:
	if hud_crystal_label:
		hud_crystal_label.text = "Crystals: %d" % amount
	if level_select_crystal_label:
		level_select_crystal_label.text = "Aquamarine Crystals: %d" % amount
	if shop_crystal_label:
		shop_crystal_label.text = "Aquamarine Crystals: %d" % amount

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode: int = event.physical_keycode
		if keycode == KEY_1:
			_select_hotbar_slot(1)
			get_viewport().set_input_as_handled()
			return
		if keycode == KEY_2:
			_select_hotbar_slot(2)
			get_viewport().set_input_as_handled()
			return
		if keycode == KEY_3:
			_select_hotbar_slot(3)
			get_viewport().set_input_as_handled()
			return
		if keycode == KEY_E:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return

	if not event.is_action_pressed("ui_cancel"):
		return

	match current_state:
		UIState.PLAYING:
			_set_state(UIState.PAUSED)
		UIState.PAUSED:
			_set_state(UIState.PLAYING)
		UIState.SETTINGS:
			_close_settings()
		UIState.SHOP:
			_close_shop()
		UIState.LEVEL_SELECT:
			_set_state(UIState.TITLE)
		_:
			return
	get_viewport().set_input_as_handled()

# --- Central state switcher ---------------------------------------------
# settingsMenu and shopMenu are deliberately NOT touched here; they overlay
# whatever state was active before they opened, and their own close
# functions restore that state.
func _set_state(new_state: UIState) -> void:
	current_state = new_state

	title_screen.hide()
	level_select.hide()
	pause_menu.hide()
	hud.hide()
	get_tree().paused = false

	match new_state:
		UIState.TITLE:
			title_screen.show()
			_disable_player()
		UIState.LEVEL_SELECT:
			level_select.show()
			_populate_level_select()
			_disable_player()
		UIState.PLAYING:
			hud.show()
			_enable_player()
		UIState.PAUSED:
			hud.show()
			pause_menu.show()
			get_tree().paused = true

func _enable_player() -> void:
	if not player:
		return
	player.show()
	player.set_physics_process(true)
	player.set_process(true)

func _disable_player() -> void:
	if not player:
		return
	player.hide()
	player.set_physics_process(false)
	player.set_process(false)

# --- Title screen ---------------------------------------------------------

func _on_play_button_pressed() -> void:
	world.teleport_player_to_pond()
	_set_state(UIState.PLAYING)

func _on_levels_button_pressed() -> void:
	_set_state(UIState.LEVEL_SELECT)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# --- Level select -----------------------------------------------------

func _on_level_select_back_button_pressed() -> void:
	_set_state(UIState.TITLE)

const PLACEHOLDER_LEVEL_COUNT := 10

func _populate_level_select() -> void:
	if not boss_list_container:
		return
	for child in boss_list_container.get_children():
		child.queue_free()

	for i in range(1, PLACEHOLDER_LEVEL_COUNT + 1):
		var btn := Button.new()
		btn.set_script(ButtonDimFxScript)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.text = "Level %d" % i
		boss_list_container.add_child(btn)

# --- Settings (usable from the title screen, HUD, or pause menu) ---------

func _on_settings_button_pressed() -> void:
	state_before_settings = current_state
	current_state = UIState.SETTINGS
	settings_menu.show()
	get_tree().paused = true

func _on_close_button_pressed() -> void:
	_close_settings()

func _close_settings() -> void:
	settings_menu.hide()
	_set_state(state_before_settings)

# --- Shop (opened by merchants along the dive tunnel) ---------------------

func open_shop() -> void:
	if current_state == UIState.SHOP:
		return
	state_before_shop = current_state
	current_state = UIState.SHOP
	_populate_shop()
	shop_menu.show()
	get_tree().paused = true

func _on_shop_close_button_pressed() -> void:
	_close_shop()

func _close_shop() -> void:
	shop_menu.hide()
	_set_state(state_before_shop)

func _populate_shop() -> void:
	if not weapon_list_container:
		return
	for child in weapon_list_container.get_children():
		child.queue_free()

	var weapon_ids := ["starter_spear", "harpoon_gun", "coral_shard", "electric_eel_rod", "void_trident", "leviathan_fang"]
	for weapon_id in weapon_ids:
		var path := "res://resources/weapons/%s.tres" % weapon_id
		if not ResourceLoader.exists(path):
			continue
		var weapon: WeaponData = load(path)

		var row := HBoxContainer.new()
		weapon_list_container.add_child(row)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = "%s — dmg %d — %s" % [weapon.weapon_name, int(weapon.damage), weapon.description]
		row.add_child(info)

		var action_btn := Button.new()
		action_btn.set_script(ButtonDimFxScript)

		var owned: bool = GameData.owns_weapon(weapon_id)
		var equipped: bool = GameData.equipped_weapon_id == weapon_id

		if equipped:
			action_btn.text = "Equipped"
			action_btn.disabled = true
		elif owned:
			action_btn.text = "Equip"
			action_btn.pressed.connect(_on_equip_weapon_pressed.bind(weapon_id))
		else:
			action_btn.text = "Buy (%d)" % weapon.cost
			action_btn.disabled = GameData.crystals < weapon.cost
			action_btn.pressed.connect(_on_buy_weapon_pressed.bind(weapon_id, weapon.cost))

		row.add_child(action_btn)

func _on_buy_weapon_pressed(weapon_id: String, cost: int) -> void:
	if GameData.purchase_weapon(weapon_id, cost):
		GameData.equip_weapon(weapon_id)
		_populate_shop()

func _on_equip_weapon_pressed(weapon_id: String) -> void:
	GameData.equip_weapon(weapon_id)
	_populate_shop()

# --- Escape / pause menu --------------------------------------------------

func _on_resume_button_pressed() -> void:
	_set_state(UIState.PLAYING)

func _on_pause_levels_button_pressed() -> void:
	_set_state(UIState.LEVEL_SELECT)

func _on_pause_main_menu_button_pressed() -> void:
	_set_state(UIState.TITLE)

func _on_pause_quit_button_pressed() -> void:
	get_tree().quit()

# --- Inventory & Hotbar ---

var inventory_visible: bool = false

func _select_hotbar_slot(slot: int) -> void:
	if not player:
		return
	if slot < 1 or slot > 3:
		return
	if player.inventory.size() < slot:
		return
	player.activeWeaponIndex = slot - 1
	_update_hotbar_selection(slot)

func _toggle_inventory() -> void:
	if current_state != UIState.PLAYING:
		return
	inventory_visible = !inventory_visible
	if has_node("HUD/inventoryPanel"):
		$HUD/inventoryPanel.visible = inventory_visible

func _update_hotbar_selection(slot: int) -> void:
	# Update hotbar slot highlighting
	if has_node("HUD/hotbarContainer/slot1"):
		var slot1 = $HUD/hotbarContainer/slot1
		var slot2 = $HUD/hotbarContainer/slot2
		var slot3 = $HUD/hotbarContainer/slot3

		slot1.texture_normal = preload("res://assets/UI/player/unselectedHotbarBox.png")
		slot2.texture_normal = preload("res://assets/UI/player/unselectedHotbarBox.png")
		slot3.texture_normal = preload("res://assets/UI/player/unselectedHotbarBox.png")

		match slot:
			1:
				slot1.texture_normal = preload("res://assets/UI/player/selectedHotbarBox.png")
			2:
				slot2.texture_normal = preload("res://assets/UI/player/selectedHotbarBox.png")
			3:
				slot3.texture_normal = preload("res://assets/UI/player/selectedHotbarBox.png")
