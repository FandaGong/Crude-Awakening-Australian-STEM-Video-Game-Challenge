extends CharacterBody2D

signal died
signal respawned

enum State { LAND, SWIMMING }
var currentState = State.LAND

# Player stats
@export var maxHealth: float = 100.0
var currentHealth: float = maxHealth

@export var maxAir: float = 60.0 # Oxygen capacity
var currentAir: float = maxAir

@export var drownDamageRate: float = 5.0 # Damage per second when drowning
@export var airRecoveryRate: float = 20.0 # How fast oxygen recovers on land
@export var air_depletion_rate: float = 2.0

var isDead: bool = false
var respawn_immunity: float = 0.0
@export var respawn_immunity_duration: float = 2.5
@export var respawn_flicker_rate: float = 12.0

@export var rewind_history_seconds: float = 3.0
@export var rewind_sample_interval: float = 0.1
@export var default_rewind_seconds: float = 1.5
var _rewind_history: Array[Dictionary] = []
var _rewind_sample_timer: float = 0.0

# Inventory and hotbar
var inventory: Array[String] = ["Potion", "Fish", "Shell"] # Temporary test list
var activeSlotIndex: int = 0

# Robot companion state
var hasRobotCompanion: bool:
	get: return GameData.is_robot_unlocked
	set(value): GameData.is_robot_unlocked = value

# Sprite scale
@export var baseScale: float = 1.0 # Standard 1x scale

# Movement speed
@export var walkSpeed = 300.0
@export var swimSpeed = 420.0
@export var gravity = 980.0
@export var jumpVelocity = -350.0
@export var acceleration = 2000.0

# Swimming
@export var swimTurnSpeed = 6.5       # Smoothness of steering into turns
@export var swimAcceleration = 850.0   # How smoothly the otter reaches full swim speed
@export var swimDeceleration = 450.0   # Water friction / gliding when releasing keys
@export var rollSpeed = 9.0            # Speed of the barrel roll synced to turning
@export var undulationStrength = 0.05  # Subtle spine flex while paddling
@export var bubble_trail_interval: float = 0.14
var currentSwimAngle: float = 0.0
var swimTime: float = 0.0
var bubble_trail_timer := 0.0
var movement_sound_timer := 0.0
@export var movement_sound_interval: float = 0.8
@export var damage_sound_interval: float = 0.35
var _damage_sound_timer := 0.0

# Jumping
@export var coyoteTime = 0.12
@export var jumpBufferTime = 0.12
var coyoteTimer = 0.0
var jumpBufferTimer = 0.0

@export var sprite: AnimatedSprite2D
@export var mainCollision2D: CollisionShape2D

# --- GEAR PROC TUNING ---
@export var synergy1_physical_damage_reduction: float = 0.85
@export var carapace_flat_damage_reduction: float = 3.0
@export var carapace_guard_damage_multiplier: float = 0.5
@export var carapace_trigger_health_pct: float = 0.30
@export var carapace_guard_duration: float = 10.0
@export var carapace_cooldown_duration: float = 15.0
@export var gazer_shockwave_range: float = 120.0
@export var gazer_shockwave_stun: float = 1.5
@export var gazer_cooldown_duration: float = 10.0
@export var bio_electric_aura_range: float = 40.0
@export var bio_electric_knockback_force: float = 200.0
@export var bio_electric_stun_duration: float = 1.0
@export var microplastic_recycler_cd_multiplier: float = 0.8
@export var whale_skin_wetsuit_max_air: float = 90.0

# --- ABILITY TUNING (non-weapon actives) ---
@export var jelly_stinger_range: float = 250.0
@export var jelly_stinger_stun: float = 1.5

@export var crab_pincer_cone_degrees: float = 60.0
@export var crab_pincer_length: float = 80.0
@export var crab_pincer_knockback: float = 250.0
@export var crab_pincer_slow_amount: float = 0.60
@export var crab_pincer_slow_duration: float = 2.0

@export var pearl_volley_angles: Array[float] = [-15.0, 0.0, 15.0]
@export var pearl_travel_distance: float = 200.0
@export var pearl_travel_time: float = 0.3
@export var pearl_hit_radius: float = 24.0
@export var pearl_homing_radius: float = 45.0
@export var pearl_cure_amount: float = 10.0
@export var pearl_visual_width: float = 4.0
@export var pearl_visual_color: Color = Color.WHITE

@export var abyssal_flare_cone_degrees: float = 15.0
@export var abyssal_flare_length: float = 300.0
@export var abyssal_flare_blind_duration: float = 3.0

@export var aim_assist_cone_degrees: float = 8.0

@export var lure_cone_degrees: float = 30.0
@export var lure_length: float = 180.0
@export var lure_cone_color: Color = Color(1.0, 0.95, 0.6, 0.15)
@export var lure_slow_amount: float = 0.20
@export var lure_slow_duration: float = 0.1

# --- VISUAL LINE / ARC STYLING ---
@export var temp_line_width: float = 3.0
@export var sweep_arc_width: float = 7.0
@export var sweep_arc_color: Color = Color(1.0, 0.48, 0.16, 0.9)
@export var sweep_arc_z_index: int = 20
@export var sweep_arc_fade_duration: float = 0.22
@export var sweep_arc_steps: int = 8

# Ability cooldowns
var ability_cooldowns: Dictionary = {
	"jelly_stinger": 0.0,
	"crab_pincer": 0.0,
	"pearlescent_volley": 0.0,
	"abyssal_flare": 0.0
}

# Gear cooldowns
var gazer_cooldown: float = 0.0
var carapace_cooldown: float = 0.0
var carapace_active_timer: float = 0.0
var physical_skill_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	if sprite:
		sprite.scale = Vector2(baseScale, baseScale)
	update_max_air_capacity()
	_auto_connect_water_areas()

func _auto_connect_water_areas() -> void:
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
	if isDead:
		velocity = Vector2.ZERO
		return
	respawn_immunity = maxf(0.0, respawn_immunity - delta)
	if respawn_immunity > 0.0 and sprite:
		sprite.visible = int(respawn_immunity * respawn_flicker_rate) % 2 == 0
	elif sprite:
		sprite.visible = true
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
	_update_movement_sound(delta)

	handleHotbarInput()
	handleShootInput()
	_apply_passive_body_aura_check()
	updateAnimation()
	move_and_slide()
	queue_redraw()
	_record_rewind_state(delta)

func _record_rewind_state(delta: float) -> void:
	_rewind_sample_timer -= delta
	if _rewind_sample_timer > 0.0:
		return
	_rewind_sample_timer = rewind_sample_interval
	_rewind_history.append({
		"position": global_position,
		"velocity": velocity,
		"state": currentState,
		"health": currentHealth,
		"air": currentAir
	})
	while _rewind_history.size() > int(rewind_history_seconds / rewind_sample_interval):
		_rewind_history.pop_front()

func rewind_to_recent_state(seconds: float = -1.0) -> void:
	if _rewind_history.is_empty():
		return
	var use_seconds = default_rewind_seconds if seconds < 0.0 else seconds
	var index := maxi(0, _rewind_history.size() - 1 - int(use_seconds / rewind_sample_interval))
	var state: Dictionary = _rewind_history[index]
	global_position = state["position"]
	velocity = Vector2.ZERO
	currentState = state["state"]
	currentHealth = minf(maxHealth, maxf(1.0, state["health"]))
	currentAir = clampf(state["air"], 0.0, maxAir)
	_rewind_history.clear()

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

		currentSwimAngle = lerp_angle(currentSwimAngle, targetAngle, swimTurnSpeed * delta)

		var forwardThrust = Vector2.from_angle(currentSwimAngle) * swimSpeed
		velocity = velocity.move_toward(forwardThrust, swimAcceleration * delta)

		var spineWiggle = sin(swimTime) * undulationStrength
		sprite.rotation = currentSwimAngle + spineWiggle
		bubble_trail_timer -= delta
		if bubble_trail_timer <= 0.0:
			bubble_trail_timer = bubble_trail_interval
			Effects.spawn_bubble_trail(global_position - Vector2.from_angle(currentSwimAngle) * 16.0)
	else:
		var sinkVelocity = Vector2(0.0, 45.0)
		velocity = velocity.move_toward(sinkVelocity, swimDeceleration * delta)

		var idleTargetAngle = 0.0 if cos(currentSwimAngle) >= 0.0 else PI
		currentSwimAngle = lerp_angle(currentSwimAngle, idleTargetAngle, 3.0 * delta)
		sprite.rotation = currentSwimAngle

	var targetScaleY = -baseScale if abs(currentSwimAngle) > (PI / 2.0) else baseScale
	sprite.scale.y = move_toward(sprite.scale.y, targetScaleY, rollSpeed * baseScale * delta)
	sprite.scale.x = baseScale

func _play_swimming_sound(delta: float) -> void:
	movement_sound_timer -= delta
	if movement_sound_timer <= 0.0:
		movement_sound_timer = movement_sound_interval
		AudioManager.play_sfx("swimming")

func _play_land_movement_sound(delta: float) -> void:
	movement_sound_timer -= delta
	if movement_sound_timer <= 0.0:
		movement_sound_timer = movement_sound_interval
		AudioManager.play_sfx("land_movement")

# Movement sounds
func _update_movement_sound(delta: float) -> void:
	var swimming_and_moving: bool = currentState == State.SWIMMING \
		and Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.01
	var grounded_and_moving: bool = currentState == State.LAND \
		and is_on_floor() and velocity.y >= 0.0 \
		and absf(Input.get_axis("move_left", "move_right")) > 0.01

	if swimming_and_moving:
		AudioManager.stop_sfx("land_movement")
		_play_swimming_sound(delta)
	elif grounded_and_moving:
		AudioManager.stop_sfx("swimming")
		_play_land_movement_sound(delta)
	else:
		AudioManager.stop_sfx("swimming")
		AudioManager.stop_sfx("land_movement")
		movement_sound_timer = 0.0

# Stat functions

func update_max_air_capacity() -> void:
	# Whale-Skin Wet-Suit
	if GameData.equip_body_id == "whale_skin_wetsuit":
		maxAir = whale_skin_wetsuit_max_air
	else:
		maxAir = 60.0
	currentAir = min(currentAir, maxAir)

func depleteAir(delta: float) -> void:
	if currentAir > 0:
		currentAir -= air_depletion_rate * delta
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
		
	# Porous Sponge Charm
	if GameData.equip_accessory_id == "porous_sponge_charm" and damage_type == "acid":
		recoverAir(5.0)
		return

	var ui = get_tree().root.get_node_or_null("Main/UI")
	if ui and ui.current_state == ui.UIState.TITLE:
		return

	# Crustacean Carapace
	var final_damage = amount
	if physical_skill_timer > 0.0 and damage_type == "physical" and GameData.has_skill("synergy_1"):
		final_damage *= synergy1_physical_damage_reduction
	if GameData.equip_body_id == "crustacean_carapace" and damage_type != "drown":
		final_damage = max(1.0, final_damage - carapace_flat_damage_reduction)
		
	# Carapace guard
	if carapace_active_timer > 0.0 and damage_type != "drown":
		final_damage *= carapace_guard_damage_multiplier

	var health_before := currentHealth
	currentHealth = max(0.0, currentHealth - final_damage)
	var damage_taken := health_before - currentHealth
	if damage_taken > 0.0:
		_play_damage_sound()
		if Effects:
			Effects.show_number(global_position, damage_taken, false, self)
	
	# Gazer Helmet
	if GameData.equip_head_id == "gazer_helmet" and gazer_cooldown <= 0.0 and damage_type == "physical":
		_trigger_gazer_shockwave()

	# Carapace emergency guard
	if GameData.equip_body_id == "crustacean_carapace" and (currentHealth / maxHealth) < carapace_trigger_health_pct:
		if carapace_cooldown <= 0.0:
			carapace_active_timer = carapace_guard_duration
			carapace_cooldown = carapace_cooldown_duration

	if currentHealth <= 0.0:
		die()

func _trigger_gazer_shockwave() -> void:
	gazer_cooldown = gazer_cooldown_duration
	var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
	for mob in mobs:
		if global_position.distance_to(mob.global_position) < gazer_shockwave_range and mob.has_method("apply_stun"):
			mob.apply_stun(gazer_shockwave_stun)

func _apply_passive_body_aura_check() -> void:
	# Bio-Electric Vest
	if GameData.equip_body_id == "bio_electric_vest":
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			if global_position.distance_to(mob.global_position) < bio_electric_aura_range:
				if mob.has_method("apply_knockback") and mob.has_method("apply_stun"):
					var dir = (mob.global_position - global_position).normalized()
					mob.apply_knockback(dir * bio_electric_knockback_force)
					mob.apply_stun(bio_electric_stun_duration)

func _tick_cooldowns(delta: float) -> void:
	for key in ability_cooldowns.keys():
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] = max(0.0, ability_cooldowns[key] - delta)
			
	gazer_cooldown = max(0.0, gazer_cooldown - delta)
	carapace_cooldown = max(0.0, carapace_cooldown - delta)
	carapace_active_timer = max(0.0, carapace_active_timer - delta)
	physical_skill_timer = max(0.0, physical_skill_timer - delta)
	_damage_sound_timer = maxf(0.0, _damage_sound_timer - delta)

func _play_damage_sound() -> void:
	if _damage_sound_timer > 0.0:
		return
	AudioManager.play_sfx("otter_hit")
	_damage_sound_timer = damage_sound_interval

func heal(amount: float) -> float:
	if isDead:
		return 0.0
	var health_before := currentHealth
	currentHealth = min(maxHealth, currentHealth + amount)
	var health_restored := currentHealth - health_before
	if Effects and health_restored > 0.0:
		Effects.show_number(global_position, health_restored, true, self)
	return health_restored

func die() -> void:
	if isDead:
		return
	isDead = true
	velocity = Vector2.ZERO
	if sprite:
		sprite.visible = false
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
	respawn_immunity = respawn_immunity_duration
	visible = true
	if sprite:
		sprite.visible = true
	respawned.emit()

# Hotbar abilities

func handleHotbarInput() -> void:
	if isDead:
		return
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
	if isDead:
		return
	# Robot ability lock
	if not GameData.is_robot_unlocked:
		return
	if not Input.is_action_just_pressed("shoot") or activeSlotIndex >= GameData.active_abilities.size():
		return

	# UI input lock
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
		"abyssal_flare": 8.0,
		"starter_spear": 0.4,
		"harpoon_gun": 0.8,
		"coral_shard": 1.0,
		"electric_eel_rod": 1.2,
		"void_trident": 1.5,
		"leviathan_fang": 1.0
	}
	
	var cd = base_cooldowns.get(ability_id, 3.0)
	
	# Microplastic Recycler
	if GameData.equip_accessory_id == "microplastic_recycler":
		cd *= microplastic_recycler_cd_multiplier
		
	ability_cooldowns[ability_id] = cd
	_execute_ability(ability_id)

func _execute_ability(ability_id: String) -> void:
	if GameData.has_skill("synergy_1"):
		physical_skill_timer = 0.35
	var aim_dir = (get_global_mouse_position() - global_position).normalized()
	if _is_weapon_id(ability_id):
		_execute_weapon(ability_id, aim_dir)
		return

	match ability_id:
		"jelly_stinger":
			var target = _get_raycast_target_to_mouse(jelly_stinger_range)
			if target and target.has_method("apply_stun"):
				target.apply_stun(jelly_stinger_stun)
				_draw_temp_line(global_position, target.global_position, Color.CYAN, 0.15)
			else:
				_draw_temp_line(global_position, global_position + aim_dir * jelly_stinger_range, Color.DARK_CYAN, 0.1)

		"crab_pincer":
			var sweep_cone = deg_to_rad(crab_pincer_cone_degrees)
			var length = crab_pincer_length
			var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
			for mob in mobs:
				var to_mob = mob.global_position - global_position
				if to_mob.length() < length and abs(aim_dir.angle_to(to_mob)) < sweep_cone:
					if mob.has_method("apply_knockback"):
						mob.apply_knockback(aim_dir * crab_pincer_knockback)
					if mob.has_method("apply_slow"):
						mob.apply_slow(crab_pincer_slow_amount, crab_pincer_slow_duration)
			_draw_sweep_arc(aim_dir, sweep_cone, length)

		"pearlescent_volley":
			for angle in pearl_volley_angles:
				var pearl_dir = aim_dir.rotated(deg_to_rad(angle))
				_spawn_curing_pearl(pearl_dir)

		"abyssal_flare":
			var search_cone = deg_to_rad(abyssal_flare_cone_degrees)
			var length = abyssal_flare_length
			var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
			for mob in mobs:
				var to_mob = mob.global_position - global_position
				if to_mob.length() < length and abs(aim_dir.angle_to(to_mob)) < search_cone:
					if mob.has_method("apply_blind"):
						mob.apply_blind(abyssal_flare_blind_duration)
			_draw_temp_line(global_position, global_position + aim_dir * length, Color(1, 1, 0.7, 0.7), 0.4)

func _is_weapon_id(item_id: String) -> bool:
	var path := "res://resources/items/%s.tres" % item_id
	if not ResourceLoader.exists(path):
		return false
	var item: ItemData = load(path)
	return item.item_type == ItemData.ItemType.WEAPON

func _execute_weapon(weapon_id: String, aim_dir: Vector2) -> void:
	var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
	var attack_range := 260.0
	var width := 24.0
	var cure_amount := 10.0
	match weapon_id:
		"harpoon_gun":
			attack_range = 380.0
			cure_amount = 28.0
			width = 18.0
		"coral_shard":
			attack_range = 240.0
			cure_amount = 16.0
			width = 48.0
		"electric_eel_rod":
			attack_range = 300.0
			cure_amount = 20.0
			width = 28.0
		"void_trident":
			attack_range = 170.0
			cure_amount = 32.0
			width = 80.0
		"leviathan_fang":
			attack_range = 210.0
			cure_amount = 22.0
	for mob in mobs:
		var to_mob: Vector2 = mob.global_position - global_position
		if to_mob.length() <= attack_range and abs(aim_dir.angle_to(to_mob)) <= atan(width / maxf(1.0, to_mob.length())):
			if mob.has_method("apply_cure"):
				mob.apply_cure(cure_amount * GameData.get_cure_multiplier(mob))
			if weapon_id == "electric_eel_rod" and mob.has_method("apply_stun"):
				mob.apply_stun(1.0)
	_draw_temp_line(global_position, global_position + aim_dir * attack_range, Color(0.8, 0.9, 1.0, 0.8), 0.18)

func _get_raycast_target_to_mouse(max_dist: float) -> Node2D:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, get_global_mouse_position())
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)
	if result and result.collider:
		if result.collider.is_in_group("corrupted_mobs") and global_position.distance_to(result.collider.global_position) <= max_dist:
			return result.collider
	# Aim fallback
	var closest_target: Node2D = null
	var closest_distance := max_dist
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	for mob in get_tree().get_nodes_in_group("corrupted_mobs"):
		var to_mob: Vector2 = mob.global_position - global_position
		var distance := to_mob.length()
		if distance <= closest_distance and distance > 0.0 and abs(aim_dir.angle_to(to_mob)) <= deg_to_rad(aim_assist_cone_degrees):
			closest_target = mob
			closest_distance = distance
	return closest_target

func _spawn_curing_pearl(dir: Vector2) -> void:
	var pearl = Line2D.new()
	pearl.width = pearl_visual_width
	pearl.default_color = pearl_visual_color
	pearl.points = [Vector2.ZERO, dir * 8.0]
	get_parent().add_child(pearl)
	pearl.global_position = global_position
	
	var tween = create_tween()
	var target_pos = global_position + dir * pearl_travel_distance
	tween.tween_property(pearl, "global_position", target_pos, pearl_travel_time)
	tween.tween_callback(func():
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			var hit_pos: Vector2 = target_pos
			var homing_hit := false
			if GameData.has_skill("target_2"):
				var projected_pos := global_position + dir * global_position.distance_to(mob.global_position)
				homing_hit = mob.global_position.distance_to(projected_pos) < pearl_homing_radius
				if homing_hit:
					hit_pos = mob.global_position
			if mob.global_position.distance_to(hit_pos) < pearl_hit_radius or homing_hit:
				if mob.has_method("apply_cure"):
					mob.apply_cure(pearl_cure_amount * GameData.get_cure_multiplier(mob))
		pearl.queue_free()
	)

func _draw_temp_line(from: Vector2, to: Vector2, col: Color, time: float) -> void:
	var line = Line2D.new()
	line.width = temp_line_width
	line.default_color = col
	line.points = [Vector2.ZERO, to - from]
	get_parent().add_child(line)
	line.global_position = from
	get_tree().create_timer(time).timeout.connect(line.queue_free)

func _draw_sweep_arc(center_dir: Vector2, angle_width: float, length: float) -> void:
	var arc = Line2D.new()
	arc.width = sweep_arc_width
	arc.default_color = sweep_arc_color
	arc.z_index = sweep_arc_z_index
	
	var pts: Array[Vector2] = []
	var steps = sweep_arc_steps
	for i in range(steps + 1):
		var ang = -angle_width + (angle_width * 2 * i / steps)
		pts.append(center_dir.rotated(ang) * length)
	
	arc.points = pts
	get_parent().add_child(arc)
	arc.global_position = global_position
	var sweep := create_tween()
	sweep.tween_property(arc, "modulate:a", 0.0, sweep_arc_fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sweep.tween_callback(arc.queue_free)

func _draw() -> void:
	# Lure Headband
	if GameData.equip_head_id == "lure_headband":
		var face_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
		if currentState == State.SWIMMING:
			face_dir = Vector2.from_angle(currentSwimAngle)
		
		var cone_angle = deg_to_rad(lure_cone_degrees)
		var length = lure_length
		var points = [
			Vector2.ZERO,
			face_dir.rotated(-cone_angle) * length,
			face_dir.rotated(cone_angle) * length
		]
		draw_polygon(points, [lure_cone_color])

		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			var to_mob = mob.global_position - global_position
			if to_mob.length() < length and abs(face_dir.angle_to(to_mob)) < cone_angle:
				if mob.has_method("apply_slow"):
					mob.apply_slow(lure_slow_amount, lure_slow_duration)

# Animation

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

# Signal receivers

func _on_water_area_body_entered(body: Node2D) -> void:
	if body == self:
		AudioManager.stop_sfx("land_movement")
		AudioManager.play_sfx("splash")
		currentState = State.SWIMMING
		velocity.y = clamp(velocity.y, -swimSpeed, swimSpeed)
		currentSwimAngle = PI if sprite.flip_h else 0.0
		sprite.flip_h = false

func _on_water_area_body_exited(body: Node2D) -> void:
	if body == self:
		AudioManager.stop_sfx("swimming")
		movement_sound_timer = 0.0
		if GameData.equip_body_id == "whale_skin_wetsuit":
			velocity = Vector2.ZERO
		currentState = State.LAND
		bubble_trail_timer = 0.0
		sprite.rotation = 0.0
		sprite.scale = Vector2(baseScale, baseScale)
		sprite.flip_v = false
		sprite.flip_h = cos(currentSwimAngle) < 0.0

func _on_weapon_equipped(_weapon_id: String) -> void:
	pass

func pop_air_bubble() -> void:
	if GameData.equip_accessory_id == "bubble_booster_charm":
		GameData.bubble_booster_timer = 5.0
