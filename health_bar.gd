extends TextureProgressBar

@export var player: CharacterBody2D

@onready var health_label: Label = $healthLabel

func _ready() -> void:
	if player:
		max_value = player.maxHealth

func _process(_delta: float) -> void:
	if player:
		value = player.currentHealth
		if health_label:
			health_label.text = "%d / %d" % [int(round(player.currentHealth)), int(round(player.maxHealth))]
