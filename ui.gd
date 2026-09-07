extends CanvasLayer

enum UIState { TITLE, PLAYING, PAUSED, SETTINGS }

var current_state: UIState = UIState.TITLE
var state_before_settings: UIState = UIState.TITLE

@onready var title_screen: Control = $titleScreen
@onready var settings_menu: Control = $settingsMenu
@onready var pause_menu: Control = $pauseMenu
@onready var hud: Control = $HUD

@onready var hud_compendium_label: Label = $HUD/compendiumDataDisplay/compendiumLabel

# --- COOLDOWN & SLOT REFERENCES (Added to fix the "not declared" error) ---
@onready var slot1: TextureButton = $HUD/hotbarContainer/slot1
@onready var slot2: TextureButton = $HUD/hotbarContainer/slot2
@onready var slot3: TextureButton = $HUD/hotbarContainer/slot3

# References relative to this UI node
@onready var player: CharacterBody2D = $"../World/player"
@onready var world: Node2D = $"../World"

# --- Inventory Panel References ---
@onready var inventory_panel: Control = $HUD/inventoryPanel
var inventory_visible: bool = false

@onready var robot_inventory_panel: Control = $HUD/robotInventoryPanel
var robot_inventory_visible: bool = false

func _ready() -> void:
	add_to_group("ui_controller")
	GameData.compendium_data_changed.connect(_on_compendium_data_changed)
	_update_compendium_label(GameData.compendium_data)
	_set_state(UIState.TITLE)
	
	# Highlight slot 1 on startup
	_update_hotbar_selection(1)
	
	# --- FOOLPROOF CODE SIGNAL CONNECTIONS ---
	# Connects mouse clicks automatically, bypassing any editor connection mistakes
	if slot1: slot1.pressed.connect(_on_slot1_pressed)
	if slot2: slot2.pressed.connect(_on_slot2_pressed)
	if slot3: slot3.pressed.connect(_on_slot3_pressed)
	
	# --- AUTOMATIC CONTAINER SIZE DIAGNOSTIC ---
	# If your container has collapsed to (0, 0), this will print a warning in your console.
	var hotbarContainer = $HUD/hotbarContainer
	if hotbarContainer and hotbarContainer.size == Vector2.ZERO:
		print("\n--- DIAGNOSTIC WARNING ---")
		print("Your 'hotbarContainer' size has collapsed to (0, 0) at runtime!")
		print("In Godot, a parent container with a size of (0, 0) cannot route mouse clicks to its children.")
		print("To fix this:")
		print("1. Select 'hotbarContainer' in the editor.")
		print("2. Go to the Inspector -> Control -> Layout -> Transform -> Size.")
		print("3. Set a minimum size (e.g., Width: 150, Height: 50) so the container covers the buttons.")
		print("--------------------------\n")

func _on_compendium_data_changed(new_amount: int) -> void:
	_update_compendium_label(new_amount)

func _update_compendium_label(amount: int) -> void:
	if hud_compendium_label:
		hud_compendium_label.text = "Compendium Data: %d" % amount

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
		if keycode == KEY_R:
			_toggle_robot_inventory()
			get_viewport().set_input_as_handled()
			return

	if not event.is_action_pressed("ui_cancel"):
		return

	# Close inventories if they're open
	if inventory_visible:
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	
	if robot_inventory_visible:
		_toggle_robot_inventory()
		get_viewport().set_input_as_handled()
		return

	match current_state:
		UIState.PLAYING:
			_set_state(UIState.PAUSED)
		UIState.PAUSED:
			_set_state(UIState.PLAYING)
		UIState.SETTINGS:
			_close_settings()
		_:
			return
	get_viewport().set_input_as_handled()

# --- Central state switcher ---
func _set_state(new_state: UIState) -> void:
	current_state = new_state

	title_screen.hide()
	pause_menu.hide()
	settings_menu.hide()
	hud.hide()
	get_tree().paused = false

	match new_state:
		UIState.TITLE:
			title_screen.show()
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

# --- Title screen ---

func _on_play_button_pressed() -> void:
	world.teleport_player_to_pond()
	_set_state(UIState.PLAYING)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# --- Settings ---

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

# --- Escape / pause menu ---

func _on_resume_button_pressed() -> void:
	_close_settings()
	_set_state(UIState.PLAYING)
	
func _on_close_settings_button_pressed() -> void:
	print("BUTTON PRESSED")
	_close_settings()
	_set_state(UIState.PLAYING)

func _on_pause_main_menu_button_pressed() -> void:
	_set_state(UIState.TITLE)

func _on_pause_quit_button_pressed() -> void:
	get_tree().quit()

# --- Inventory & Hotbar ---

func _toggle_inventory() -> void:
	if current_state != UIState.PLAYING:
		return
	# Inventory can be viewed early, but installation of upgrades is blocked by
	# GameData until the robot is assigned by the scientist.
	if not inventory_visible and robot_inventory_visible:
		robot_inventory_visible = false
		robot_inventory_panel.hide()
	inventory_visible = !inventory_visible
	if inventory_panel:
		inventory_panel.visible = inventory_visible

func _on_inventory_button_pressed() -> void:
	_toggle_inventory()


func _toggle_robot_inventory() -> void:
	if current_state != UIState.PLAYING:
		return
	# Only allow opening if the player has actually unlocked the robot
	if not player or not player.hasRobotCompanion:
		return
	if not robot_inventory_visible and inventory_visible:
		inventory_visible = false
		inventory_panel.hide()
	robot_inventory_visible = !robot_inventory_visible
	if robot_inventory_panel:
		robot_inventory_panel.visible = robot_inventory_visible

func _select_hotbar_slot(slot: int) -> void:
	if not player:
		return
	if slot < 1 or slot > 3:
		return
	if player.inventory.size() < slot:
		return
	player.activeSlotIndex = slot - 1
	_update_hotbar_selection(slot)

func _update_hotbar_selection(slot: int) -> void:
	if not slot1 or not slot2 or not slot3:
		return

	var unselectedTex = preload("res://assets/UI/player/unselectedHotbarBox.png")
	var selectedTex = preload("res://assets/UI/player/selectedHotbarBox.png")

	slot1.texture_normal = unselectedTex
	slot2.texture_normal = unselectedTex
	slot3.texture_normal = unselectedTex

	match slot:
		1:
			slot1.texture_normal = selectedTex
		2:
			slot2.texture_normal = selectedTex
		3:
			slot3.texture_normal = selectedTex

# --- Interactive HUD Buttons ---

func _on_hud_pause_button_pressed() -> void:
	if current_state == UIState.PLAYING:
		_set_state(UIState.PAUSED)

# --- MOUSE CLICK SIGNALS FOR HOTBAR SLOTS ---

func _on_slot1_pressed() -> void:
	print("Slot 1 physically clicked!")
	_select_hotbar_slot(1)

func _on_slot2_pressed() -> void:
	_select_hotbar_slot(2)

func _on_slot3_pressed() -> void:
	_select_hotbar_slot(3)
