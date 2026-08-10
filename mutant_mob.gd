extends CharacterBody2D

@export var baseHealth: float = 30.0
@export var baseSpeed: float = 50.0

var currentHealth: float
var isCured: bool = false

func _ready() -> void:
	# Calculate difficulty based on depth (Y position) in the world
	var depthScale = global_position.y / 1000.0
	currentHealth = baseHealth + (depthScale * 10.0) # More health deeper down
	velocity.x = -baseSpeed - (depthScale * 5.0)     # Faster deeper down

func _physics_process(_delta: float) -> void:
	if not isCured:
		move_and_slide() # Mobs swim forward

func applyCure(amount: float) -> void:
	if isCured: return
	currentHealth -= amount
	if currentHealth <= 0:
		cureMob()

func cureMob() -> void:
	isCured = true
	# Trigger a visual "pop" particle explosion here
	queue_free()
