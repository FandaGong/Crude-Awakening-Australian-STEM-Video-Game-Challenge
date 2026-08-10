extends TextureProgressBar

@export var player: CharacterBody2D

func _ready() -> void:
	if player:
		max_value = player.maxHealth

func _process(_delta: float) -> void:
	if player:
		value = player.currentHealth
