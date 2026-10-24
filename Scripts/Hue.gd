extends CharacterBody2D

@export var speed := 300.0
@export var dash_speed := 600.0
@export var dash_slowdown_time := 0.2
@export var dash_turn_time := 0.3

var dashing := false
var dash_direction := 1.0

func _physics_process(delta: float) -> void:
	var direction := signf(Input.get_axis("move_left", "move_right"))
	var dash_held := Input.is_action_pressed("dash")

	# Start a dash, or snap back to full dash speed if C is pressed again mid-slowdown
	if dash_held and direction != 0 and not dashing:
		dashing = true
		dash_direction = direction
		velocity.x = dash_direction * dash_speed
	elif Input.is_action_just_pressed("dash") and dashing:
		if direction != 0:
			dash_direction = direction
		velocity.x = dash_direction * dash_speed

	if dashing and dash_held:
		# Keep dashing with no arrows held; pressing the other way turns around over dash_turn_time
		var target_direction := direction if direction != 0 else dash_direction
		velocity.x = move_toward(velocity.x, target_direction * dash_speed, 2 * dash_speed / dash_turn_time * delta)
		if signf(velocity.x) == target_direction:
			dash_direction = target_direction
	elif dashing:
		# C released: slow to walking speed, or to a stop if no arrows are held, over dash_slowdown_time
		var target_speed := direction * speed
		var slowdown_rate := (dash_speed - absf(target_speed)) / dash_slowdown_time
		velocity.x = move_toward(velocity.x, target_speed, slowdown_rate * delta)
		if velocity.x == target_speed:
			dashing = false
	else:
		velocity.x = direction * speed
	move_and_slide()
