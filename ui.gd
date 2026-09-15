extends CanvasLayer

enum UIState { TITLE, PLAYING, PAUSED, SETTINGS }

var current_state: UIState = UIState.TITLE
var state_before_settings: UIState = UIState.TITLE

@export_category("Screens")
@export var title_screen_path: NodePath = ^"titleScreen"
@export var settings_menu_path: NodePath = ^"settingsMenu"
@export var pause_menu_path: NodePath = ^"pauseMenu"
@export var hud_path: NodePath = ^"HUD"

@export_category("Settings Menu")
@export var settings_panel_path: NodePath = ^"settingsMenu/Panel"
@export var music_toggle_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/Audio/bgmButton"
@export var sfx_toggle_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/Audio/soundEffectsButton"
@export var effects_toggle_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/Graphics/particlesButton"
@export var close_settings_button_path: NodePath = ^"settingsMenu/Panel/closeSettingsButton"
@export var master_volume_slider_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/Audio/masterVolumeSlider"
@export var music_volume_slider_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/Audio/musicVolumeSlider"
@export var sfx_volume_slider_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/Audio/sfxVolumeSlider"
@export var graphics_tab_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/Graphics"
@export var audio_tab_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/Audio"
@export var graphics_tab_button_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/GraphicsTabButton"
@export var audio_tab_button_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/AudioTabButton"
@export var tab_underline_path: NodePath = ^"settingsMenu/Panel/SettingsTabs/TabUnderline"
## Controls hidden because the feature behind them isn't finished yet.
@export var unfinished_settings_controls: Array[NodePath] = [
	^"settingsMenu/Panel/reduceMotionButton",
	^"settingsMenu/Panel/colorblindButton",
]
@export var music_toggle_label: String = "Music"
@export var sfx_toggle_label: String = "Sound effects"
@export var effects_toggle_label: String = "Bubble trails"
@export var toggle_font_size: int = 8
@export var close_settings_tooltip: String = "Return to the previous menu"

@export_category("HUD")
@export var hud_compendium_label_path: NodePath = ^"HUD/compendiumDataDisplay/compendiumLabel"
@export var hud_details_panel_path: NodePath = ^"HUD/DetailsPanel"
@export var hud_item_name_label_path: NodePath = ^"HUD/DetailsPanel/SkillNameLabel"
@export var hud_item_desc_label_path: NodePath = ^"HUD/DetailsPanel/DescriptionLabel"
@export var active_effects_panel_path: NodePath = ^"HUD/activeEffects"
@export var active_effects_label_path: NodePath = ^"HUD/activeEffects/DescriptionLabel"
@export var compendium_label_format: String = "Compendium Data: %d"

@export_category("Active Effects Layout")
@export var active_effects_width: float = 134.0
@export var active_effects_padding: float = 6.0

@export_category("Active Effects Text")
@export var bubble_booster_text: String = "Bubble Booster: +30% cure speed (%s)"
@export var respawn_shield_text: String = "Respawn Shield: immune (%s)"
@export var carapace_guard_text: String = "Carapace Guard: 50% damage reduction (%s)"
@export var guardian_relay_text: String = "Guardian Relay: 15% damage reduction (%s)"
@export var drowning_text: String = "Drowning: taking damage"
@export var overheat_text: String = "Overheat: +30% cure speed (%s)"

@export_category("Hotbar")
@export var hotbar_slots: Array[TextureButton] = []
@export var hotbar_slot_paths: Array[NodePath] = [
	^"HUD/hotbarContainer/TextureButton",
	^"HUD/hotbarContainer/TextureButton2",
	^"HUD/hotbarContainer/TextureButton3",
]
@export var hotbar_highlight_paths: Array[NodePath] = [
	^"HUD/hotbarContainer/TextureButton/SelectionHighlight",
	^"HUD/hotbarContainer/TextureButton2/SelectionHighlight",
	^"HUD/hotbarContainer/TextureButton3/SelectionHighlight",
]
@export var unselected_hotbar_texture: Texture2D = preload("res://assets/UI/player/unselectedHotbarBox.png")
@export var selected_hotbar_texture: Texture2D = preload("res://assets/UI/player/selectedHotbarBox.png")
@export_global_dir var item_resource_dir: String = "res://resources/items/"

@export_category("Inventory")
@export var inventory_panel_path: NodePath = ^"HUD/inventoryPanel"
@export var robot_inventory_button_path: NodePath = ^"HUD/robotInventoryButton"
@export var robot_inventory_panel_path: NodePath = ^"HUD/robotInventoryPanel"

@export_category("World References")
@export var player_path: NodePath = ^"../World/player"
@export var world_path: NodePath = ^"../World"
@export var companion_robot_node_name: String = "CompanionRobot"

@export_category("Input")
@export var hotbar_select_actions: Array[StringName] = [&"hotbar_1", &"hotbar_2", &"hotbar_3"]
@export var inventory_toggle_action: StringName = &"inventory"
@export var robot_inventory_toggle_action: StringName = &"robotInventory"
@export var button_click_sfx: StringName = &"button_click"

@onready var title_screen: Control = get_node_or_null(title_screen_path) as Control
@onready var settings_menu: Control = get_node_or_null(settings_menu_path) as Control
@onready var pause_menu: Control = get_node_or_null(pause_menu_path) as Control
@onready var hud: Control = get_node_or_null(hud_path) as Control
@onready var settings_panel: Panel = get_node_or_null(settings_panel_path) as Panel
@onready var music_toggle: CheckButton = get_node_or_null(music_toggle_path) as CheckButton
@onready var sfx_toggle: CheckButton = get_node_or_null(sfx_toggle_path) as CheckButton
@onready var effects_toggle: CheckButton = get_node_or_null(effects_toggle_path) as CheckButton
@onready var close_settings_button: TextureButton = get_node_or_null(close_settings_button_path) as TextureButton
@onready var master_volume_slider: HSlider = get_node_or_null(master_volume_slider_path) as HSlider
@onready var music_volume_slider: HSlider = get_node_or_null(music_volume_slider_path) as HSlider
@onready var sfx_volume_slider: HSlider = get_node_or_null(sfx_volume_slider_path) as HSlider
@onready var graphics_tab: Control = get_node_or_null(graphics_tab_path) as Control
@onready var audio_tab: Control = get_node_or_null(audio_tab_path) as Control
@onready var graphics_tab_button: Button = get_node_or_null(graphics_tab_button_path) as Button
@onready var audio_tab_button: Button = get_node_or_null(audio_tab_button_path) as Button
@onready var tab_underline: ColorRect = get_node_or_null(tab_underline_path) as ColorRect

@onready var hud_compendium_label: Label = get_node_or_null(hud_compendium_label_path) as Label
@onready var hud_details_panel: Panel = get_node_or_null(hud_details_panel_path) as Panel
@onready var hud_item_name_label: Label = get_node_or_null(hud_item_name_label_path) as Label
@onready var hud_item_desc_label: Label = get_node_or_null(hud_item_desc_label_path) as Label
@onready var active_effects_panel: Panel = get_node_or_null(active_effects_panel_path) as Panel
@onready var active_effects_label: Label = get_node_or_null(active_effects_label_path) as Label

@onready var player: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D
@onready var world: Node2D = get_node_or_null(world_path) as Node2D

@onready var inventory_panel: Control = get_node_or_null(inventory_panel_path) as Control
@onready var robot_inventory_button: TextureButton = get_node_or_null(robot_inventory_button_path) as TextureButton
@onready var robot_inventory_panel: Control = get_node_or_null(robot_inventory_panel_path) as Control

var inventory_visible: bool = false
var robot_inventory_visible: bool = false
var _active_effects_text := ""
var _hotbar_highlights: Array[Control] = []

func _ready() -> void:
	add_to_group("ui_controller")
	GameData.compendium_data_changed.connect(_on_compendium_data_changed)
	GameData.robot_unlocked_changed.connect(_on_robot_unlocked_changed)
	_update_compendium_label(GameData.compendium_data)
	_update_robot_inventory_button(GameData.is_robot_unlocked)
	_set_state(UIState.TITLE)
	_setup_settings_controls()
	_show_settings_tab(graphics_tab, audio_tab, graphics_tab_button)

	_load_hotbar_controls()
	_update_hotbar_selection(1)
	_connect_hotbar_signals()

	if hud_details_panel:
		hud_details_panel.hide()
	if active_effects_panel:
		active_effects_panel.hide()
	_connect_button_sounds()

func _connect_hotbar_signals() -> void:
	for i in hotbar_slots.size():
		var hotbar_slot := hotbar_slots[i]
		if not hotbar_slot:
			continue
		hotbar_slot.pressed.connect(_select_hotbar_slot.bind(i + 1))
		hotbar_slot.mouse_entered.connect(_on_hotbar_hover_entered.bind(hotbar_slot))
		hotbar_slot.mouse_exited.connect(_on_hotbar_hover_exited)

func _load_hotbar_controls() -> void:
	if hotbar_slots.is_empty():
		for path in hotbar_slot_paths:
			var hotbar_slot := get_node_or_null(path) as TextureButton
			if hotbar_slot:
				hotbar_slots.append(hotbar_slot)
	for path in hotbar_highlight_paths:
		var highlight := get_node_or_null(path) as Control
		if highlight:
			_hotbar_highlights.append(highlight)

func _process(_delta: float) -> void:
	_update_active_effects_hud()

# Active effects
func _update_active_effects_hud() -> void:
	if not active_effects_panel or not active_effects_label or not player:
		return
	var effects: Array[String] = []
	if GameData.bubble_booster_timer > 0.0:
		effects.append(bubble_booster_text % _format_effect_time(GameData.bubble_booster_timer))
	if player.respawn_immunity > 0.0:
		effects.append(respawn_shield_text % _format_effect_time(player.respawn_immunity))
	if player.carapace_active_timer > 0.0:
		effects.append(carapace_guard_text % _format_effect_time(player.carapace_active_timer))
	if player.physical_skill_timer > 0.0:
		effects.append(guardian_relay_text % _format_effect_time(player.physical_skill_timer))
	if player.currentState == player.State.SWIMMING and player.currentAir <= 0.0:
		effects.append(drowning_text)

	var robot := world.get_node_or_null(companion_robot_node_name) if world else null
	if robot and bool(robot.get("is_overheated")) and float(robot.get("overheat_timer")) > 0.0:
		effects.append(overheat_text % _format_effect_time(float(robot.get("overheat_timer"))))

	var new_text := "\n".join(effects)
	if new_text == _active_effects_text:
		return
	_active_effects_text = new_text
	active_effects_panel.visible = not new_text.is_empty()
	if new_text.is_empty():
		return
	active_effects_label.text = new_text
	active_effects_label.position = Vector2(active_effects_padding, active_effects_padding)
	active_effects_label.size.x = active_effects_width - active_effects_padding * 2.0
	active_effects_label.reset_size()
	call_deferred("_resize_active_effects_panel")

func _resize_active_effects_panel() -> void:
	if not active_effects_panel.visible:
		return
	var text_height := active_effects_label.get_combined_minimum_size().y
	active_effects_label.size = Vector2(
		active_effects_width - active_effects_padding * 2.0,
		text_height
	)
	active_effects_panel.size = Vector2(
		active_effects_width,
		text_height + active_effects_padding * 2.0
	)

func _format_effect_time(seconds: float) -> String:
	return "%ds" % maxi(1, ceili(seconds))

func _setup_settings_controls() -> void:
	_configure_toggle(music_toggle, music_toggle_label, AudioManager.music_enabled)
	_configure_toggle(sfx_toggle, sfx_toggle_label, AudioManager.sfx_enabled)
	_configure_toggle(effects_toggle, effects_toggle_label, Effects.effects_enabled)
	for control_path in unfinished_settings_controls:
		var control := get_node_or_null(control_path) as Control
		if control:
			control.hide()
	if close_settings_button:
		close_settings_button.tooltip_text = close_settings_tooltip
	_configure_volume_slider(master_volume_slider, AudioManager.master_volume)
	_configure_volume_slider(music_volume_slider, AudioManager.music_volume)
	_configure_volume_slider(sfx_volume_slider, AudioManager.sfx_volume)

func _show_settings_tab(active_page: Control, inactive_page: Control, button: Button) -> void:
	active_page.show()
	inactive_page.hide()
	tab_underline.position.x = button.position.x
	tab_underline.size.x = button.size.x

func _on_graphics_tab_button_pressed() -> void:
	_show_settings_tab(graphics_tab, audio_tab, graphics_tab_button)

func _on_audio_tab_button_pressed() -> void:
	_show_settings_tab(audio_tab, graphics_tab, audio_tab_button)

func _configure_toggle(toggle: CheckButton, label: String, enabled: bool) -> void:
	if not toggle:
		return
	toggle.text = label
	toggle.add_theme_font_size_override("font_size", toggle_font_size)
	toggle.button_pressed = enabled
	for child in toggle.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			child.hide()

func _configure_volume_slider(slider: HSlider, value: float) -> void:
	if slider:
		slider.value = value

func _connect_button_sounds() -> void:
	for node in find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button and not button.pressed.is_connected(_play_button_sound):
			button.pressed.connect(_play_button_sound)

func _play_button_sound() -> void:
	AudioManager.play_sfx(button_click_sfx)

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
		hud_compendium_label.text = compendium_label_format % amount

func _unhandled_input(event: InputEvent) -> void:
	for i in hotbar_select_actions.size():
		if event.is_action_pressed(hotbar_select_actions[i]):
			_select_hotbar_slot(i + 1)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(inventory_toggle_action):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(robot_inventory_toggle_action):
		_toggle_robot_inventory()
		get_viewport().set_input_as_handled()
		return

	if not event.is_action_pressed("ui_cancel"):
		return

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

# UI state
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

# Title screen

func _on_play_button_pressed() -> void:
	world.teleport_player_to_pond()
	_set_state(UIState.PLAYING)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# Settings

func _on_settings_button_pressed() -> void:
	state_before_settings = current_state
	_set_state(UIState.SETTINGS)

func _on_close_button_pressed() -> void:
	_close_settings()

func _close_settings() -> void:
	settings_menu.hide()
	_set_state(state_before_settings)

# Pause menu

func _on_resume_button_pressed() -> void:
	_set_state(UIState.PLAYING)

func _on_close_settings_button_pressed() -> void:
	_close_settings()

func _on_pause_main_menu_button_pressed() -> void:
	_set_state(UIState.TITLE)

func _on_pause_quit_button_pressed() -> void:
	get_tree().quit()

# Inventory and hotbar

func _toggle_inventory() -> void:
	if current_state != UIState.PLAYING:
		return
	if not inventory_visible and robot_inventory_visible:
		_close_robot_inventory()
	inventory_visible = not inventory_visible
	if inventory_panel:
		inventory_panel.visible = inventory_visible
	_update_inventory_pause()

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
		_close_robot_inventory()

func _toggle_robot_inventory() -> void:
	if current_state != UIState.PLAYING:
		return
	if not player or not player.hasRobotCompanion:
		return
	if not robot_inventory_visible and inventory_visible:
		_close_inventory()
	robot_inventory_visible = not robot_inventory_visible
	if robot_inventory_panel:
		robot_inventory_panel.visible = robot_inventory_visible
	_update_inventory_pause()

func _close_inventory() -> void:
	inventory_visible = false
	if inventory_panel:
		inventory_panel.hide()
	_update_inventory_pause()

func _close_robot_inventory() -> void:
	robot_inventory_visible = false
	if robot_inventory_panel:
		robot_inventory_panel.hide()
	_update_inventory_pause()

func _close_open_inventories() -> void:
	_close_inventory()
	_close_robot_inventory()

func _update_inventory_pause() -> void:
	if current_state != UIState.PLAYING:
		return
	get_tree().paused = inventory_visible or robot_inventory_visible

func _select_hotbar_slot(slot: int) -> void:
	if not player:
		return
	if slot < 1 or slot > hotbar_slots.size():
		return
	if player.inventory.size() < slot:
		return
	player.activeSlotIndex = slot - 1
	_update_hotbar_selection(slot)

func _update_hotbar_selection(slot: int) -> void:
	for i in hotbar_slots.size():
		var hotbar_slot := hotbar_slots[i]
		if hotbar_slot:
			hotbar_slot.texture_normal = selected_hotbar_texture if i == slot - 1 else unselected_hotbar_texture
		if i < _hotbar_highlights.size():
			_hotbar_highlights[i].visible = i == slot - 1

# HUD buttons

func _on_hud_pause_button_pressed() -> void:
	if current_state == UIState.PLAYING:
		_close_open_inventories()
		_set_state(UIState.PAUSED)

func _on_hotbar_hover_entered(hotbar_slot: TextureButton) -> void:
	var index := hotbar_slots.find(hotbar_slot)
	if index < 0 or index >= GameData.active_abilities.size():
		return
	var item_id: String = GameData.active_abilities[index]
	var item_path := "%s%s.tres" % [item_resource_dir, item_id]
	if item_id == "" or not ResourceLoader.exists(item_path):
		return
	var item: ItemData = load(item_path)
	hud_item_name_label.text = item.name
	hud_item_desc_label.text = item.description
	hud_details_panel.show()
	_position_hotbar_details_panel(get_viewport().get_mouse_position())

func _position_hotbar_details_panel(mouse_position: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := hud_details_panel.size
	var target := mouse_position + Vector2(10.0, -10.0 - panel_size.y)
	target.x = clamp(target.x, 0.0, maxf(0.0, viewport_size.x - panel_size.x))
	target.y = clamp(target.y, 0.0, maxf(0.0, viewport_size.y - panel_size.y))
	hud_details_panel.global_position = target

func _on_hotbar_hover_exited() -> void:
	if hud_details_panel:
		hud_details_panel.hide()
