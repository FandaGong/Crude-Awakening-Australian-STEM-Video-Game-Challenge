extends CanvasLayer

enum UIState { TITLE, PLAYING, PAUSED, SETTINGS }

var current_state: UIState = UIState.TITLE
var state_before_settings: UIState = UIState.TITLE

@onready var title_screen: Control = $titleScreen
@onready var settings_menu: Control = $settingsMenu
@onready var pause_menu: Control = $pauseMenu
@onready var hud: Control = $HUD
@onready var settings_panel: Panel = $settingsMenu/Panel
@onready var music_toggle: CheckButton = $settingsMenu/Panel/bgmButton
@onready var sfx_toggle: CheckButton = $settingsMenu/Panel/soundEffectsButton
@onready var effects_toggle: CheckButton = $settingsMenu/Panel/particlesButton
@onready var close_settings_button: TextureButton = $settingsMenu/Panel/closeSettingsButton
@onready var master_volume_slider: HSlider = $settingsMenu/Panel/masterVolumeSlider
@onready var music_volume_slider: HSlider = $settingsMenu/Panel/musicVolumeSlider
@onready var sfx_volume_slider: HSlider = $settingsMenu/Panel/sfxVolumeSlider

@onready var hud_compendium_label: Label = $HUD/compendiumDataDisplay/compendiumLabel
@onready var hud_details_panel: Panel = $HUD/DetailsPanel
@onready var hud_item_name_label: Label = $HUD/DetailsPanel/SkillNameLabel
@onready var hud_item_desc_label: Label = $HUD/DetailsPanel/DescriptionLabel

# --- COOLDOWN & SLOT REFERENCES (Added to fix the "not declared" error) ---
@onready var slot1: TextureButton = $HUD/hotbarContainer/TextureButton
@onready var slot2: TextureButton = $HUD/hotbarContainer/TextureButton2
@onready var slot3: TextureButton = $HUD/hotbarContainer/TextureButton3

# References relative to this UI node
@onready var player: CharacterBody2D = $"../World/player"
@onready var world: Node2D = $"../World"

# --- Inventory Panel References ---
@onready var inventory_panel: Control = $HUD/inventoryPanel
var inventory_visible: bool = false

@onready var robot_inventory_button: TextureButton = $HUD/robotInventoryButton
@onready var robot_inventory_panel: Control = $HUD/robotInventoryPanel
var robot_inventory_visible: bool = false

func _ready() -> void:
	add_to_group("ui_controller")
	GameData.compendium_data_changed.connect(_on_compendium_data_changed)
	GameData.robot_unlocked_changed.connect(_on_robot_unlocked_changed)
	_update_compendium_label(GameData.compendium_data)
	_update_robot_inventory_button(GameData.is_robot_unlocked)
	_set_state(UIState.TITLE)
	_setup_settings_controls()
	_build_settings_tabs()
	
	# Highlight slot 1 on startup
	_update_hotbar_selection(1)
	
	# --- FOOLPROOF CODE SIGNAL CONNECTIONS ---
	# Connects mouse clicks automatically, bypassing any editor connection mistakes
	if slot1: slot1.pressed.connect(_on_slot1_pressed)
	if slot2: slot2.pressed.connect(_on_slot2_pressed)
	if slot3: slot3.pressed.connect(_on_slot3_pressed)
	for hotbar_slot in [slot1, slot2, slot3]:
		if hotbar_slot:
			hotbar_slot.mouse_entered.connect(_on_hotbar_hover_entered.bind(hotbar_slot))
			hotbar_slot.mouse_exited.connect(_on_hotbar_hover_exited)
	if hud_details_panel:
		hud_details_panel.hide()
	if robot_inventory_button:
		robot_inventory_button.pressed.connect(_on_robot_inventory_button_pressed)
	_connect_button_sounds()
	

func _setup_settings_controls() -> void:
	_configure_toggle(music_toggle, "Music", AudioManager.music_enabled, _on_music_toggled)
	_configure_toggle(sfx_toggle, "Sound effects", AudioManager.sfx_enabled, _on_sfx_toggled)
	_configure_toggle(effects_toggle, "Bubble trails", Effects.effects_enabled, _on_effects_toggled)
	$settingsMenu/Panel/reduceMotionButton.hide()
	$settingsMenu/Panel/colorblindButton.hide()
	close_settings_button.tooltip_text = "Return to the previous menu"
	_configure_volume_slider(master_volume_slider, AudioManager.master_volume, _on_master_volume_changed)
	_configure_volume_slider(music_volume_slider, AudioManager.music_volume, _on_music_volume_changed)
	_configure_volume_slider(sfx_volume_slider, AudioManager.sfx_volume, _on_sfx_volume_changed)

func _build_settings_tabs() -> void:
	var tabs := Control.new()
	tabs.name = "SettingsTabs"
	tabs.position = Vector2(20.0, 56.0)
	tabs.size = Vector2(340.0, 224.0)
	settings_panel.add_child(tabs)

	var audio := Control.new()
	audio.name = "Audio"
	audio.position = Vector2(0.0, 30.0)
	var graphics := Control.new()
	graphics.name = "Graphics"
	graphics.position = Vector2(0.0, 30.0)
	tabs.add_child(graphics)
	tabs.add_child(audio)

	var graphics_button := _make_tab_button("Graphics", Vector2(42.0, 0.0))
	var audio_button := _make_tab_button("Audio", Vector2(198.0, 0.0))
	var underline := ColorRect.new()
	underline.color = Color.WHITE
	underline.position = Vector2(graphics_button.position.x, 24.0)
	underline.size = Vector2(graphics_button.size.x, 2.0)
	tabs.add_child(graphics_button)
	tabs.add_child(audio_button)
	tabs.add_child(underline)
	graphics_button.pressed.connect(_select_settings_tab.bind(graphics, audio, underline, graphics_button))
	audio_button.pressed.connect(_select_settings_tab.bind(audio, graphics, underline, audio_button))
	_select_settings_tab(graphics, audio, underline, graphics_button)

	$settingsMenu/Panel/soundLabel.hide()
	$settingsMenu/Panel/graphicsLabel.hide()
	_move_to_tab(music_toggle, audio, Vector2(20.0, 20.0))
	_move_to_tab(sfx_toggle, audio, Vector2(20.0, 48.0))
	_move_to_tab(master_volume_slider, audio, Vector2(130.0, 92.0))
	_move_to_tab(music_volume_slider, audio, Vector2(130.0, 126.0))
	_move_to_tab(sfx_volume_slider, audio, Vector2(130.0, 160.0))
	_move_to_tab($settingsMenu/Panel/masterVolumeLabel, audio, Vector2(20.0, 92.0))
	_move_to_tab($settingsMenu/Panel/musicVolumeLabel, audio, Vector2(20.0, 126.0))
	_move_to_tab($settingsMenu/Panel/sfxVolumeLabel, audio, Vector2(20.0, 160.0))
	_move_to_tab(effects_toggle, graphics, Vector2(20.0, 20.0))

func _make_tab_button(label: String, tab_position: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.flat = true
	button.position = tab_position
	button.size = Vector2(100.0, 24.0)
	button.add_theme_font_size_override("font_size", 8)
	return button

func _select_settings_tab(active_page: Control, inactive_page: Control, underline: ColorRect, button: Button) -> void:
	active_page.show()
	inactive_page.hide()
	underline.position.x = button.position.x
	underline.size.x = button.size.x

func _move_to_tab(control: Control, tab: Control, tab_position: Vector2) -> void:
	control.reparent(tab)
	control.position = tab_position

func _configure_toggle(toggle: CheckButton, label: String, enabled: bool, callback: Callable) -> void:
	toggle.text = label
	toggle.add_theme_font_size_override("font_size", 8)
	toggle.button_pressed = enabled
	toggle.toggled.connect(callback)
	for child in toggle.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			child.hide()

func _configure_volume_slider(slider: HSlider, value: float, callback: Callable) -> void:
	slider.value = value
	slider.value_changed.connect(callback)

func _connect_button_sounds() -> void:
	for node in find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if not button:
			continue
		if not button.pressed.is_connected(_play_button_sound):
			button.pressed.connect(_play_button_sound)

func _play_button_sound() -> void:
	AudioManager.play_sfx("button_click")

func _on_music_toggled(enabled: bool) -> void:
	AudioManager.set_music_enabled(enabled)

func _on_sfx_toggled(enabled: bool) -> void:
	AudioManager.set_sfx_enabled(enabled)

func _on_effects_toggled(enabled: bool) -> void:
	Effects.set_effects_enabled(enabled)

func _on_master_volume_changed(value: float) -> void:
	AudioManager.set_master_volume(value)

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)

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
		UIState.SETTINGS:
			settings_menu.show()
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
	_set_state(UIState.SETTINGS)

func _on_close_button_pressed() -> void:
	_close_settings()

func _close_settings() -> void:
	settings_menu.hide()
	_set_state(state_before_settings)

# --- Escape / pause menu ---

func _on_resume_button_pressed() -> void:
	_set_state(UIState.PLAYING)
	
func _on_close_settings_button_pressed() -> void:
	_close_settings()

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

func _on_robot_inventory_button_pressed() -> void:
	_toggle_robot_inventory()

func _on_robot_unlocked_changed(unlocked: bool) -> void:
	_update_robot_inventory_button(unlocked)

func _update_robot_inventory_button(unlocked: bool) -> void:
	if robot_inventory_button:
		robot_inventory_button.visible = unlocked
	if not unlocked and robot_inventory_visible:
		robot_inventory_visible = false
		if robot_inventory_panel:
			robot_inventory_panel.hide()


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
		_close_open_inventories()
		_set_state(UIState.PAUSED)

func _close_open_inventories() -> void:
	inventory_visible = false
	robot_inventory_visible = false
	if inventory_panel:
		inventory_panel.hide()
	if robot_inventory_panel:
		robot_inventory_panel.hide()

# --- MOUSE CLICK SIGNALS FOR HOTBAR SLOTS ---

func _on_slot1_pressed() -> void:
	print("Slot 1 physically clicked!")
	_select_hotbar_slot(1)

func _on_slot2_pressed() -> void:
	_select_hotbar_slot(2)

func _on_slot3_pressed() -> void:
	_select_hotbar_slot(3)

func _on_hotbar_hover_entered(hotbar_slot: TextureButton) -> void:
	var index := [slot1, slot2, slot3].find(hotbar_slot)
	if index < 0 or index >= GameData.active_abilities.size():
		return
	var item_id: String = GameData.active_abilities[index]
	var item_path := "res://resources/items/%s.tres" % item_id
	if item_id == "" or not ResourceLoader.exists(item_path):
		return
	var item: ItemData = load(item_path)
	hud_item_name_label.text = item.name
	hud_item_desc_label.text = item.description
	hud_details_panel.global_position = get_viewport().get_mouse_position() + Vector2(10, 10)
	hud_details_panel.show()

func _on_hotbar_hover_exited() -> void:
	if hud_details_panel:
		hud_details_panel.hide()
