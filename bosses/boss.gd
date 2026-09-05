extends Area2D

## Generic boss encounter shell. Every boss in the game uses this same
## script; what makes each fight different is the BossData resource
## assigned to it (health, reward, colour, timings) plus `boss_data.boss_type`,
## which picks a scripted attack pattern below. `boss_type == "generic"`
## (the default, and what all ten pre-existing bosses use) keeps the
## original radial/aimed/spiral bullet-hell untouched. The four field-boss
## types from the design doc ("shell", "jellyfish", "crab", "anglerfish")
## and the two unique megabosses ("whale", "kraken") get their own patterns.

signal defeated(boss_id: int, crystal_reward: int)
signal health_changed(current: float, max: float)

const EnemyBullet := preload("res://bullets/enemy_bullet.tscn")

@export var boss_data: BossData

var current_health: float = 0.0
var player: Node2D
var attack_timer: float = 0.0
var spiral_angle: float = 0.0
var is_defeated: bool = false

@onready var visual: Polygon2D = $Visual
@onready var health_bar: ColorRect = $HealthBar

var _health_bar_full_width: float = 0.0

# --- Shell: consecutive pearl volley then retract ---------------------------
var _shell_pearls_fired: int = 0
var _shell_retract_timer: float = 0.0

# --- Jellyfish: random 5-10s circular shockwave -----------------------------
var _shockwave_timer: float = 0.0

# --- Crab: charge-in melee ---------------------------------------------------
var _crab_state: String = "wait"
var _crab_state_timer: float = 0.0
var body_contact_cooldown: float = 0.0

# --- Anglerfish: sustained triangle light beam ------------------------------
var _beam_active: bool = false
var _beam_timer: float = 0.0
@onready var light_cone: Polygon2D = get_node_or_null("LightCone")

# --- Whale: shockwave + blowhole cure event ---------------------------------
var whale_cured_by_event: bool = false
var _whale_shockwave_telegraph: bool = false
@onready var blowhole: Area2D = get_node_or_null("Blowhole")

# --- Kraken: two-stage tentacle fight ----------------------------------------
var kraken_stage: int = 1
var _kraken_poke_x: float = 0.0
var _kraken_suction_telegraph_timer: float = 0.0

func _ready() -> void:
	add_to_group("boss")
	player = get_tree().get_first_node_in_group("player")
	if health_bar:
		_health_bar_full_width = health_bar.size.x
	if boss_data:
		current_health = 0.0 # bosses are healed from 0% to 100%, never killed
		if visual:
			visual.color = boss_data.color
	attack_timer = 0.5 # brief pause before the fight opens
	health_changed.connect(_on_health_changed)
	body_entered.connect(_on_body_entered)
	if boss_data and boss_data.boss_type == "whale" and blowhole:
		blowhole.body_entered.connect(_on_blowhole_entered)

func _on_health_changed(current: float, max_hp: float) -> void:
	if health_bar and max_hp > 0.0:
		health_bar.size.x = _health_bar_full_width * clampf(current / max_hp, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	if is_defeated or not boss_data:
		return

	body_contact_cooldown = max(0.0, body_contact_cooldown - delta)

	match boss_data.boss_type:
		"shell": _process_shell(delta)
		"jellyfish": _process_jellyfish(delta)
		"crab": _process_crab(delta)
		"anglerfish": _process_anglerfish(delta)
		"whale": _process_whale(delta)
		"kraken": _process_kraken(delta)
		_:
			attack_timer -= delta
			if attack_timer <= 0.0:
				_generic_attack_pattern()
				attack_timer = _current_pattern_interval()

func _current_pattern_interval() -> float:
	var health_pct := 1.0 - current_health / boss_data.max_health
	var base_interval := boss_data.pattern_interval
	if health_pct < 0.33:
		return base_interval * 0.55 # enrage phase: attacks come much faster
	elif health_pct < 0.66:
		return base_interval * 0.78
	return base_interval

# =============================================================================
# GENERIC BULLET-HELL (unchanged behaviour for the original ten bosses)
# =============================================================================

func _generic_attack_pattern() -> void:
	var health_pct := 1.0 - current_health / boss_data.max_health
	var bullet_count := 8 + boss_data.id # later bosses throw more bullets
	var speed := 110.0 * boss_data.bullet_speed_mult

	if health_pct > 0.66:
		_radial_burst(bullet_count, speed)
	elif health_pct > 0.33:
		if randi() % 2 == 0:
			_radial_burst(bullet_count, speed)
		else:
			_aimed_spread(5, 28.0, speed * 1.2)
	else:
		_spiral_tick(speed * 1.3, 6)
		_aimed_spread(3, 18.0, speed * 1.4)

func _radial_burst(count: int, speed: float) -> void:
	for i in range(count):
		var angle := (TAU / count) * i
		_spawn_bullet(Vector2.RIGHT.rotated(angle) * speed)

func _aimed_spread(count: int, spread_deg: float, speed: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	var base_dir: Vector2 = (player.global_position - global_position).normalized()
	var half := count / 2
	for i in range(count):
		var offset_deg := deg_to_rad(float(i - half) * spread_deg)
		_spawn_bullet(base_dir.rotated(offset_deg) * speed)

func _spiral_tick(speed: float, arms: int) -> void:
	for a in range(arms):
		var angle := spiral_angle + (TAU / arms) * a
		_spawn_bullet(Vector2.RIGHT.rotated(angle) * speed)
	spiral_angle = fmod(spiral_angle + 0.35, TAU)

func _spawn_bullet(vel: Vector2) -> void:
	var b := EnemyBullet.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position
	b.velocity = vel
	b.color = boss_data.color
	b.damage = 6.0 + boss_data.id * 0.6

# =============================================================================
# BOSS SHELL: 5 pearls in a row (15 dmg each), retract, repeat
# =============================================================================

func _process_shell(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0.0:
		if _shell_pearls_fired < 5:
			_fire_pearl()
			_shell_pearls_fired += 1
			attack_timer = 0.3 # fast consecutive volley
		else:
			# All 5 pearls retract back into the shell at once, then repeat.
			_shell_pearls_fired = 0
			attack_timer = 1.4

func _fire_pearl() -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	var dir := (player.global_position - global_position).normalized()
	var b := EnemyBullet.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position
	b.velocity = dir * 260.0
	b.color = Color(0.95, 0.92, 0.85)
	b.damage = 15.0

# =============================================================================
# BOSS JELLYFISH: gentle zaps + a big circular shockwave every 5-10s
# =============================================================================

func _process_jellyfish(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0.0:
		_aimed_spread(3, 20.0, 90.0) # weak constant zap pattern (contact-tier)
		attack_timer = 1.6

	_shockwave_timer -= delta
	if _shockwave_timer <= 0.0:
		_fire_shockwave()
		_shockwave_timer = randf_range(5.0, 10.0)

func _fire_shockwave() -> void:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.5, 0.9, 1.0, 0.6)
	var pts: Array[Vector2] = []
	for i in range(33):
		pts.append(Vector2.from_angle(i * TAU / 32.0) * 20.0)
	ring.points = pts
	add_child(ring)

	var radius := 20.0
	var tween := create_tween()
	tween.tween_method(func(r):
		radius = r
		var new_pts: Array[Vector2] = []
		for i in range(33):
			new_pts.append(Vector2.from_angle(i * TAU / 32.0) * r)
		ring.points = new_pts
		if player and is_instance_valid(player) and global_position.distance_to(player.global_position) < r + 10.0 and global_position.distance_to(player.global_position) > r - 10.0:
			player.takeDamage(20.0, "physical")
	, 20.0, 260.0, 0.7)
	tween.tween_callback(ring.queue_free)

# =============================================================================
# BOSS CRAB: longer, faster charge into melee contact damage
# =============================================================================

func _process_crab(delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	_crab_state_timer -= delta
	match _crab_state:
		"wait":
			if _crab_state_timer <= 0.0:
				_crab_state = "charge"
				_crab_state_timer = 0.9 # longer charge than the field crab
		"charge":
			var dir := (player.global_position - global_position).normalized()
			global_position += dir * 340.0 * delta # faster charge than the field crab
			if _crab_state_timer <= 0.0:
				_crab_state = "wait"
				_crab_state_timer = 1.2

func _on_body_entered(body: Node2D) -> void:
	if is_defeated or not boss_data or boss_data.body_damage <= 0.0:
		return
	if body_contact_cooldown > 0.0:
		return
	if body.is_in_group("player") and body.has_method("takeDamage"):
		body.takeDamage(boss_data.body_damage, "physical")
		body_contact_cooldown = 0.6

# =============================================================================
# BOSS ANGLERFISH: triangle light beam (10 dps) + a weaker bulb glow (5 dps)
# =============================================================================

func _process_anglerfish(delta: float) -> void:
	attack_timer -= delta
	if not _beam_active and attack_timer <= 0.0:
		_beam_active = true
		_beam_timer = 2.5
	elif _beam_active:
		_beam_timer -= delta
		_apply_beam_damage(delta)
		if _beam_timer <= 0.0:
			_beam_active = false
			attack_timer = 2.0
			if light_cone:
				light_cone.visible = false

	# Passive bulb glow always ticks a little damage at close range.
	if player and is_instance_valid(player) and global_position.distance_to(player.global_position) < 70.0:
		player.takeDamage(5.0 * delta, "physical")

func _apply_beam_damage(delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var facing := Vector2.LEFT # bosses face the player-ward tunnel by convention
	var cone_half_angle := deg_to_rad(20.0)
	if light_cone:
		light_cone.visible = true
		var length := 260.0
		light_cone.polygon = PackedVector2Array([
			Vector2.ZERO,
			facing.rotated(-cone_half_angle) * length,
			facing.rotated(cone_half_angle) * length
		])
	if dist < 260.0 and abs(facing.angle_to(to_player)) < cone_half_angle:
		player.takeDamage(10.0 * delta, "physical")

# =============================================================================
# BLUE WHALE: not curable normally. Shockwaves toward the player, contact
# damage, and swims in a radius before each volley. Only way to cure it is
# to swim through its blowhole, which absorbs the plastic in its stomach.
# =============================================================================

func _process_whale(delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	# Slow orbit within a radius of the player between shockwave volleys.
	var to_player := player.global_position - global_position
	var desired_radius := 260.0
	var tangent := to_player.normalized().rotated(PI / 2.0)
	if to_player.length() > desired_radius:
		global_position += to_player.normalized() * 40.0 * delta
	global_position += tangent * 30.0 * delta

	attack_timer -= delta
	if attack_timer <= 0.0:
		_fire_whale_shockwave()
		attack_timer = 2.2

func _fire_whale_shockwave() -> void:
	if not player or not is_instance_valid(player):
		return
	var dir := (player.global_position - global_position).normalized()
	var b := EnemyBullet.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position
	b.velocity = dir * 420.0 # travels fast
	b.color = Color(0.6, 0.75, 0.9)
	b.damage = 30.0

func _on_blowhole_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or whale_cured_by_event or is_defeated:
		return
	_run_blowhole_sequence(body)

func _run_blowhole_sequence(body: Node2D) -> void:
	# Simplified "swim into the stomach, absorb the plastic, swim back out"
	# sequence. A full separate interior room can be built later; for now
	# the otter is briefly held in place while the plastic is absorbed, then
	# the whale is cured exactly as the design doc describes.
	set_process_mode(Node.PROCESS_MODE_DISABLED)
	if body.has_method("set"):
		body.velocity = Vector2.ZERO
	await get_tree().create_timer(2.5).timeout
	whale_cured_by_event = true
	set_process_mode(Node.PROCESS_MODE_INHERIT)
	_die()

func takeDamage(amount: float) -> void:
	if is_defeated or not boss_data:
		return
	# Blue Whale ignores the normal curing beam/abilities entirely.
	if not boss_data.curable_by_normal_means and not whale_cured_by_event:
		return
	current_health = minf(boss_data.max_health, current_health + amount)
	if Effects and amount > 0.0:
		Effects.show_number(global_position, amount, true)
	health_changed.emit(current_health, boss_data.max_health)
	if current_health >= boss_data.max_health:
		_die()

func apply_cure(amount: float) -> void:
	takeDamage(amount)

# =============================================================================
# KRAKEN: two-stage fight. Stage 1 = rapid tentacle pokes bottom-to-top.
# Stage 2 (at 50% health) = pokes AND a suction slam with a telegraph ring.
# Cured through standard curing procedures the whole time.
# =============================================================================

func _process_kraken(delta: float) -> void:
	if kraken_stage == 1 and current_health >= boss_data.max_health * 0.5:
		kraken_stage = 2

	attack_timer -= delta
	if attack_timer <= 0.0:
		_kraken_tentacle_poke()
		attack_timer = 0.5 # rapid succession

	if kraken_stage == 2:
		_kraken_suction_telegraph_timer -= delta
		if _kraken_suction_telegraph_timer <= 0.0:
			_kraken_tentacle_suction()
			_kraken_suction_telegraph_timer = 4.0

func _kraken_tentacle_poke() -> void:
	# A massive, fast tentacle pokes up from the bottom of the screen.
	var viewport_size := get_viewport_rect().size
	_kraken_poke_x = randf_range(-viewport_size.x * 0.4, viewport_size.x * 0.4)
	var warn := Line2D.new()
	warn.width = 30.0
	warn.default_color = Color(0.6, 0.1, 0.6, 0.5)
	warn.points = [Vector2(_kraken_poke_x, 400.0), Vector2(_kraken_poke_x, -400.0)]
	add_child(warn)
	get_tree().create_timer(0.15).timeout.connect(func():
		if player and is_instance_valid(player):
			var local_x: float = to_local(player.global_position).x
			if abs(local_x - _kraken_poke_x) < 40.0:
				player.takeDamage(20.0, "physical")
		warn.queue_free()
	)

func _kraken_tentacle_suction() -> void:
	# Circular pre-warning, then a suction-cup slam onto the back of the screen.
	if not player or not is_instance_valid(player):
		return
	var target_pos := player.global_position
	var telegraph := Line2D.new()
	telegraph.width = 3.0
	telegraph.default_color = Color(1.0, 0.4, 0.6, 0.8)
	var pts: Array[Vector2] = []
	for i in range(33):
		pts.append(Vector2.from_angle(i * TAU / 32.0) * 60.0)
	telegraph.points = pts
	telegraph.global_position = target_pos
	get_tree().current_scene.add_child(telegraph)

	get_tree().create_timer(1.0).timeout.connect(func():
		if player and is_instance_valid(player) and player.global_position.distance_to(target_pos) < 70.0:
			player.takeDamage(30.0, "physical")
		telegraph.queue_free()
	)

func _die() -> void:
	is_defeated = true
	if Effects:
		Effects.spawn_trash_drop(global_position, "large")
	else:
		GameData.add_trash("large")
	GameData.compendium_data += 1
	for item_path in boss_data.drop_item_paths:
		if ResourceLoader.exists(item_path):
			GameData.add_item(load(item_path))
	GameData.mark_boss_defeated(boss_data.id)
	defeated.emit(boss_data.id, boss_data.crystal_reward)
	queue_free()
