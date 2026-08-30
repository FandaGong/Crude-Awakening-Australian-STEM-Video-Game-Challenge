extends Area2D

## Generic bullet-hell boss. Every boss in the game uses this same script;
## what makes each fight different is the BossData resource assigned to it
## (health, reward, colour, and how aggressive/fast its attacks are) plus
## which phase of the fight it's currently in (health-based).

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

func _ready() -> void:
	add_to_group("boss")
	player = get_tree().get_first_node_in_group("player")
	if health_bar:
		_health_bar_full_width = health_bar.size.x
	if boss_data:
		current_health = boss_data.max_health
		if visual:
			visual.color = boss_data.color
	attack_timer = 0.5 # brief pause before the fight opens
	health_changed.connect(_on_health_changed)

func _on_health_changed(current: float, max_hp: float) -> void:
	if health_bar and max_hp > 0.0:
		health_bar.size.x = _health_bar_full_width * clampf(current / max_hp, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	if is_defeated or not boss_data:
		return
	attack_timer -= delta
	if attack_timer <= 0.0:
		_run_attack_pattern()
		attack_timer = _current_pattern_interval()

func _current_pattern_interval() -> float:
	var health_pct := current_health / boss_data.max_health
	var base_interval := boss_data.pattern_interval
	if health_pct < 0.33:
		return base_interval * 0.55 # enrage phase: attacks come much faster
	elif health_pct < 0.66:
		return base_interval * 0.78
	return base_interval

func _run_attack_pattern() -> void:
	var health_pct := current_health / boss_data.max_health
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

func takeDamage(amount: float) -> void:
	if is_defeated or not boss_data:
		return
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, boss_data.max_health)
	if current_health <= 0.0:
		_die()

func _die() -> void:
	is_defeated = true
	GameData.add_crystals(boss_data.crystal_reward)
	GameData.mark_boss_defeated(boss_data.id)
	defeated.emit(boss_data.id, boss_data.crystal_reward)
	queue_free()
