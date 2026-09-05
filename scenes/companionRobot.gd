extends Node2D

# --- MOVEMENT CONTROLS ---
@export var player: CharacterBody2D
@export var followSpeed: float = 6.0
@export var hoverSpeed: float = 3.5
@export var hoverAmplitude: float = 12.0

# --- CURING MODULE CONTROLS ---
@export var cure_range: float = 250.0
@export var base_cure_speed: float = 20.0
@export var healing_injection_amount: float = 20.0
@export var healing_injection_interval: float = 1.0

# --- INTERNAL STATES ---
var timePassed: float = 0.0
var geo_core_timer: float = 0.0
var baleen_timer: float = 0.0

# Overheat State (Branch 4)
var overheat_gauge: float = 0.0
var max_overheat: float = 100.0
var is_overheated: bool = false
var overheat_timer: float = 0.0

# Rescue Protocol Cooldown (Node 2.4)
var rescue_cooldown: float = 0.0
var healing_injection_timer: float = 0.0

@onready var light_beam: Line2D = get_node_or_null("CureBeam")

func _ready() -> void:
	if light_beam:
		light_beam.default_color = Color(0.3, 1.0, 0.5, 0.9)
		light_beam.width = 3.0
	healing_injection_timer = healing_injection_interval

func _physics_process(delta: float) -> void:
	if not player or not player.hasRobotCompanion:
		hide()
		if light_beam:
			light_beam.visible = false
		return
		
	show()
	timePassed += delta
	
	# --- 1. MOVEMENT & WAVE LOGIC ---
	var horizontalOffset = 35.0
	if player.sprite and player.sprite.flip_h:
		horizontalOffset = -35.0 
		
	var targetPosition = player.global_position + Vector2(horizontalOffset, -35.0)
	global_position = global_position.lerp(targetPosition, followSpeed * delta)
	global_position.y += sin(timePassed * hoverSpeed) * hoverAmplitude * delta

	# --- 2. UNIQUE PASSIVE MODULE LOOPS ---
	_process_unique_gear_and_modules(delta)

	# --- 3. TARGETING & CURING MECHANICS ---
	_handle_targeting_and_curing(delta)

	# --- 4. OVERHEAT SYSTEMS ---
	_handle_overheat(delta)

	# --- 5. RESCUE PROTOCOLS ---
	_check_rescue_protocol(delta)

func _process_unique_gear_and_modules(delta: float) -> void:
	# Baleen Resonance Core: Pull all nearby air bubbles toward player every 10s
	if GameData.equip_robot_module_id == "baleen_core":
		baleen_timer += delta
		if baleen_timer >= 10.0:
			baleen_timer = 0.0
			var bubbles = get_tree().get_nodes_in_group("air_bubbles")
			for bubble in bubbles:
				if global_position.distance_to(bubble.global_position) < 300.0:
					var tween = create_tween()
					tween.tween_property(bubble, "global_position", player.global_position, 0.8)

	# Geothermal Core: Drop a passive geothermal curing aura every 6s
	if GameData.equip_robot_module_id == "geothermal_core":
		geo_core_timer += delta
		if geo_core_timer >= 6.0:
			geo_core_timer = 0.0
			_spawn_thermal_field()

func _spawn_thermal_field() -> void:
	var field = Line2D.new()
	field.width = 2.0
	field.default_color = Color(1.0, 0.4, 0.2, 0.3)
	
	var pts: Array[Vector2] = []
	for i in range(17):
		var angle = i * PI / 8.0
		pts.append(Vector2.from_angle(angle) * 60.0)
	field.points = pts
	get_parent().add_child(field)
	field.global_position = global_position
	
	var cure_ticks = 10
	var timer = get_tree().create_timer(5.0)
	var tween = create_tween().set_loops(cure_ticks)
	tween.tween_callback(func():
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			if mob.global_position.distance_to(field.global_position) < 60.0:
				if mob.has_method("apply_cure"):
					mob.apply_cure(4.0)
	).set_delay(0.5)
	
	timer.timeout.connect(field.queue_free)

# --- TARGETING ENGINE ---
func _select_targets() -> Array[Node2D]:
	# Pearl Crown: +25% Robot assist range
	var effective_range = cure_range
	if GameData.equip_head_id == "pearl_crown":
		effective_range *= 1.25

	var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
	# Bosses use the same healing-injection pipeline as field animals.
	mobs.append_array(get_tree().get_nodes_in_group("boss"))
	var valid_mobs: Array[Node2D] = []
	var spotlight_pos = GameData.get("photonic_spotlight_position") if "photonic_spotlight_position" in GameData else null

	for mob in mobs:
		var dist = global_position.distance_to(mob.global_position)
		if dist <= effective_range:
			valid_mobs.append(mob)

	valid_mobs.sort_custom(func(a, b):
		if spotlight_pos:
			return a.global_position.distance_to(spotlight_pos) < b.global_position.distance_to(spotlight_pos)
		
		var dist_a = player.global_position.distance_to(a.global_position) if player else 0.0
		var dist_b = player.global_position.distance_to(b.global_position) if player else 0.0
		return dist_a < dist_b
	)

	return valid_mobs

# --- CURING SYSTEM ---
func _handle_targeting_and_curing(delta: float) -> void:
	var targets = _select_targets()
	if targets.is_empty():
		if light_beam:
			light_beam.visible = false
		return

	var speed_modifier = 1.0
	
	# Bubble Booster Charm: Popping bubble yields +30% cure speed for 5s
	if GameData.bubble_booster_timer > 0.0:
		speed_modifier += 0.30
		
	# Pearl Crown: +25% Robot lock-on/assist speed
	if GameData.equip_head_id == "pearl_crown":
		speed_modifier += 0.25

	if is_overheated:
		speed_modifier += 0.30

	healing_injection_timer -= delta
	if healing_injection_timer > 0.0:
		return
	healing_injection_timer = healing_injection_interval
	var cure_rate = healing_injection_amount * speed_modifier

	# Unique Ability: Overcharge Prism (Split Beam up to 3 targets)
	if GameData.equip_robot_module_id == "overcharge_prism":
		var num_targets = min(3, targets.size())
		var split_rate = cure_rate / num_targets
		for i in range(num_targets):
			var mob = targets[i]
			if mob.has_method("apply_cure"):
				mob.apply_cure(split_rate)
			_draw_assist_beam(i, mob.global_position)
	else:
		var primary_target = targets[0]
		
		# Unique Ability: Static Frequency Modulator (Chain-Curing Arc)
		if GameData.equip_robot_module_id == "static_modulator":
			if primary_target.has_method("apply_cure"):
				primary_target.apply_cure(cure_rate)
			
				if targets.size() > 1:
					var secondary = targets[1]
					if secondary.global_position.distance_to(primary_target.global_position) < 80.0:
						if secondary.has_method("apply_cure") and secondary.has_method("apply_slow"):
							secondary.apply_cure(cure_rate * 0.5)
						secondary.apply_slow(0.30, 1.0)
					_draw_chain_arc(primary_target.global_position, secondary.global_position)
		else:
			if primary_target.has_method("apply_cure"):
				primary_target.apply_cure(cure_rate)
				
			if primary_target.get("is_cured") and GameData.equip_robot_module_id == "beak_sovereign":
				_trigger_beak_cure_burst(primary_target.global_position)

		if light_beam:
			light_beam.visible = true
			light_beam.points = [Vector2.ZERO, to_local(primary_target.global_position)]

	if GameData.has_skill("heat_1") and not is_overheated:
		overheat_gauge += 15.0 * delta
		if overheat_gauge >= max_overheat:
			_enter_overheat()

func _trigger_beak_cure_burst(origin: Vector2) -> void:
	var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
	for mob in mobs:
		if mob.has_method("apply_cure") and mob.global_position.distance_to(origin) < 400.0:
			mob.apply_cure(20.0)
			
	var circle = Line2D.new()
	circle.width = 3.0
	circle.default_color = Color.GREEN
	var pts: Array[Vector2] = []
	for i in range(17):
		var angle = i * PI / 8.0
		pts.append(Vector2.from_angle(angle) * 120.0)
	circle.points = pts
	get_parent().add_child(circle)
	circle.global_position = origin
	get_tree().create_timer(0.3).timeout.connect(circle.queue_free)

func _draw_assist_beam(index: int, target_pos: Vector2) -> void:
	var beam_node_name = "SplitBeam_" + str(index)
	var beam = get_node_or_null(beam_node_name) as Line2D
	if not beam:
		beam = Line2D.new()
		beam.name = beam_node_name
		beam.width = 2.0
		beam.default_color = Color(0.2, 1.0, 0.4, 0.6)
		add_child(beam)
	beam.visible = true
	beam.points = [Vector2.ZERO, to_local(target_pos)]
	get_tree().process_frame.connect(func(): if is_instance_valid(beam): beam.visible = false, CONNECT_ONE_SHOT)

func _draw_chain_arc(from: Vector2, to: Vector2) -> void:
	var chain = Line2D.new()
	chain.width = 2.0
	chain.default_color = Color.CYAN
	chain.points = [to_local(from), to_local(to)]
	add_child(chain)
	get_tree().create_timer(0.1).timeout.connect(chain.queue_free)

# --- OVERHEAT PROCEDURES ---
func _enter_overheat() -> void:
	is_overheated = true
	overheat_timer = 5.0
	if GameData.has_skill("heat_3"):
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			if global_position.distance_to(mob.global_position) < 96.0 and mob.has_method("apply_slow"):
				mob.apply_slow(0.40, 3.0)

func _handle_overheat(delta: float) -> void:
	if not GameData.has_skill("heat_1"):
		return

	if is_overheated:
		overheat_timer -= delta
		if overheat_timer <= 0.0:
			is_overheated = false
			overheat_gauge = 0.0
	else:
		var cool_rate = 10.0
		if GameData.has_skill("heat_2"):
			cool_rate *= 1.3
		overheat_gauge = max(0.0, overheat_gauge - (cool_rate * delta))

# --- SURVIVAL GUARDIAN COOLDOWNS ---
func _check_rescue_protocol(delta: float) -> void:
	if not GameData.has_skill("synergy_4") or not player:
		return

	rescue_cooldown = max(0.0, rescue_cooldown - delta)
	if rescue_cooldown <= 0.0 and (player.currentHealth / player.maxHealth) < 0.20:
		rescue_cooldown = 60.0
		var mobs = get_tree().get_nodes_in_group("corrupted_mobs")
		for mob in mobs:
			if global_position.distance_to(mob.global_position) < 128.0 and mob.has_method("apply_knockback"):
				var push_dir = (mob.global_position - global_position).normalized()
				mob.apply_knockback(push_dir * 300.0)
