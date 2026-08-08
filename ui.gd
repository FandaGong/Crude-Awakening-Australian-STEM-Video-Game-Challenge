extends CanvasLayer

@onready var title_screen: Control = $titleScreen
@onready var settings_menu: Control = $settingsMenu
@onready var hud: Control = $HUD

func _ready() -> void:
	# Show title screen, hide gameplay HUD and Settings at startup
	title_screen.show()
	hud.hide()
	settings_menu.hide()

# --- BUTTON SIGNALS ---

func _on_play_button_pressed() -> void:
	title_screen.hide()
	hud.show()
	# Here you can also trigger spawning the player or loading the pond scene
	start_game()

func _on_settings_button_pressed() -> void:
	settings_menu.show()
	# If you are in-game, you can pause the engine while settings are open
	if not title_screen.visible:
		get_tree().paused = true

func _on_close_button_pressed() -> void:
	settings_menu.hide()
	# Resume the game when closing settings
	get_tree().paused = false

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func start_game() -> void:
	# Add any gameplay initialization here, like unpausing or activating player physics
	print("Game started!")
