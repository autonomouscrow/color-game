extends CharacterBody2D

@export var speed := 300.0
@export var dash_speed := 600.0
@export var dash_slowdown_time := 0.2
@export var dash_turn_time := 0.3
@export var slide_friction := 200.0
@export var slide_min_speed := 450.0
@export var slide_squish_time := 0.1
@export var slide_stop_time := 0.1
@export var gravity := 1800.0
@export var max_fall_speed := 1000.0
@export var jump_velocity := 800.0
## Upward speed is multiplied by this when Z is released early, for shorter hops
@export var jump_release_cut := 0.5
## Seconds after walking off a ledge that Z still jumps
@export var coyote_time := 0.1
## Seconds before landing that a Z press is remembered and jumps on touchdown
@export var jump_buffer_time := 0.1

@onready var hitbox: CollisionShape2D = $Hitbox
@onready var color_rect: ColorRect = $Color

var dashing := false
var dash_locked := false
var dash_direction := 1.0
var sliding := false
var slide_direction := 1.0
var slide_stopping := false
var slide_stop_rate := 0.0
var squish := 0.0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var hitbox_shape: RectangleShape2D
var stand_size: Vector2

func _ready() -> void:
	# Own copy of the shape so resizing it doesn't affect other Hue instances
	hitbox_shape = hitbox.shape.duplicate()
	hitbox.shape = hitbox_shape
	stand_size = hitbox_shape.size

func _physics_process(delta: float) -> void:
	var direction := signf(Input.get_axis("move_left", "move_right"))
	var dash_held := Input.is_action_pressed("dash")
	if not dash_held:
		dash_locked = false

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	# A buffered press jumps as soon as Hue is on the floor, or just walked off it
	if jump_buffer_timer > 0 and coyote_timer > 0 and not sliding:
		velocity.y = -jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
	# Letting go of Z while still rising cuts the jump short
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_release_cut

	if Input.is_action_just_pressed("slide") and not sliding and is_on_floor() and absf(velocity.x) >= speed:
		sliding = true
		slide_stopping = false
		slide_direction = signf(velocity.x)
		# Slides start at least at slide_min_speed; faster slides keep their speed
		if absf(velocity.x) < slide_min_speed:
			velocity.x = slide_direction * slide_min_speed
		dashing = false
	if sliding:
		_slide(direction, delta)
		move_and_slide()
		return

	# Start a dash, or snap back to full dash speed if C is pressed again mid-slowdown
	if dash_held and direction != 0 and not dashing and not dash_locked:
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

func _slide(direction: float, delta: float) -> void:
	# Letting go of the arrows or running out of speed ends the slide: stop over slide_stop_time and unsquish
	if (direction == 0 or velocity.x == 0) and not slide_stopping:
		slide_stopping = true
		slide_stop_rate = absf(velocity.x) / slide_stop_time
	if slide_stopping:
		velocity.x = move_toward(velocity.x, 0, slide_stop_rate * delta)
		squish = move_toward(squish, 0, delta / slide_squish_time)
		if velocity.x == 0 and squish == 0:
			sliding = false
			# C held through the slide doesn't dash on getting up; it has to be pressed again
			dash_locked = Input.is_action_pressed("dash")
	else:
		velocity.x = move_toward(velocity.x, 0, slide_friction * delta)
		squish = move_toward(squish, 1, delta / slide_squish_time)
	_apply_squish()

func _apply_squish() -> void:
	var size := stand_size.lerp(Vector2(stand_size.x * 2, stand_size.y / 2), squish)
	hitbox_shape.size = size
	# Keep the bottom edge in place so Hue squishes down instead of shrinking toward its center
	hitbox.position.y = (stand_size.y - size.y) / 2
	# Keep the back edge in place so Hue only stretches forward, and pulls the front back when getting up
	hitbox.position.x = slide_direction * (size.x - stand_size.x) / 2
	color_rect.size = size
	color_rect.position = hitbox.position - size / 2
