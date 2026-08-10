extends CharacterBody2D

enum State { LAND, SWIMMING }
var currentState = State.LAND

# --- PLAYER STATS ---
@export var maxHealth: float = 100.0
var currentHealth: float = maxHealth

@export var maxAir: float = 100.0 # Oxygen capacity
var currentAir: float = maxAir

@export var drownDamageRate: float = 10.0 # Damage per second when drowning
@export var airRecoveryRate: float = 50.0 # How fast oxygen recovers on land

# --- INVENTORY & HOTBAR ---
var inventory: Array[String] = ["Potion"] # Starts with the curing potion
var activeWeaponIndex: int = 0

# --- MOVEMENT SPEED ---
@export var walkSpeed = 300.0
@export var swimSpeed = 400.0
@export var gravity = 980.0
@export var jumpVelocity = -200.0

@onready var sprite = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	match currentState:
		State.LAND:
			handleLandMovement(delta)
			recoverAir(delta)
		State.SWIMMING:
			handleSwimmingMovement(delta)
			depleteAir(delta)
			
	# Switch active weapons using 1, 2, 3 keys
	handleHotbarInput()
	move_and_slide()

func handleLandMovement(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		
	if Input.is_action_just_pressed("move_up") and is_on_floor():
		velocity.y = jumpVelocity
		
	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * walkSpeed
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, walkSpeed)

func handleSwimmingMovement(_delta: float) -> void:
	var inputVector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = inputVector * swimSpeed
	
	if inputVector.y == 0:
		var sinkRate = 45.0
		velocity.y = sinkRate
	
	if Input.is_action_just_pressed("move_up"):
		velocity.y = jumpVelocity
	
	if inputVector.x != 0:
		sprite.flip_h = inputVector.x < 0

# --- STAT FUNCTIONS ---

func depleteAir(delta: float) -> void:
	if currentAir > 0:
		currentAir -= 10.0 * delta # Depletes over 10 seconds
	else:
		# Drown: Take damage over time
		currentHealth -= drownDamageRate * delta
		currentHealth = max(0.0, currentHealth)

func recoverAir(delta: float) -> void:
	if currentAir < maxAir:
		currentAir += airRecoveryRate * delta
		currentAir = min(maxAir, currentAir)

func handleHotbarInput() -> void:
	if Input.is_action_just_pressed("hotbar_1") and inventory.size() > 0:
		activeWeaponIndex = 0
	elif Input.is_action_just_pressed("hotbar_2") and inventory.size() > 1:
		activeWeaponIndex = 1
	elif Input.is_action_just_pressed("hotbar_3") and inventory.size() > 2:
		activeWeaponIndex = 2


# --- restored SIGNAL RECEIVERS ---

func _on_water_area_body_entered(body: Node2D) -> void:
	if body == self:
		currentState = State.SWIMMING
		# Slowly damp falling speed upon hitting the water instead of stopping instantly
		velocity.y = clamp(velocity.y, -swimSpeed, swimSpeed)


func _on_water_area_body_exited(body: Node2D) -> void:
	if body == self:
		currentState = State.LAND
