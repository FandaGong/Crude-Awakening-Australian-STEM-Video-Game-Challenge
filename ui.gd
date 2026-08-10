extends CanvasLayer

@onready var title_screen: Control = $titleScreen
@onready var settings_menu: Control = $settingsMenu
@onready var hud: Control = $HUD

# References the Player node relative to this UI node
@onready var player: CharacterBody2D = $"../World/player"
# Add these at the top of ui.gd
@onready var healthBar: TextureProgressBar = $HUD/healthBar
@onready var airBar: TextureProgressBar = $HUD/airBar

func _process(_delta: float) -> void:
	if player and hud.visible:
		# Update progress bar values based on player stats
		healthBar.value = player.currentHealth
		airBar.value = player.currentAir
		
		
func _ready() -> void:
	# Show the title screen, hide gameplay elements
	title_screen.show()
	hud.hide()
	settings_menu.hide()
	
	# Disable the player completely so they don't fall or move behind the menu
	player.hide()
	player.set_physics_process(false)
	player.set_process(false)

func _on_play_button_pressed() -> void:
	title_screen.hide()
	hud.show()
	
	# Turn the player's physics and visual model back on
	player.show()
	player.set_physics_process(true)
	player.set_process(true)
	
	print("Play button clicked! Player physics active: ", player.is_physics_processing())

func _on_settings_button_pressed() -> void:
	settings_menu.show()
	# Pause only gameplay physics when settings is open
	get_tree().paused = true

func _on_close_button_pressed() -> void:
	settings_menu.hide()
	get_tree().paused = false

func _on_quit_button_pressed() -> void:
	get_tree().quit()
