extends Area2D

## The player's projectile. Damage/speed/color come from the currently
## equipped WeaponData resource so switching weapons changes how this feels.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var color: Color = Color(0.9, 0.9, 0.9)
var lifetime: float = 3.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, color)

func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)

func _on_area_entered(area: Node2D) -> void:
	_try_hit(area)

func _try_hit(target: Node) -> void:
	if target.has_method("takeDamage"):
		target.takeDamage(damage)
		queue_free()
