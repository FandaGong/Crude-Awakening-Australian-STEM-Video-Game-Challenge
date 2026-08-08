extends CharacterBody2D

enum State { LAND, SWIMMING }
var current_state = State.LAND

@export var walk_speed = 200.0
@export var swim_speed = 400.0 # Slightly slower for better underwater feel
@export var gravity = 980.0
@export var jump_velocity = -400.0 # Negative because Y goes UP in Godot 2D

@onready var sprite = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	match current_state:
		State.LAND:
			handle_land_movement(delta)
		State.SWIMMING:
			handle_swimming_movement(delta)
			
	move_and_slide()

func handle_land_movement(delta: float) -> void:
	# Apply gravity on land
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# Handle Jump (only if on the floor)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		
	# Left/Right movement
	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * walk_speed
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed)

func handle_swimming_movement(_delta: float) -> void:
	# 8-way movement under water (no gravity)
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * swim_speed
	
	# Leaping out of water: Pressing jump while swimming gives an upward burst
	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	
	if input_vector.x != 0:
		sprite.flip_h = input_vector.x < 0


func _on_water_area_body_entered(body: Node2D) -> void:
	if body == self:
		current_state = State.SWIMMING
		# Slowly damp falling speed upon hitting the water instead of stopping instantly
		velocity.y = clamp(velocity.y, -swim_speed, swim_speed)


func _on_water_area_body_exited(body: Node2D) -> void:
	if body == self:
		current_state = State.LAND
