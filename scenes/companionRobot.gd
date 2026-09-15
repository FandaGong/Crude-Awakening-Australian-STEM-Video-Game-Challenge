extends Node2D

# Movement
@export var player: CharacterBody2D
@export var followDistance: float = 64.0
@export var hoverSpeed: float = 3.5
@export var hoverAmplitude: float = 4.0
@export var follow_dead_zone: float = 12.0
@export var follow_acceleration: float = 900.0
@export var follow_max_speed: float = 360.0

# Guidance
@export var guide_speed: float = 185.0
@export var guide_lead_distance: float = 92.0
@export var guide_wait_distance: float = 155.0
@export var guide_arrival_distance: float = 72.0

# Curing
@export var cure_range: float = 250.0
@export var base_cure_speed: float = 20.0
@export var healing_injection_amount: float = 20.0
@export var healing_injection_interval: float = 1.0
@export var target_lock_bonus_range: float = 96.0

# Overheat
@export var max_overheat: float = 100.0
@export var overheat_duration: float = 5.0
@export var overheat_cool_rate: float = 10.0
@export var heat_2_cool_multiplier: float = 1.3
@export var heat_gauge_gain_rate: float = 15.0
@export var heat_3_slow_range: float = 96.0
@export var heat_3_slow_amount: float = 0.40
@export var heat_3_slow_duration: float = 3.0

# Rescue
@export var rescue_cooldown_duration: float = 60.0
@export var rescue_trigger_health_pct: float = 0.20
@export var rescue_range: float = 128.0
@export var rescue_knockback_force: float = 300.0

# Baleen / Geothermal
@export var baleen_pull_interval: float = 10.0
@export var baleen_pull_range: float = 300.0
@export var geo_core_interval: float = 6.0
@export var geo_field_radius: float = 60.0
@export var geo_cure_per_tick: float = 4.0

# Beak Soverign
@export var beak_burst_range: float = 400.0
@export var beak_burst_heal: float = 20.0

# Modulator
@export var static_mod_chain_range: float = 80.0
@export var static_mod_secondary_heal_pct: float = 0.5
@export var static_mod_slow_amount: float = 0.30
@export var static_mod_slow_duration: float = 1.0
@export var static_mod_stun_duration: float = 0.75

# Node / Scene
@export var light_beam: Line2D
@export var animated_sprite: AnimatedSprite2D
@export var thermal_field_scene: PackedScene
@export var cure_burst_scene: PackedScene

var timePassed: float = 0.0
var geo_core_timer: float = 0.0
var baleen_timer: float = 0.0

# Overheat
var overheat_gauge: float = 0.0
var is_overheated: bool = false
var overheat_timer: float = 0.0

# Rescue Protocol
var rescue_cooldown: float = 0.0
var healing_injection_timer: float = 0.0

# Trickle damage
var active_beam_target: Node2D = null
var active_beam_heal_rate: float = 0.0
var active_beam_time_left: float = 0.0
var active_beam_heal_accumulator: float = 0.0

var _dialogue_box: DialogueBox = null
var _guide_target: Vector2 = Vector2.ZERO
var _is_guiding: bool = false
var _bubble_trail_timer := 0.0
var _last_trail_position := Vector2.ZERO
var _follow_anchor := Vector2.ZERO
var _follow_velocity := Vector2.ZERO

func _ready() -> void:
	healing_injection_timer = healing_injection_interval
	_last_trail_position = global_position
	if player:
		_follow_anchor = player.global_position
		global_position = _follow_anchor + Vector2(0.0, -followDistance)

func _physics_process(delta: float) -> void:
	if not player or player.isDead or not player.hasRobotCompanion:
		_clear_active_beam()
		hide()
		if light_beam:
			light_beam.visible = false
		return
		
	show()
	_play_default_animation()
	timePassed += delta
	_spawn_bubble_trail(delta)
	
	_follow_player(delta)
	if _is_guiding:
		_process_guidance()

	_process_unique_gear_and_modules(delta)

	if _is_speaking():
		if light_beam:
			light_beam.visible = false
	else:
		_handle_targeting_and_curing(delta)

	_handle_overheat(delta)

	_check_rescue_protocol(delta)

func _spawn_bubble_trail(delta: float) -> void:
	if not player or player.currentState != player.State.SWIMMING:
		_bubble_trail_timer = 0.0
		_last_trail_position = global_position
		return
	_bubble_trail_timer -= delta
	if _bubble_trail_timer > 0.0 or global_position.distance_to(_last_trail_position) < 8.0:
		return
	_bubble_trail_timer = 0.18
	_last_trail_position = global_position
	Effects.spawn_bubble_trail(global_position + Vector2(0.0, 8.0))

# Animation
func _play_default_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default") and (animated_sprite.animation != "default" or not animated_sprite.is_playing()):
		animated_sprite.play("default")

# Guidance
func guide_player_to(destination: Vector2) -> void:
	if not player:
		return
	_guide_target = destination
	_is_guiding = true
	queue_redraw()

# World transition
func snap_to_player() -> void:
	if not player:
		return
	_follow_anchor = player.global_position
	_follow_velocity = Vector2.ZERO
	global_position = _follow_anchor + Vector2(0.0, -followDistance)
	show()

func _follow_player(delta: float) -> void:
	# Smooth follow
	if _follow_anchor.distance_to(player.global_position) > follow_dead_zone:
		_follow_anchor = player.global_position
	var bob_offset := sin(timePassed * hoverSpeed) * hoverAmplitude
	var hover_target := _follow_anchor + Vector2(0.0, -followDistance + bob_offset)
	var offset := hover_target - global_position
	var desired_velocity := offset * 5.0
	desired_velocity = desired_velocity.limit_length(follow_max_speed)
	_follow_velocity = _follow_velocity.move_toward(desired_velocity, follow_acceleration * delta)
	global_position += _follow_velocity * delta

func _process_guidance() -> void:
	var player_to_goal := _guide_target - player.global_position
	if player_to_goal.length() <= guide_arrival_distance:
		_is_guiding = false
		queue_redraw()
	queue_redraw()

func _draw() -> void:
	if not _is_guiding:
		return
	var route := to_local(_guide_target)
	var distance := route.length()
	if distance < 8.0:
		return
	var direction := route.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var arrow_color := Color(0.48, 1.0, 0.82, 0.9)
	var spacing := 34.0
	var arrow_count := mini(8, int(distance / spacing))
	for i in range(1, arrow_count + 1):
		var tip := direction * float(i) * spacing
		var base := tip - direction * 10.0
		draw_colored_polygon(PackedVector2Array([
			tip,
			base + perpendicular * 6.0,
			base - perpendicular * 6.0,
		]), arrow_color)

func _is_speaking() -> bool:
	if not _dialogue_box or not is_instance_valid(_dialogue_box):
		_dialogue_box = get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	return _dialogue_box != null and _dialogue_box.is_open()

func _process_unique_gear_and_modules(delta: float) -> void:
	# Baleen Resonance Core
	if GameData.has_robot_module("baleen_core"):
		baleen_timer += delta
		if baleen_timer >= baleen_pull_interval:
			baleen_timer = 0.0
			var bubbles = get_tree().get_nodes_in_group("air_bubbles")
			for bubble in bubbles:
				if global_position.distance_to(bubble.global_position) < baleen_pull_range:
					var tween = create_tween()
					tween.tween_property(bubble, "global_position", player.global_position, 0.8)

	# Geothermal Core
	if GameData.has_robot_module("geothermal_core"):
		geo_core_timer += delta
		if geo_core_timer >= geo_core_interval:
			geo_core_timer = 0.0
			_spawn_thermal_field()

func _spawn_thermal_field() -> void:
	var field: Line2D = thermal_field_scene.instantiate()
	
	var pts: Array[Vector2] = []
	for i in range(17):
		var angle = i * PI / 8.0
		pts.append(Vector2.from_angle(angle) * geo_field_radius)
	field.points = pts
	get_parent().add_child(field)
	field.global_position = global_position
	
	var cure_ticks = 10
	var timer = get_tree().create_timer(5.0)
	var tween = create_tween().set_loops(cure_ticks)
	tween.tween_callback(func():
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			if mob.global_position.distance_to(field.global_position) < geo_field_radius:
				if mob.has_method("apply_cure"):
					mob.apply_cure(geo_cure_per_tick)
	).set_delay(0.5)
	
	timer.timeout.connect(field.queue_free)

# Targeting
func _select_targets() -> Array[Node2D]:
	# Pearl Crown range bonus
	var effective_range = cure_range
	if GameData.equip_head_id == "pearl_crown":
		effective_range *= 1.25
	if GameData.has_skill("target_2"):
		effective_range *= 1.10
	if GameData.has_skill("comp_2"):
		effective_range *= 1.10

	var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
	# Include bosses
	mobs.append_array(get_tree().get_nodes_in_group("boss"))
	var valid_mobs: Array[Node2D] = []
	var spotlight_pos = GameData.get("photonic_spotlight_position") if "photonic_spotlight_position" in GameData else null

	for mob in mobs:
		var dist = global_position.distance_to(mob.global_position)
		if dist <= effective_range:
			valid_mobs.append(mob)

	valid_mobs.sort_custom(func(a, b):
		if GameData.has_skill("target_3"):
			return _target_health_ratio(a) < _target_health_ratio(b)
		if GameData.has_skill("target_1"):
			# Finish the closest-to-cured target
			return _target_health_ratio(a) > _target_health_ratio(b)
		if spotlight_pos:
			return a.global_position.distance_to(spotlight_pos) < b.global_position.distance_to(spotlight_pos)
		
		var dist_a = player.global_position.distance_to(a.global_position) if player else 0.0
		var dist_b = player.global_position.distance_to(b.global_position) if player else 0.0
		return dist_a < dist_b
	)

	return valid_mobs

func _target_health_ratio(target: Node) -> float:
	var current = target.get("currentHealth")
	var maximum = target.get("max_health")
	if current == null:
		current = target.get("current_health")
	if maximum == null:
		maximum = target.get("maxHealth")
	return float(current) / maxf(1.0, float(maximum)) if current != null and maximum != null else 1.0

# Curing
func _handle_targeting_and_curing(delta: float) -> void:
	var targets = _select_targets()

	# Active beam
	_update_active_beam(delta)

	if targets.is_empty():
		if light_beam and not active_beam_target:
			light_beam.visible = false
		return

	var speed_modifier = 1.0
	
	# Bubble Booster Charm
	if GameData.bubble_booster_timer > 0.0:
		speed_modifier += 0.30 * _module_stat_multiplier()
		
	# Pearl Crown speed bonus
	if GameData.equip_head_id == "pearl_crown":
		speed_modifier += 0.25 * _module_stat_multiplier()

	speed_modifier *= GameData.get_module_speed_multiplier()

	if is_overheated:
		speed_modifier += 0.30

	healing_injection_timer -= delta
	if healing_injection_timer > 0.0:
		return
	healing_injection_timer = healing_injection_interval
	var cure_rate = healing_injection_amount * speed_modifier * _weapon_cure_multiplier()
	if GameData.has_skill("target_4") and player and player.global_position.distance_to(targets[0].global_position) < target_lock_bonus_range:
		healing_injection_timer = healing_injection_interval * 0.5

	# Primary beam
	var primary_target = targets[0]
	_start_beam(primary_target, cure_rate)

	# Overcharge Prism
	if GameData.has_robot_module("overcharge_prism"):
		var num_targets = min(3, targets.size())
		var split_rate = cure_rate / float(num_targets)
		for i in range(1, num_targets):
			var split_target = targets[i]
			if split_target.has_method("apply_cure"):
				split_target.apply_cure(split_rate * GameData.get_cure_multiplier(split_target))
			_draw_assist_beam(i, split_target.global_position)

	# Static Modulator
	if GameData.has_robot_module("static_modulator"):
		if GameData.equipped_weapon_id == "electric_eel_rod" and primary_target.has_method("apply_stun"):
			primary_target.apply_stun(static_mod_stun_duration)
		if targets.size() > 1:
			var secondary = targets[1]
			if secondary.global_position.distance_to(primary_target.global_position) < static_mod_chain_range:
				if secondary.has_method("apply_cure") and secondary.has_method("apply_slow"):
					secondary.apply_cure(cure_rate * static_mod_secondary_heal_pct * GameData.get_cure_multiplier(secondary))
				secondary.apply_slow(static_mod_slow_amount, static_mod_slow_duration)
			_draw_chain_arc(primary_target.global_position, secondary.global_position)

	if GameData.has_skill("heat_1") and not is_overheated:
		overheat_gauge += heat_gauge_gain_rate * delta
		if overheat_gauge >= max_overheat:
			_enter_overheat()

# Beam start
func _start_beam(target: Node2D, total_heal: float) -> void:
	AudioManager.play_sfx("robot_shoot")
	active_beam_target = target
	active_beam_time_left = healing_injection_interval
	active_beam_heal_rate = total_heal / healing_injection_interval
	active_beam_heal_accumulator = 0.0
	if light_beam:
		light_beam.visible = true
		light_beam.points = [Vector2.ZERO, to_local(target.global_position)]

# Beam update
func _update_active_beam(delta: float) -> void:
	if not active_beam_target or not is_instance_valid(active_beam_target):
		_clear_active_beam()
		return

	var tick_time = min(delta, active_beam_time_left)
	active_beam_heal_accumulator += active_beam_heal_rate * tick_time
	if active_beam_heal_accumulator >= 1.0 and active_beam_target.has_method("apply_cure"):
		var heal_tick: float = floor(active_beam_heal_accumulator)
		active_beam_target.apply_cure(maxf(1.0, heal_tick))
		active_beam_heal_accumulator -= heal_tick

	if light_beam:
		light_beam.visible = true
		light_beam.points = [Vector2.ZERO, to_local(active_beam_target.global_position)]

	active_beam_time_left -= delta
	if active_beam_time_left <= 0.0:
		if active_beam_target.get("is_cured") and GameData.has_robot_module("beak_sovereign"):
			_trigger_beak_cure_burst(active_beam_target.global_position)
		_clear_active_beam()

func _clear_active_beam() -> void:
	active_beam_target = null
	active_beam_heal_rate = 0.0
	active_beam_time_left = 0.0
	active_beam_heal_accumulator = 0.0
	if light_beam:
		light_beam.visible = false

func _trigger_beak_cure_burst(origin: Vector2) -> void:
	var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
	for mob in mobs:
		if mob.has_method("apply_cure") and mob.global_position.distance_to(origin) < beak_burst_range:
			mob.apply_cure(beak_burst_heal)

	var circle: Line2D = cure_burst_scene.instantiate()
	get_parent().add_child(circle)
	circle.global_position = origin
	get_tree().create_timer(0.3).timeout.connect(circle.queue_free)

func _draw_assist_beam(index: int, target_pos: Vector2) -> void:
	var beam_node_name = "SplitBeam_" + str(index)
	var beam = get_node_or_null(beam_node_name) as Line2D
	if not beam:
		return  # Missing scene beam
	beam.visible = true
	beam.points = [Vector2.ZERO, to_local(target_pos)]
	get_tree().process_frame.connect(func(): if is_instance_valid(beam): beam.visible = false, CONNECT_ONE_SHOT)

func _draw_chain_arc(from: Vector2, to: Vector2) -> void:
	var chain: Line2D = get_node_or_null("ChainArc") as Line2D
	if not chain:
		return  # Missing scene arc
	chain.points = [to_local(from), to_local(to)]
	chain.visible = true
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(chain):
			chain.visible = false
	)

# Overheat
func _enter_overheat() -> void:
	is_overheated = true
	overheat_timer = overheat_duration
	if GameData.has_skill("heat_3"):
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			if global_position.distance_to(mob.global_position) < heat_3_slow_range and mob.has_method("apply_slow"):
				mob.apply_slow(heat_3_slow_amount, heat_3_slow_duration)

func _handle_overheat(delta: float) -> void:
	if not GameData.has_skill("heat_1"):
		return

	if is_overheated:
		overheat_timer -= delta
		if overheat_timer <= 0.0:
			is_overheated = false
			overheat_gauge = 0.0
	else:
		var cool_rate = overheat_cool_rate
		if GameData.has_skill("heat_2"):
			cool_rate *= heat_2_cool_multiplier
		overheat_gauge = max(0.0, overheat_gauge - (cool_rate * delta))

func _module_stat_multiplier() -> float:
	return 2.0 if is_overheated and GameData.has_skill("heat_4") else 1.0

func _weapon_cure_multiplier() -> float:
	match GameData.equipped_weapon_id:
		"harpoon_gun": return 1.5
		"coral_shard": return 1.25
		"void_trident": return 2.0
		"electric_eel_rod": return 1.15
		"leviathan_fang": return 1.35
		_: return 1.0

# Rescue
func _check_rescue_protocol(delta: float) -> void:
	if not GameData.has_skill("synergy_4") or not player:
		return

	rescue_cooldown = max(0.0, rescue_cooldown - delta)
	if rescue_cooldown <= 0.0 and (player.currentHealth / player.maxHealth) < rescue_trigger_health_pct:
		rescue_cooldown = rescue_cooldown_duration
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			if global_position.distance_to(mob.global_position) < rescue_range and mob.has_method("apply_knockback"):
				var push_dir = (mob.global_position - global_position).normalized()
				mob.apply_knockback(push_dir * rescue_knockback_force)
