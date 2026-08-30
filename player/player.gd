extends CharacterBody2D

signal died
signal respawned
signal weapon_fired(weapon_name: String)

enum State { LAND, SWIMMING }
var currentState = State.LAND

# --- PLAYER STATS ---
@export var maxHealth: float = 100.0
var currentHealth: float = maxHealth

@export var maxAir: float = 100.0 # Oxygen capacity
var currentAir: float = maxAir

@export var drownDamageRate: float = 10.0 # Damage per second when drowning
@export var airRecoveryRate: float = 50.0 # How fast oxygen recovers on land

var isDead: bool = false

# --- INVENTORY & HOTBAR ---
var inventory: Array[String] = ["Potion"] # Starts with the curing potion
var activeWeaponIndex: int = 0

# --- MOVEMENT SPEED ---
@export var walkSpeed = 300.0
@export var swimSpeed = 400.0
@export var gravity = 980.0
@export var jumpVelocity = -200.0
@export var acceleration = 2000.0 # How quickly the player reaches walkSpeed
@export var swimAcceleration = 900.0 # Smooths out swim direction changes

# --- JUMP FEEL ---
@export var coyoteTime = 0.12 # Grace period to jump after leaving a platform
@export var jumpBufferTime = 0.12 # Grace period so an early jump press still registers
var coyoteTimer = 0.0
var jumpBufferTimer = 0.0

@onready var sprite = $AnimatedSprite2D

const PlayerBulletScene := preload("res://bullets/player_bullet.tscn")
var shootCooldown: float = 0.0
var _weaponCache: Dictionary = {}

func _ready() -> void:
	add_to_group("player")
	GameData.weapon_equipped.connect(_on_weapon_equipped)

func _physics_process(delta: float) -> void:
	if isDead:
		velocity.x = move_toward(velocity.x, 0, walkSpeed * delta)
		move_and_slide()
		return

	# Don't process gameplay on titlescreen
	var ui = get_tree().root.get_node("Main/UI")
	if ui and ui.current_state == ui.UIState.TITLE:
		return

	_updateJumpTimers(delta)
	shootCooldown = max(0.0, shootCooldown - delta)

	match currentState:
		State.LAND:
			handleLandMovement(delta)
			recoverAir(delta)
		State.SWIMMING:
			handleSwimmingMovement(delta)
			depleteAir(delta)

	# Switch active weapons using 1, 2, 3 keys
	handleHotbarInput()
	handleShootInput()
	updateAnimation()
	move_and_slide()

func _updateJumpTimers(delta: float) -> void:
	# Coyote time: keep a short window after walking off a ledge where a jump still works
	if currentState == State.LAND and is_on_floor():
		coyoteTimer = coyoteTime
	else:
		coyoteTimer = max(0.0, coyoteTimer - delta)

	# Jump buffering: remember a jump press briefly so it isn't dropped if
	# it happens a few frames before the player actually lands
	if Input.is_action_just_pressed("move_up"):
		jumpBufferTimer = jumpBufferTime
	else:
		jumpBufferTimer = max(0.0, jumpBufferTimer - delta)

func handleLandMovement(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var wantsToJump = jumpBufferTimer > 0.0
	var canJump = is_on_floor() or coyoteTimer > 0.0
	if wantsToJump and canJump:
		velocity.y = jumpVelocity
		jumpBufferTimer = 0.0
		coyoteTimer = 0.0

	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * walkSpeed, acceleration * delta)
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)

func handleSwimmingMovement(delta: float) -> void:
	var inputVector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var targetVelocity = inputVector * swimSpeed

	if inputVector.y == 0:
		var sinkRate = 45.0
		targetVelocity.y = sinkRate

	velocity = velocity.move_toward(targetVelocity, swimAcceleration * delta)

	if Input.is_action_just_pressed("move_up"):
		velocity.y = jumpVelocity

	if inputVector.x != 0:
		sprite.flip_h = inputVector.x < 0

# --- STAT FUNCTIONS ---

func depleteAir(delta: float) -> void:
	if currentAir > 0:
		currentAir -= 10.0 * delta # Depletes over 10 seconds
		currentAir = max(0.0, currentAir)
	else:
		# Drown: Take damage over time
		takeDamage(drownDamageRate * delta)

func recoverAir(delta: float) -> void:
	if currentAir < maxAir:
		currentAir += airRecoveryRate * delta
		currentAir = min(maxAir, currentAir)

func takeDamage(amount: float) -> void:
	if isDead:
		return
	# Don't take damage on titlescreen
	var ui = get_tree().root.get_node("Main/UI")
	if ui and ui.current_state == ui.UIState.TITLE:
		return
	currentHealth = max(0.0, currentHealth - amount)
	if currentHealth <= 0.0:
		die()

func heal(amount: float) -> void:
	if isDead:
		return
	currentHealth = min(maxHealth, currentHealth + amount)

func die() -> void:
	if isDead:
		return
	isDead = true
	currentHealth = 0.0
	died.emit()

func respawn(atPosition: Vector2) -> void:
	isDead = false
	currentHealth = maxHealth
	currentAir = maxAir
	velocity = Vector2.ZERO
	global_position = atPosition
	respawned.emit()

func handleHotbarInput() -> void:
	if Input.is_action_just_pressed("hotbar_1") and inventory.size() > 0:
		activeWeaponIndex = 0
		_on_hotbar_selected(1)
	elif Input.is_action_just_pressed("hotbar_2") and inventory.size() > 1:
		activeWeaponIndex = 1
		_on_hotbar_selected(2)
	elif Input.is_action_just_pressed("hotbar_3") and inventory.size() > 2:
		activeWeaponIndex = 2
		_on_hotbar_selected(3)

func _on_hotbar_selected(slot: int) -> void:
	# Signal to UI to highlight the selected hotbar slot
	var ui = get_tree().root.get_node("Main/UI")
	if ui:
		ui._update_hotbar_selection(slot)

func handleShootInput() -> void:
	if not Input.is_action_pressed("shoot") or shootCooldown > 0.0:
		return

	var weapon: WeaponData = _getEquippedWeapon()
	if not weapon:
		return

	shootCooldown = weapon.fire_rate
	var direction: Vector2 = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT

	var bullet := PlayerBulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.velocity = direction * weapon.bullet_speed
	bullet.damage = weapon.damage
	bullet.color = weapon.color

	weapon_fired.emit(weapon.weapon_name)

func _getEquippedWeapon() -> WeaponData:
	var weapon_id: String = GameData.equipped_weapon_id
	if _weaponCache.has(weapon_id):
		return _weaponCache[weapon_id]

	var path := "res://resources/weapons/%s.tres" % weapon_id
	if not ResourceLoader.exists(path):
		return null

	var weapon: WeaponData = load(path)
	_weaponCache[weapon_id] = weapon
	return weapon

func updateAnimation() -> void:
	if not sprite or not sprite.sprite_frames:
		return

	var animName := "idle"
	var is_jumping = currentState == State.LAND and not is_on_floor()
	var target_scale := Vector2(1.0, 2.0)

	if is_jumping:
		animName = "idle"
		target_scale = Vector2(1.0, 2.0)
	else:
		match currentState:
			State.LAND:
				animName = "walking" if abs(velocity.x) > 5.0 else "idle"
			State.SWIMMING:
				animName = "walking" if abs(velocity.x) > 5.0 else "idle"
		if abs(velocity.x) > 5.0:
			target_scale = Vector2(2.0, 1.0)
		else:
			target_scale = Vector2(1.0, 2.0)

	if sprite.sprite_frames.has_animation(animName):
		if sprite.animation != animName:
			sprite.play(animName)
	elif sprite.sprite_frames.has_animation("idle"):
		if sprite.animation != "idle":
			sprite.play("idle")

	sprite.scale = target_scale

# --- SIGNAL RECEIVERS ---

func _on_water_area_body_entered(body: Node2D) -> void:
	if body == self:
		currentState = State.SWIMMING
		# Slowly damp falling speed upon hitting the water instead of stopping instantly
		velocity.y = clamp(velocity.y, -swimSpeed, swimSpeed)

func _on_water_area_body_exited(body: Node2D) -> void:
	if body == self:
		currentState = State.LAND

func _on_weapon_equipped(_weapon_id: String) -> void:
	# Invalidate weapon cache when weapon is changed
	_weaponCache.clear()
