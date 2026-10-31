extends enemy

enum State { RUNNING, JUMPING, COOLDOWN }

@export_group("Movement Settings")
@export var run_speed: float = 600.0
@export var patrol_direction: int = 1 # 1 = right, -1 = left

@export_group("Jump Settings")
@export var jump_velocity: float = -600.0      # Upward jump force (negative is up)
@export var jump_forward_speed: float = 600.0   # Horizontal speed while leaping over the player
@export var jump_cooldown_time: float = 0.8    # Prevents immediately jumping again upon landing

var current_state: State = State.RUNNING
var player_target: Node2D = null

@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox_shape: CollisionShape2D = $Hitbox2/Hitbox

var kunai = preload("res://Scenes/Prefabs/kunai.tscn")

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	# Keep the hitbox enabled if you want it to hurt the player on contact
	hitbox_shape.disabled = false 

func _physics_process(delta: float) -> void:
	if velocity.x >= 0:
		$AnimatedSprite2D.flip_h = false
	else:
		$AnimatedSprite2D.flip_h = true
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.RUNNING:
			_process_running()
			_check_for_player_jump()

		State.JUMPING:
			_process_jumping()

		State.COOLDOWN:
			# Continue running normally, but temporarily prevent another jump
			_process_running()

	move_and_slide()


func _process_running() -> void:
	# Reverse direction if hitting a wall
	if is_on_wall():
		patrol_direction *= -1

	velocity.x = patrol_direction * run_speed


func _check_for_player_jump() -> void:
	if not can_see(player_target) or not is_on_floor():
		return

	# Determine if the player is in the direction the enemy is running
	var dir_to_player: float = sign(player_target.global_position.x - global_position.x)

	# Only jump if the player is in front of the enemy (or directly aligned)
	if dir_to_player == patrol_direction or dir_to_player == 0:
		_start_jump()


func _start_jump() -> void:
	current_state = State.JUMPING
	velocity.y = jump_velocity
	velocity.x = patrol_direction * jump_forward_speed
	await get_tree().create_timer(0.1, false).timeout
	throw(Vector2(1*patrol_direction, 1))
	await get_tree().create_timer(0.1, false).timeout
	throw(Vector2(0, 1))
	await get_tree().create_timer(0.1, false).timeout
	throw(Vector2(-1*patrol_direction, 1))
	


func _process_jumping() -> void:
	# If hitting a wall mid-air, bounce off it
	if is_on_wall():
		patrol_direction *= -1
		velocity.x = patrol_direction * jump_forward_speed

	# Check if the enemy has landed (moving downward or stationary and touching floor)
	if velocity.y >= 0 and is_on_floor():
		_end_jump()


func _end_jump() -> void:
	current_state = State.COOLDOWN
	
	# Wait for cooldown before allowing another jump
	await get_tree().create_timer(jump_cooldown_time, false).timeout
	
	# Only return to RUNNING if we are still in COOLDOWN
	if current_state == State.COOLDOWN:
		current_state = State.RUNNING


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_target = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_target:
		player_target = null



## False for a missing player, or one hidden in a matching color zone
func can_see(body: Node2D) -> bool:
	return is_instance_valid(body) and not (body.has_method("is_hidden") and body.is_hidden())

func _on_hitbox_2_body_entered(body: Node2D) -> void:
	if body.has_method("GetDamaged"):
		body.GetDamaged(20)
	var push_dir = sign(body.global_position.x - global_position.x)
	var knockback = Vector2(push_dir * 500.0, -500.0)
	
	if body.has_method("SetKnockback"):
				body.SetKnockback(knockback)

func throw(direction: Vector2) -> void:
	var knife = kunai.instantiate()
	
	knife.global_position = global_position
	knife.rotation = direction.angle()
	get_tree().current_scene.add_child(knife)
