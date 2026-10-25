extends enemy
enum State { PATROL, WINDUP, SLIDING, COOLDOWN }

@export_group("Patrol Settings")
@export var walk_speed: float = 70.0
@export var patrol_direction: int = 1 # 1 = right, -1 = left

@export_group("Slide Settings")
@export var slide_speed: float = 600.0
@export var slide_friction: float = 300.0 
@export var windup_time: float = 0.35 
@export var cooldown_time: float = 1.0 

var current_state: State = State.PATROL
var player_target: Node2D = null
var slide_direction: float = 0.0

@onready var detection_area: Area2D = $DetectionArea
@onready var slide_hitbox: Area2D = $Hitbox2
@onready var hitbox_shape: CollisionShape2D = $Hitbox2/Hitbox

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	hitbox_shape.disabled = true 

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.PATROL:
			_process_patrol()
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0, 800 * delta)
		State.SLIDING:
			_process_slide(delta)
		State.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0, 800 * delta)

	move_and_slide()



func _process_patrol() -> void:
	# Reverse direction if hitting a wall
	if is_on_wall():
		patrol_direction *= -1

	velocity.x = patrol_direction * walk_speed

func _start_windup() -> void:
	current_state = State.WINDUP
	
	slide_direction = sign(player_target.global_position.x - global_position.x)
	if slide_direction == 0:
		slide_direction = 1


	await get_tree().create_timer(windup_time).timeout
	_start_slide()

func _start_slide() -> void:
	current_state = State.SLIDING
	velocity.x = slide_direction * slide_speed
	hitbox_shape.disabled = false # Turn on attack hitbox


func _process_slide(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, slide_friction * delta)

	if abs(velocity.x) < 30.0 or is_on_wall():
		_end_slide()

func _end_slide() -> void:
	hitbox_shape.disabled = true
	current_state = State.COOLDOWN
	
	await get_tree().create_timer(cooldown_time).timeout

	if player_target and is_instance_valid(player_target):
		_start_windup()
	else:
		current_state = State.PATROL


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and current_state == State.PATROL:
		player_target = body
		_start_windup()

	
func _on_hitbox_2_body_entered(body: Node2D) -> void:
	if body.has_method("GetDamaged"):
		body.GetDamaged(20)
	var push_dir = sign(body.global_position.x - global_position.x)
	var knockback = Vector2(push_dir * 500.0, -500.0)
	
	if body.has_method("SetKnockback"):
				body.SetKnockback(knockback)
