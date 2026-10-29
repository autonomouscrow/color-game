extends enemy

# 1. Added DASHING state
enum State { IDLE, JUMPING, CHASING, DASHING }
var current_state: State = State.IDLE

@export var chase_speed: float = 200.0
@export var jump_vertical_force: float = -200.0
@export var jump_horizontal_speed: float = 500.0

# Dash tuning parameters
@export var dash_speed: float = 450.0       # Speed of the retreat dash
@export var dash_duration: float = 0.35     # How long the dash lasts in seconds
@export var bounce_force: float = -250.0    # Little hop so it doesn't get stuck on floor friction

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: Node2D = null
var has_left_ground: bool = false
var dash_timer: float = 0.0

@onready var detection_area: Area2D = $DetectionArea


func _physics_process(delta: float) -> void:
	# 1. Apply gravity when active
	if current_state != State.IDLE:
		if not is_on_floor():
			velocity.y += gravity * delta

	# 2. State behavior
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO

		State.JUMPING:
			if not is_on_floor():
				has_left_ground = true
			elif has_left_ground and is_on_floor():
				current_state = State.CHASING

		State.CHASING:
			if player:
				var direction = sign(player.global_position.x - global_position.x)
				velocity.x = direction * chase_speed
			else:
				velocity.x = move_toward(velocity.x, 0, chase_speed * delta)

		State.DASHING:
			dash_timer -= delta
			# Once dash expires, resume chasing if player exists
			if dash_timer <= 0.0:
				current_state = State.CHASING

	move_and_slide()


func start_dash_away(from_body: Node2D) -> void:
	current_state = State.DASHING
	dash_timer = dash_duration

	# Calculate direction away from the body that collided with it
	var dash_dir = sign(global_position.x - from_body.global_position.x)
	# If directly on top/bottom aligned (x difference is 0), pick a direction at random
	if dash_dir == 0:
		dash_dir = 1 if randf() > 0.5 else -1

	velocity.x = dash_dir * dash_speed
	velocity.y = bounce_force # Small hop to dislodge from player/floor collisions


func _on_head_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		start_dash_away(body)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if current_state == State.IDLE and body.is_in_group("Player"):
		player = body
		start_jump()


func start_jump() -> void:
	current_state = State.JUMPING
	has_left_ground = not is_on_floor()

	var direction = sign(player.global_position.x - global_position.x)
	if direction == 0:
		direction = 1

	velocity.y = jump_vertical_force
	velocity.x = direction * jump_horizontal_speed


func _on_hitbox_2_body_entered(body: Node2D) -> void:
	if body.has_method("GetDamaged"):
		body.GetDamaged(20)
	var push_dir = sign(body.global_position.x - global_position.x)
	var knockback = Vector2(push_dir * 500.0, -500.0)
	
	if body.has_method("SetKnockback"):
		body.SetKnockback(knockback)
