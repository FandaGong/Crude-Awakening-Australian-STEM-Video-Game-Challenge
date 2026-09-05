extends CharacterBody2D
class_name MutantMob

signal cured(mob: MutantMob)

## Generic field mob. Which of the four creature types (or the stationary
## sponge) this instance behaves as is picked with `mob_type`; the boss
## versions of these same creatures live in bosses/boss.gd instead, since
## they need the health-bar / bullet-hell scaffolding that only bosses use.

enum MobType { SHELL, JELLYFISH, CRAB, ANGLERFISH, SPONGE }

const EnemyBullet := preload("res://bullets/enemy_bullet.tscn")

@export var mob_type: MobType = MobType.SHELL
@export var baseHealth: float = 30.0
@export var baseSpeed: float = 50.0
@export_enum("small", "medium", "large") var trash_size := "small"

# --- Per-type tunables (defaults match the design doc) ---
@export_group("Shell")
@export var shell_body_damage: float = 10.0
@export var shell_charge_time: float = 1.1
@export var shell_pause_time: float = 0.9
@export var shell_charge_speed: float = 220.0

@export_group("Jellyfish")
@export var jelly_body_damage: float = 2.0
@export var jelly_zap_damage: float = 5.0
@export var jelly_hover_distance: float = 128.0 # ~2 tiles
@export var jelly_zap_interval: float = 1.2

@export_group("Crab")
@export var crab_body_damage: float = 15.0
@export var crab_pivot_speed: float = 1.4 # rad/s around the player
@export var crab_pivot_radius: float = 160.0
@export var crab_charge_speed: float = 260.0
@export var crab_pivot_time: float = 1.8
@export var crab_charge_time: float = 0.5
@export var crab_retreat_time: float = 0.6

@export_group("Anglerfish")
@export var angler_radius_dps: float = 2.0
@export var angler_body_damage: float = 5.0
@export var angler_light_radius: float = 110.0
@export var angler_stalk_distance: float = 90.0

@export_group("Sponge")
@export var sponge_bubble_interval: float = 2.5
@export var sponge_bubble_damage: float = 1.0
@export var sponge_bubble_speed: float = 90.0

# --- Shared runtime state -------------------------------------------------
var currentHealth: float
var max_health: float
var isCured: bool = false # legacy name kept for backwards compatibility
var is_cured: bool:
	get: return isCured

var player: Node2D
var body_damage: float = 10.0
var body_hit_cooldown: float = 0.0
var encounter_active := false

var _state: String = ""
var _state_timer: float = 0.0
var _pivot_angle: float = 0.0
var _pivot_dir: int = 1
var _zap_timer: float = 0.0
var _sponge_timer: float = 0.0

# --- Status effects --------------------------------------------------------
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var slow_pct: float = 0.0
var blind_timer: float = 0.0

func _ready() -> void:
	add_to_group("corrupted_mobs")
	player = get_tree().get_first_node_in_group("player")

	var depthScale = global_position.y / 1000.0
	max_health = baseHealth + (depthScale * 10.0)
	currentHealth = 0.0 # creatures begin injured, then heal to 100% cure

	match mob_type:
		MobType.SHELL:
			body_damage = shell_body_damage
			_enter_state("pause")
		MobType.JELLYFISH:
			body_damage = jelly_body_damage
		MobType.CRAB:
			body_damage = crab_body_damage
			_pivot_angle = randf() * TAU
			_pivot_dir = 1 if randi() % 2 == 0 else -1
			_enter_state("pivot")
		MobType.ANGLERFISH:
			body_damage = angler_body_damage
		MobType.SPONGE:
			body_damage = 0.0
			baseSpeed = 0.0

	var hitbox := get_node_or_null("HitBox")
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if isCured or not encounter_active:
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	_tick_status_effects(delta)
	body_hit_cooldown = max(0.0, body_hit_cooldown - delta)

	if stun_timer > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return

	match mob_type:
		MobType.SHELL: _process_shell(delta)
		MobType.JELLYFISH: _process_jellyfish(delta)
		MobType.CRAB: _process_crab(delta)
		MobType.ANGLERFISH: _process_anglerfish(delta)
		MobType.SPONGE: _process_sponge(delta)

	move_and_slide()
	_apply_contact_damage()

func _tick_status_effects(delta: float) -> void:
	stun_timer = max(0.0, stun_timer - delta)
	blind_timer = max(0.0, blind_timer - delta)
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_pct = 0.0

func _speed_mult() -> float:
	return 1.0 - slow_pct if slow_timer > 0.0 else 1.0

func _enter_state(state_name: String, duration: float = 0.0) -> void:
	_state = state_name
	_state_timer = duration

# --- SHELL: charge, stop, charge -------------------------------------------
func _process_shell(delta: float) -> void:
	if not player:
		return
	_state_timer -= delta
	match _state:
		"pause":
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			if _state_timer <= 0.0:
				_enter_state("charge", shell_charge_time)
		"charge":
			var dir := (player.global_position - global_position).normalized()
			velocity = dir * shell_charge_speed * _speed_mult()
			if _state_timer <= 0.0:
				_enter_state("pause", shell_pause_time)
		_:
			_enter_state("pause", shell_pause_time)

# --- JELLYFISH: hover ~2 tiles away, then zap -------------------------------
func _process_jellyfish(delta: float) -> void:
	if not player:
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var desired := jelly_hover_distance
	if dist > desired + 8.0:
		velocity = to_player.normalized() * baseSpeed * _speed_mult()
	elif dist < desired - 8.0:
		velocity = -to_player.normalized() * baseSpeed * _speed_mult()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)

	if dist <= desired + 24.0:
		_zap_timer -= delta
		if _zap_timer <= 0.0:
			_zap_timer = jelly_zap_interval
			_fire_zap()

func _fire_zap() -> void:
	if not player:
		return
	player.takeDamage(jelly_zap_damage, "physical")
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.6, 0.9, 1.0, 0.85)
	line.points = [Vector2.ZERO, to_local(player.global_position)]
	add_child(line)
	get_tree().create_timer(0.15).timeout.connect(line.queue_free)

# --- CRAB: pivot around player, charge in, retreat, repeat ------------------
func _process_crab(delta: float) -> void:
	if not player:
		return
	_state_timer -= delta
	match _state:
		"pivot":
			_pivot_angle += crab_pivot_speed * _pivot_dir * delta
			var target := player.global_position + Vector2.from_angle(_pivot_angle) * crab_pivot_radius
			velocity = (target - global_position) * 4.0
			velocity = velocity.limit_length(baseSpeed * _speed_mult())
			if _state_timer <= 0.0:
				_enter_state("charge", crab_charge_time)
		"charge":
			var dir := (player.global_position - global_position).normalized()
			velocity = dir * crab_charge_speed * _speed_mult()
			if _state_timer <= 0.0:
				_enter_state("retreat", crab_retreat_time)
		"retreat":
			var away := (global_position - player.global_position).normalized()
			velocity = away * baseSpeed * 1.2 * _speed_mult()
			if _state_timer <= 0.0:
				_enter_state("pivot", crab_pivot_time)
		_:
			_enter_state("pivot", crab_pivot_time)

# --- ANGLERFISH: stalk to light range, deal continuous radius damage -------
func _process_anglerfish(delta: float) -> void:
	if not player:
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist > angler_stalk_distance:
		velocity = to_player.normalized() * baseSpeed * _speed_mult()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)

	if dist <= angler_light_radius:
		player.takeDamage(angler_radius_dps * delta, "physical")

# --- SPONGE: stationary, periodically lobs acidic bubbles -------------------
func _process_sponge(delta: float) -> void:
	velocity = Vector2.ZERO
	_sponge_timer -= delta
	if _sponge_timer <= 0.0:
		_sponge_timer = sponge_bubble_interval
		_spawn_acid_bubble()

func _spawn_acid_bubble() -> void:
	if not player:
		return
	var b := EnemyBullet.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position
	b.velocity = (player.global_position - global_position).normalized() * sponge_bubble_speed
	b.color = Color(0.55, 0.9, 0.3, 0.9)
	b.damage = sponge_bubble_damage
	if "damage_type" in b:
		b.damage_type = "acid"

# --- Contact / body damage --------------------------------------------------
func _apply_contact_damage() -> void:
	if body_damage <= 0.0 or body_hit_cooldown > 0.0:
		return
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("player") and collider.has_method("takeDamage"):
			collider.takeDamage(body_damage, "physical")
			body_hit_cooldown = 0.5
			return

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body_damage <= 0.0 or body_hit_cooldown > 0.0:
		return
	if body.is_in_group("player") and body.has_method("takeDamage"):
		body.takeDamage(body_damage, "physical")
		body_hit_cooldown = 0.5

# --- Curing & status-effect interface (called by player.gd / companionRobot.gd) ---
func apply_cure(amount: float) -> void:
	if isCured:
		return
	currentHealth = minf(max_health, currentHealth + amount)
	if currentHealth >= max_health:
		cureMob()

func cure_percent() -> float:
	return 100.0 * currentHealth / max_health if max_health > 0.0 else 0.0

# Legacy alias kept in case anything still calls the old camelCase name.
func applyCure(amount: float) -> void:
	apply_cure(amount)

func apply_stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)

func apply_slow(pct: float, duration: float) -> void:
	slow_pct = max(slow_pct, clampf(pct, 0.0, 0.95))
	slow_timer = max(slow_timer, duration)

func apply_blind(duration: float) -> void:
	blind_timer = max(blind_timer, duration)
	# A blinded mob turns tail and swims away from the otter for the duration.
	if player and is_instance_valid(player):
		var away := (global_position - player.global_position).normalized()
		velocity = away * baseSpeed * 1.5

func apply_knockback(impulse: Vector2) -> void:
	velocity += impulse
	stun_timer = max(stun_timer, 0.2)

func cureMob() -> void:
	isCured = true
	# A healed animal is catalogued rather than destroyed and leaves recyclable
	# debris lodged in its corruption for the robot's upgrades.
	if GameData:
		GameData.compendium_data += 1
		GameData.add_trash(trash_size)
	cured.emit(self)
	queue_free()
