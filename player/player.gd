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
var inventory: Array[String] = ["Potion", "Harpoon", "Spear"] # Temporary test list
var activeWeaponIndex: int = 0

# --- SPRITE VISUAL SCALE ---
@export var baseScale: float = 3.0

# --- MOVEMENT SPEED ---
@export var walkSpeed = 300.0
@export var swimSpeed = 420.0
@export var gravity = 980.0
@export var jumpVelocity = -350.0
@export var acceleration = 2000.0

# --- SMOOTH HYDRODYNAMIC SWIMMING ---
@export var swimTurnSpeed = 6.5       # Smoothness of steering into turns
@export var swimAcceleration = 850.0   # How smoothly the otter reaches full swim speed
@export var swimDeceleration = 450.0   # Water friction / gliding when releasing keys
@export var rollSpeed = 9.0            # Speed of the barrel roll synced to turning
@export var undulationStrength = 0.05  # Subtle spine flex while paddling
var currentSwimAngle: float = 0.0
var swimTime: float = 0.0

# --- JUMP FEEL ---
@export var coyoteTime = 0.12
@export var jumpBufferTime = 0.12
var coyoteTimer = 0.0
var jumpBufferTimer = 0.0

@onready var sprite = $AnimatedSprite2D

# --- UNIFIED COLLIDER ---
@onready var mainCollision2D: CollisionShape2D = $mainCollision2D

const PlayerBulletScene := preload("res://bullets/player_bullet.tscn")
var shootCooldown: float = 0.0
var _weaponCache: Dictionary = {}

func _ready() -> void:
	add_to_group("player")
	GameData.weapon_equipped.connect(_on_weapon_equipped)
	if sprite:
		sprite.scale = Vector2(baseScale, baseScale)

func _physics_process(delta: float) -> void:
	if isDead:
		velocity.x = move_toward(velocity.x, 0, walkSpeed * delta)
		move_and_slide()
		return

	# Don't process gameplay on titlescreen
	var ui = get_tree().root.get_node_or_null("Main/UI")
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

	handleHotbarInput()
	handleShootInput()
	updateAnimation()
	move_and_slide()

func _updateJumpTimers(delta: float) -> void:
	if currentState == State.LAND and is_on_floor():
		coyoteTimer = coyoteTime
	else:
		coyoteTimer = max(0.0, coyoteTimer - delta)

	if Input.is_action_just_pressed("move_up"):
		jumpBufferTimer = jumpBufferTime
	else:
		jumpBufferTimer = max(0.0, jumpBufferTimer - delta)

func handleLandMovement(delta: float) -> void:
	# Reset rotation, flips, and scale upright on land
	sprite.rotation = 0.0
	sprite.scale = Vector2(baseScale, baseScale)
	sprite.flip_v = false

	if not is_on_floor():
		velocity.y += gravity * delta

	var wantsToJump = jumpBufferTimer > 0.0
	var canJump = is_on_floor() or coyoteTimer > 0.0
	if wantsToJump and canJump:
		velocity.y = jumpVelocity
		jumpBufferTimer = 0.0
		coyoteTimer = 0.0

	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * walkSpeed, acceleration * delta)
		sprite.flip_h = direction < 0
		currentSwimAngle = PI if direction < 0 else 0.0
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)

func handleSwimmingMovement(delta: float) -> void:
	var inputVector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var isPressingKeys = inputVector.length_squared() > 0.01

	sprite.flip_h = false
	sprite.flip_v = false

	if isPressingKeys:
		swimTime += delta * 9.0
		var targetAngle = inputVector.angle()

		# Smooth continuous turn steering across all angles
		currentSwimAngle = lerp_angle(currentSwimAngle, targetAngle, swimTurnSpeed * delta)

		# Forward propulsion directed along where the otter is currently facing
		var forwardThrust = Vector2.from_angle(currentSwimAngle) * swimSpeed
		velocity = velocity.move_toward(forwardThrust, swimAcceleration * delta)

		# Subtle spine undulation while actively swimming
		var spineWiggle = sin(swimTime) * undulationStrength
		sprite.rotation = currentSwimAngle + spineWiggle
	else:
		# Idle glide / sink with water drag
		var sinkVelocity = Vector2(0.0, 45.0)
		velocity = velocity.move_toward(sinkVelocity, swimDeceleration * delta)

		# Smoothly ease back to level posture
		var idleTargetAngle = 0.0 if cos(currentSwimAngle) >= 0.0 else PI
		currentSwimAngle = lerp_angle(currentSwimAngle, idleTargetAngle, 3.0 * delta)
		sprite.rotation = currentSwimAngle

	# --- SMOOTH SYNCHRONIZED BARREL ROLL (Scaled to 3x) ---
	var targetScaleY = -baseScale if abs(currentSwimAngle) > (PI / 2.0) else baseScale
	sprite.scale.y = move_toward(sprite.scale.y, targetScaleY, rollSpeed * baseScale * delta)
	sprite.scale.x = baseScale

# --- STAT FUNCTIONS ---

func depleteAir(delta: float) -> void:
	if currentAir > 0:
		currentAir -= 10.0 * delta
		currentAir = max(0.0, currentAir)
	else:
		takeDamage(drownDamageRate * delta)

func recoverAir(delta: float) -> void:
	if currentAir < maxAir:
		currentAir += airRecoveryRate * delta
		currentAir = min(maxAir, currentAir)

func takeDamage(amount: float) -> void:
	if isDead:
		return
	var ui = get_tree().root.get_node_or_null("Main/UI")
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
	sprite.rotation = 0.0
	sprite.scale = Vector2(baseScale, baseScale)
	sprite.flip_v = false
	sprite.flip_h = false
	currentSwimAngle = 0.0
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
	var ui = get_tree().root.get_node_or_null("Main/UI")
	if ui:
		ui._update_hotbar_selection(slot)

func handleShootInput() -> void:
	if not Input.is_action_pressed("shoot") or shootCooldown > 0.0:
		return

	var weapon: WeaponData = _getEquippedWeapon()
	if not weapon:
		return

	shootCooldown = weapon.fire_rate

	var direction: Vector2
	if currentState == State.SWIMMING:
		direction = Vector2.from_angle(currentSwimAngle)
	else:
		direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT

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

# --- ANIMATION LOGIC ---

func updateAnimation() -> void:
	if not sprite or not sprite.sprite_frames:
		return

	var animName := "idle"
	var isJumping = currentState == State.LAND and not is_on_floor()

	if isJumping:
		if sprite.sprite_frames.has_animation("jump"):
			animName = "jump"
		else:
			animName = "idle"
	else:
		match currentState:
			State.LAND:
				if abs(velocity.x) > 5.0:
					animName = "walking"
				else:
					animName = "idle"
			State.SWIMMING:
				var inputVector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
				var isPressingKeys = inputVector.length_squared() > 0.01

				if isPressingKeys:
					if sprite.sprite_frames.has_animation("swim"):
						animName = "swim"
					else:
						animName = "walking"
				else:
					if sprite.sprite_frames.has_animation("swimIdle"):
						animName = "swimIdle"
					else:
						animName = "idle"

	if sprite.sprite_frames.has_animation(animName):
		if sprite.animation != animName:
			sprite.play(animName)
	elif sprite.sprite_frames.has_animation("idle"):
		if sprite.animation != "idle":
			sprite.play("idle")

# --- SIGNAL RECEIVERS ---

func _on_water_area_body_entered(body: Node2D) -> void:
	if body == self:
		currentState = State.SWIMMING
		velocity.y = clamp(velocity.y, -swimSpeed, swimSpeed)
		currentSwimAngle = PI if sprite.flip_h else 0.0
		sprite.flip_h = false

func _on_water_area_body_exited(body: Node2D) -> void:
	if body == self:
		currentState = State.LAND
		sprite.rotation = 0.0
		sprite.scale = Vector2(baseScale, baseScale)
		sprite.flip_v = false
		sprite.flip_h = cos(currentSwimAngle) < 0.0

func _on_weapon_equipped(_weapon_id: String) -> void:
	_weaponCache.clear()
