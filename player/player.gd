extends CharacterBody2D

signal died
signal respawned

enum State { LAND, SWIMMING }
var currentState = State.LAND

# --- PLAYER STATS ---
@export var maxHealth: float = 100.0
var currentHealth: float = maxHealth

@export var maxAir: float = 100.0 # Oxygen capacity
var currentAir: float = maxAir

@export var drownDamageRate: float = 5.0 # Damage per second when drowning
@export var airRecoveryRate: float = 5.0 # How fast oxygen recovers on land

var isDead: bool = false
var respawn_immunity: float = 0.0

# --- INVENTORY & HOTBAR ---
var inventory: Array[String] = ["Potion", "Fish", "Shell"] # Temporary test list
var activeSlotIndex: int = 0

# Synchronized with GameData so unlocking via NPC or inventory works in all scripts
var hasRobotCompanion: bool:
	get: return GameData.is_robot_unlocked
	set(value): GameData.is_robot_unlocked = value

# --- SPRITE VISUAL SCALE ---
@export var baseScale: float = 1.0 # Standard 1x scale

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

# --- ACTIVE ABILITY COOLDOWNS ---
var ability_cooldowns: Dictionary = {
	"jelly_stinger": 0.0,
	"crab_pincer": 0.0,
	"pearlescent_volley": 0.0,
	"abyssal_flare": 0.0
}

# --- GEAR SPECIAL COOLDOWNS ---
var gazer_cooldown: float = 0.0
var carapace_cooldown: float = 0.0
var carapace_active_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	if sprite:
		sprite.scale = Vector2(baseScale, baseScale)
	update_max_air_capacity()
	_auto_connect_water_areas()

func _auto_connect_water_areas() -> void:
	# Automatically binds all waterArea nodes across the scene tree
	for node in get_tree().get_nodes_in_group("water"):
		if node is Area2D:
			_bind_water_area(node)

	var world = get_tree().root.get_node_or_null("Main/World")
	if world:
		for child in world.find_children("waterArea", "Area2D", true, false):
			_bind_water_area(child)

func _bind_water_area(water: Area2D) -> void:
	if not water.body_entered.is_connected(_on_water_area_body_entered):
		water.body_entered.connect(_on_water_area_body_entered)
	if not water.body_exited.is_connected(_on_water_area_body_exited):
		water.body_exited.connect(_on_water_area_body_exited)

func _physics_process(delta: float) -> void:
	respawn_immunity = maxf(0.0, respawn_immunity - delta)
	if respawn_immunity > 0.0 and sprite:
		sprite.visible = int(respawn_immunity * 12.0) % 2 == 0
	elif sprite:
		sprite.visible = true
	if isDead:
		velocity.x = move_toward(velocity.x, 0, walkSpeed * delta)
		move_and_slide()
		return

	# Don't process gameplay on titlescreen
	var ui = get_tree().root.get_node_or_null("Main/UI")
	if ui and ui.current_state == ui.UIState.TITLE:
		return

	_updateJumpTimers(delta)
	_tick_cooldowns(delta)

	match currentState:
		State.LAND:
			handleLandMovement(delta)
			recoverAir(delta)
		State.SWIMMING:
			handleSwimmingMovement(delta)
			depleteAir(delta)

	handleHotbarInput()
	handleShootInput()
	_apply_passive_body_aura_check()
	updateAnimation()
	move_and_slide()
	queue_redraw()

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

	# --- SMOOTH SYNCHRONIZED BARREL ROLL ---
	var targetScaleY = -baseScale if abs(currentSwimAngle) > (PI / 2.0) else baseScale
	sprite.scale.y = move_toward(sprite.scale.y, targetScaleY, rollSpeed * baseScale * delta)
	sprite.scale.x = baseScale

# --- STAT FUNCTIONS ---

func update_max_air_capacity() -> void:
	# Whale-Skin Wet-Suit: +50% Oxygen Capacity
	if GameData.equip_body_id == "whale_skin_wetsuit":
		maxAir = 150.0
	else:
		maxAir = 100.0
	currentAir = min(currentAir, maxAir)

func depleteAir(delta: float) -> void:
	if currentAir > 0:
		currentAir -= 0.5 * delta
		currentAir = max(0.0, currentAir)
	else:
		takeDamage(drownDamageRate * delta, "drown")

func recoverAir(delta: float) -> void:
	if currentAir < maxAir:
		currentAir += airRecoveryRate * delta
		currentAir = min(maxAir, currentAir)

func takeDamage(amount: float, damage_type: String = "physical") -> void:
	if isDead or respawn_immunity > 0.0:
		return
		
	# Porous Sponge Charm: immunity to acid bubble damage, restores +5 Air instead
	if GameData.equip_accessory_id == "porous_sponge_charm" and damage_type == "acid":
		recoverAir(5.0)
		return

	var ui = get_tree().root.get_node_or_null("Main/UI")
	if ui and ui.current_state == ui.UIState.TITLE:
		return

	# Crustacean Carapace: Passively grants +3 Armor
	var final_damage = amount
	if GameData.equip_body_id == "crustacean_carapace" and damage_type != "drown":
		final_damage = max(1.0, final_damage - 3.0)
		
	# Crustacean Carapace Active: 50% damage reduction
	if carapace_active_timer > 0.0 and damage_type != "drown":
		final_damage *= 0.5

	currentHealth = max(0.0, currentHealth - final_damage)
	
	# Gazer Helmet: taking body damage flashes shockwave to stun nearby mobs
	if GameData.equip_head_id == "gazer_helmet" and gazer_cooldown <= 0.0 and damage_type == "physical":
		_trigger_gazer_shockwave()

	# Crustacean Carapace emergency auto-activation below 30% HP
	if GameData.equip_body_id == "crustacean_carapace" and (currentHealth / maxHealth) < 0.30:
		if carapace_cooldown <= 0.0:
			carapace_active_timer = 10.0
			carapace_cooldown = 15.0

	if currentHealth <= 0.0:
		die()

func _trigger_gazer_shockwave() -> void:
	gazer_cooldown = 10.0
	var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
	for mob in mobs:
		if global_position.distance_to(mob.global_position) < 120.0 and mob.has_method("apply_stun"):
			mob.apply_stun(1.5)

func _apply_passive_body_aura_check() -> void:
	# Bio-Electric Vest: Static aura pushes back touching mobs and stuns for 1s
	if GameData.equip_body_id == "bio_electric_vest":
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			if global_position.distance_to(mob.global_position) < 40.0:
				if mob.has_method("apply_knockback") and mob.has_method("apply_stun"):
					var dir = (mob.global_position - global_position).normalized()
					mob.apply_knockback(dir * 200.0)
					mob.apply_stun(1.0)

func _tick_cooldowns(delta: float) -> void:
	for key in ability_cooldowns.keys():
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] = max(0.0, ability_cooldowns[key] - delta)
			
	gazer_cooldown = max(0.0, gazer_cooldown - delta)
	carapace_cooldown = max(0.0, carapace_cooldown - delta)
	carapace_active_timer = max(0.0, carapace_active_timer - delta)

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
	respawn_immunity = 2.5
	respawned.emit()

# --- HOTBAR & ABILITIES ---

func handleHotbarInput() -> void:
	if Input.is_action_just_pressed("hotbar_1") and inventory.size() > 0:
		activeSlotIndex = 0
		_on_hotbar_selected(1)
	elif Input.is_action_just_pressed("hotbar_2") and inventory.size() > 1:
		activeSlotIndex = 1
		_on_hotbar_selected(2)
	elif Input.is_action_just_pressed("hotbar_3") and inventory.size() > 2:
		activeSlotIndex = 2
		_on_hotbar_selected(3)

func _on_hotbar_selected(slot: int) -> void:
	var ui = get_tree().root.get_node_or_null("Main/UI")
	if ui and ui.has_method("_update_hotbar_selection"):
		ui._update_hotbar_selection(slot)

func handleShootInput() -> void:
	# Mouse-aimed abilities are robot-converted upgrades. The otter has no
	# access to them until the scientist assigns the companion.
	if not GameData.is_robot_unlocked:
		return
	if not Input.is_action_just_pressed("shoot") or activeSlotIndex >= GameData.active_abilities.size():
		return

	# Don't shoot abilities if clicking dialogues or menus
	var hovered = get_viewport().gui_get_hovered_control()
	if hovered and hovered.is_visible_in_tree() and not hovered is SubViewportContainer:
		return

	var ability_id = GameData.active_abilities[activeSlotIndex]
	if ability_cooldowns.get(ability_id, 0.0) > 0.0:
		return

	var base_cooldowns = {
		"jelly_stinger": 3.0,
		"crab_pincer": 3.0,
		"pearlescent_volley": 4.0,
		"abyssal_flare": 8.0
	}
	
	var cd = base_cooldowns.get(ability_id, 3.0)
	
	# Microplastic Recycler: -20% cooldown reduction
	if GameData.equip_accessory_id == "microplastic_recycler":
		cd *= 0.8
		
	ability_cooldowns[ability_id] = cd
	_execute_ability(ability_id)

func _execute_ability(ability_id: String) -> void:
	var aim_dir = (get_global_mouse_position() - global_position).normalized()

	match ability_id:
		"jelly_stinger":
			var target = _get_raycast_target_to_mouse(250.0)
			if target and target.has_method("apply_stun"):
				target.apply_stun(1.5)
				_draw_temp_line(global_position, target.global_position, Color.CYAN, 0.15)
			else:
				_draw_temp_line(global_position, global_position + aim_dir * 250.0, Color.DARK_CYAN, 0.1)

		"crab_pincer":
			var sweep_cone = deg_to_rad(60.0)
			var length = 80.0
			var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
			for mob in mobs:
				var to_mob = mob.global_position - global_position
				if to_mob.length() < length and abs(aim_dir.angle_to(to_mob)) < sweep_cone:
					if mob.has_method("apply_knockback"):
						mob.apply_knockback(aim_dir * 250.0)
					if mob.has_method("apply_slow"):
						mob.apply_slow(0.60, 2.0)
			_draw_sweep_arc(aim_dir, sweep_cone, length)

		"pearlescent_volley":
			var angles = [-15.0, 0.0, 15.0]
			for angle in angles:
				var pearl_dir = aim_dir.rotated(deg_to_rad(angle))
				_spawn_curing_pearl(pearl_dir)

		"abyssal_flare":
			var search_cone = deg_to_rad(15.0)
			var length = 300.0
			var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
			for mob in mobs:
				var to_mob = mob.global_position - global_position
				if to_mob.length() < length and abs(aim_dir.angle_to(to_mob)) < search_cone:
					if mob.has_method("apply_blind"):
						mob.apply_blind(3.0)
			_draw_temp_line(global_position, global_position + aim_dir * length, Color(1, 1, 0.7, 0.7), 0.4)

func _get_raycast_target_to_mouse(max_dist: float) -> Node2D:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, get_global_mouse_position())
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)
	if result and result.collider:
		if result.collider.is_in_group("corrupted_mobs") and global_position.distance_to(result.collider.global_position) <= max_dist:
			return result.collider
	return null

func _spawn_curing_pearl(dir: Vector2) -> void:
	var pearl = Line2D.new()
	pearl.width = 4.0
	pearl.default_color = Color.WHITE
	pearl.points = [Vector2.ZERO, dir * 8.0]
	get_parent().add_child(pearl)
	pearl.global_position = global_position
	
	var tween = create_tween()
	var target_pos = global_position + dir * 200.0
	tween.tween_property(pearl, "global_position", target_pos, 0.3)
	tween.tween_callback(func():
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			if mob.global_position.distance_to(target_pos) < 24.0:
				if mob.has_method("apply_cure"):
					mob.apply_cure(10.0)
		pearl.queue_free()
	)

func _draw_temp_line(from: Vector2, to: Vector2, col: Color, time: float) -> void:
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = col
	line.points = [Vector2.ZERO, to - from]
	get_parent().add_child(line)
	line.global_position = from
	get_tree().create_timer(time).timeout.connect(line.queue_free)

func _draw_sweep_arc(center_dir: Vector2, angle_width: float, length: float) -> void:
	var arc = Line2D.new()
	arc.width = 4.0
	arc.default_color = Color(1.0, 1.0, 1.0, 0.5)
	
	var pts: Array[Vector2] = []
	var steps = 8
	for i in range(steps + 1):
		var ang = -angle_width + (angle_width * 2 * i / steps)
		pts.append(center_dir.rotated(ang) * length)
	
	arc.points = pts
	get_parent().add_child(arc)
	arc.global_position = global_position
	get_tree().create_timer(0.2).timeout.connect(arc.queue_free)

func _draw() -> void:
	# Lure Headband: headlight slowing cone
	if GameData.equip_head_id == "lure_headband":
		var face_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
		if currentState == State.SWIMMING:
			face_dir = Vector2.from_angle(currentSwimAngle)
		
		var cone_angle = deg_to_rad(30.0)
		var length = 180.0
		var points = [
			Vector2.ZERO,
			face_dir.rotated(-cone_angle) * length,
			face_dir.rotated(cone_angle) * length
		]
		draw_polygon(points, [Color(1.0, 0.95, 0.6, 0.15)])

		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			var to_mob = mob.global_position - global_position
			if to_mob.length() < length and abs(face_dir.angle_to(to_mob)) < cone_angle:
				if mob.has_method("apply_slow"):
					mob.apply_slow(0.20, 0.1)

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
		if GameData.equip_body_id == "whale_skin_wetsuit":
			velocity = Vector2.ZERO
		currentState = State.LAND
		sprite.rotation = 0.0
		sprite.scale = Vector2(baseScale, baseScale)
		sprite.flip_v = false
		sprite.flip_h = cos(currentSwimAngle) < 0.0

func _on_weapon_equipped(_weapon_id: String) -> void:
	pass

func pop_air_bubble() -> void:
	if GameData.equip_accessory_id == "bubble_booster_charm":
		GameData.bubble_booster_timer = 5.0
