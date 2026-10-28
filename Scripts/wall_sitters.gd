extends enemy

enum State { IDLE, JUMPING, CHASING }
var current_state: State = State.IDLE

@export var chase_speed: float = 200.0
@export var jump_vertical_force: float = -200.0
@export var jump_horizontal_speed: float = 500.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: Node2D = null
var has_left_ground: bool = false

@onready var detection_area: Area2D = $DetectionArea



func _physics_process(delta: float) -> void:
	# 1. ONLY apply gravity once it has attacked (JUMPING or CHASING)
	if current_state != State.IDLE:
		if not is_on_floor():
			velocity.y += gravity * delta

	# 2. State behavior
	match current_state:
		State.IDLE:
			# Stay completely stationary in place
			velocity = Vector2.ZERO

		State.JUMPING:
			# Track when it is in the air
			if not is_on_floor():
				has_left_ground = true
			# Once it hits the floor after being airborne, transition to chasing
			elif has_left_ground and is_on_floor():
				current_state = State.CHASING

		State.CHASING:
			if player:
				var direction = sign(player.global_position.x - global_position.x)
				velocity.x = direction * chase_speed
			else:
				velocity.x = move_toward(velocity.x, 0, chase_speed * delta)

	move_and_slide()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if current_state == State.IDLE and body.is_in_group("Player"):
		player = body
		start_jump()

func start_jump() -> void:
	current_state = State.JUMPING
	
	# If the enemy was already floating/in the air, mark it as left the ground immediately
	has_left_ground = not is_on_floor()

	# Determine horizontal direction towards the player
	var direction = sign(player.global_position.x - global_position.x)
	if direction == 0:
		direction = 1

	# Apply initial launch
	velocity.y = jump_vertical_force
	velocity.x = direction * jump_horizontal_speed

func _on_hitbox_2_body_entered(body: Node2D) -> void:
	if body.has_method("GetDamaged"):
		body.GetDamaged(20)
	var push_dir = sign(body.global_position.x - global_position.x)
	var knockback = Vector2(push_dir * 500.0, -500.0)
	
	if body.has_method("SetKnockback"):
				body.SetKnockback(knockback)
