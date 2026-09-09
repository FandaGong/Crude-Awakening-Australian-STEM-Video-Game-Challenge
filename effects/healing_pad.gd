extends Area2D

@export var healing_per_second := 18.0

var player: CharacterBody2D

func _ready() -> void:
	add_to_group("healing_pads")

func _physics_process(delta: float) -> void:
	if player and is_instance_valid(player) and player.has_method("heal"):
		player.heal(healing_per_second * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
