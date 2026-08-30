extends Area2D

## A single bullet-hell projectile fired by a boss. Travels in a straight
## line at a fixed velocity and damages the player on contact.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 8.0
var color: Color = Color(1.0, 0.3, 0.3)
var lifetime: float = 6.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, color)
	draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, 0.35), false, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("takeDamage"):
		body.takeDamage(damage)
	queue_free()
