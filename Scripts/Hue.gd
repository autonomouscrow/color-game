extends CharacterBody2D

@export_group("Walk")
@export var speed := 300.0

@export_group("Dash")
@export var dash_speed := 600.0
@export var dash_slowdown_time := 0.2
@export var dash_turn_time := 0.3

@export_group("Slide")
@export var slide_friction := 200.0
@export var slide_min_speed := 450.0
## Friction never slows a slide below this; letting go of the arrows still stops it
@export var slide_lowest_speed := 150.0
## Hue's size while fully squished into a slide, as a fraction of its normal width and height
@export var slide_squish_scale := Vector2(2.0, 0.5)
@export var slide_squish_time := 0.1
@export var slide_stop_time := 0.1

@export_group("Jump")
@export var gravity := 1800.0
@export var max_fall_speed := 1000.0
@export var jump_velocity := 800.0
## Upward speed is multiplied by this when A is released early, for shorter hops
@export var jump_release_cut := 0.5
## Seconds after walking off a ledge that A still jumps
@export var coyote_time := 0.1
## Seconds before landing that an A press is remembered and jumps on touchdown
@export var jump_buffer_time := 0.1
## Seconds to unsquish when jumping out of a slide with A
@export var slide_jump_unsquish_time := 0.05

@export_group("Slam")
## Downward speed of the mid-air C slam
@export var slam_speed := 2000.0
## Seconds to squish into a slide when a slam hits the ground
@export var slam_squish_time := 0.05
## Hue's size while squatting after a straight-down slam, as a fraction of its normal width and height
@export var squat_scale := Vector2(1.0, 0.5)
## Seconds a straight-down slam stays squished before standing up, if no other input cuts it short
@export var squat_hold_time := 0.2
## Seconds for a squat to stretch forward into a slide when left or right is held
@export var squat_to_slide_time := 0.1

@export_group("Mental Health Crisis")
## Seconds of holding Z for the first MP; each MP after takes crisis_mp_interval_factor times as long as the last
@export var crisis_first_mp_time := 1.5
@export var crisis_mp_interval_factor := 0.5
## Hue's size while in a crisis, as a fraction of its normal width and height
@export var crisis_shrink_scale := Vector2(0.8, 0.6)
## Seconds to shrink when a crisis starts, and to grow back when it ends
@export var crisis_shrink_time := 0.1
## Seconds into the crisis that Hue explodes
@export var crisis_explode_time := 2.999
@export_subgroup("Shake")
## Seconds into the crisis that Hue starts shaking
@export var crisis_shake_start_time := 0.5
## Higher values keep the shaking gentle for longer before it ramps up near the explosion
@export var crisis_shake_ramp := 2.0
## Seconds between shake jumps when shaking starts; shrinks to one jump per frame by the explosion
@export var crisis_shake_start_interval := 0.15
## How far the color rectangle can jump from the hitbox by the explosion, in multiples of Hue's size
@export var crisis_shake_max_distance := 1.5

@export_group("Display")
## Color the true hitbox is drawn in, underneath the white color rectangle
@export var hitbox_color := Color(0.6, 0.2, 1.0, 0.4)

@export_group("Stats")
@export var max_health := 100.0:
	set(value):
		max_health = maxf(value, 0.0)
		health = minf(health, max_health)
@export var health := 100.0:
	set(value):
		health = clampf(value, 0.0, max_health)
@export var max_mp := 80:
	set(value):
		max_mp = maxi(value, 0)
		mp = mini(mp, max_mp)
@export var mp := 0:
	set(value):
		mp = clampi(value, 0, max_mp)

@export_group("Debug")
## Q/W raise/lower health and E/R raise/lower MP while held, for testing the HUD
@export var debug_stat_keys := true
## Health per second gained or lost while Q or W is held
@export var debug_health_rate := 50.0
## Seconds between each MP point gained or lost while E or R is held
@export var debug_mp_interval := 0.3
@export_group("")

@onready var hitbox: CollisionShape2D = $Hitbox
@onready var color_rect: ColorRect = $Color

var dashing := false
var dash_locked := false
var dash_direction := 1.0
var sliding := false
var slide_direction := 1.0
var slide_stopping := false
var slide_stop_rate := 0.0
var slide_squish_duration := 0.1
var slamming := false
## True for a slam that landed with no sideways speed: Hue squats to half height without widening
var squatting := false
var squat_timer := 0.0
## How far Hue's squished shape is toward squat_scale (1) rather than slide_squish_scale (0)
var squat_amount := 0.0
var squish := 0.0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var hitbox_shape: RectangleShape2D
var stand_size: Vector2
var debug_mp_timer := 0.0
var in_crisis := false
## Z has to be released and pressed again after a crisis ends
var crisis_locked := false
var crisis_time := 0.0
var crisis_next_mp_time := 0.0
var crisis_mp_interval := 0.0
var shake_timer := 0.0
var shake_offset := Vector2.ZERO
## Extra glitching copies of the color rectangle, one per MP gained this crisis
var crisis_copies: Array[ColorRect] = []
## 0 is normal size, 1 is fully shrunk into crisis_shrink_scale
var crisis_shrink := 0.0
var exploded := false

func _ready() -> void:
	# Own copy of the shape so resizing it doesn't affect other Hue instances
	hitbox_shape = hitbox.shape.duplicate()
	hitbox.shape = hitbox_shape
	stand_size = hitbox_shape.size

func _physics_process(delta: float) -> void:
	if debug_stat_keys:
		_debug_stats(delta)
	queue_redraw()
	if exploded:
		# Raising health again (Q debug key) brings Hue back
		if health > 0:
			exploded = false
			color_rect.visible = true
			crisis_locked = Input.is_action_pressed("crisis")
		return
	var direction := signf(Input.get_axis("move_left", "move_right"))
	var dash_held := Input.is_action_pressed("dash")
	if not dash_held:
		dash_locked = false

	var crisis_held := Input.is_action_pressed("crisis")
	if not crisis_held:
		crisis_locked = false
	var other_input := direction != 0 or dash_held or Input.is_action_pressed("jump") or Input.is_action_pressed("slide")
	if in_crisis and (not crisis_held or other_input or not is_on_floor()):
		# Any other input breaks out of the crisis and then does its normal thing below
		_end_crisis()
	elif not in_crisis and crisis_held and not crisis_locked and not other_input and is_on_floor() and not sliding and not slamming and squish == 0:
		in_crisis = true
		dashing = false
		crisis_time = 0.0
		crisis_mp_interval = crisis_first_mp_time
		crisis_next_mp_time = crisis_first_mp_time
		shake_timer = 0.0
	if in_crisis:
		velocity.x = 0
		crisis_shrink = move_toward(crisis_shrink, 1, delta / crisis_shrink_time)
		_apply_squish()
		_crisis(delta)
		move_and_slide()
		return
	elif crisis_shrink > 0:
		crisis_shrink = move_toward(crisis_shrink, 0, delta / crisis_shrink_time)
		_apply_squish()

	if is_on_floor():
		coyote_timer = coyote_time
		# A slam that hits the ground turns straight into a slide, keeping its horizontal speed
		if slamming:
			slamming = false
			if velocity.x != 0:
				slide_direction = signf(velocity.x)
			_start_slide(slam_squish_time)
			squatting = velocity.x == 0
			squat_amount = 1.0 if squatting else 0.0
	else:
		coyote_timer -= delta
		if slamming:
			velocity.y = slam_speed
		else:
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	# A buffered press jumps as soon as Hue is on the floor, or just walked off it
	if jump_buffer_timer > 0 and coyote_timer > 0 and not slamming:
		if sliding:
			_jump_out_of_slide(dash_held)
		velocity.y = -jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
	# Letting go of A while still rising cuts the jump short
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_release_cut

	if Input.is_action_just_pressed("slide") and not sliding:
		if is_on_floor():
			if absf(velocity.x) >= speed:
				slide_direction = signf(velocity.x)
				# Slides start at least at slide_min_speed; faster slides keep their speed
				if absf(velocity.x) < slide_min_speed:
					velocity.x = slide_direction * slide_min_speed
				_start_slide(slide_squish_time)
		elif not slamming:
			slamming = true
			dashing = false
			velocity.y = slam_speed
	if slamming:
		# No steering during a slam; horizontal speed is kept as it was
		move_and_slide()
		return
	# Finish unsquishing after jumping out of a slide
	if not sliding and squish > 0:
		squish = move_toward(squish, 0, delta / slide_jump_unsquish_time)
		_apply_squish()
	if sliding:
		_slide(direction, delta)
		move_and_slide()
		return

	# Start a dash, or snap back to full dash speed if D is pressed again mid-slowdown
	if dash_held and direction != 0 and not dashing and not dash_locked:
		dashing = true
		dash_direction = direction
		velocity.x = dash_direction * dash_speed
	elif Input.is_action_just_pressed("dash") and dashing:
		if direction != 0:
			dash_direction = direction
		velocity.x = dash_direction * dash_speed

	if dashing and dash_held and not dash_locked:
		# Keep dashing with no arrows held; pressing the other way turns around over dash_turn_time
		var target_direction := direction if direction != 0 else dash_direction
		velocity.x = move_toward(velocity.x, target_direction * dash_speed, 2 * dash_speed / dash_turn_time * delta)
		if signf(velocity.x) == target_direction:
			dash_direction = target_direction
	elif dashing:
		# D released: slow to walking speed, or to a stop if no arrows are held, over dash_slowdown_time
		var target_speed := direction * speed
		var slowdown_rate := (dash_speed - absf(target_speed)) / dash_slowdown_time
		velocity.x = move_toward(velocity.x, target_speed, slowdown_rate * delta)
		if velocity.x == target_speed:
			dashing = false
	else:
		velocity.x = direction * speed
	move_and_slide()

func _start_slide(squish_time: float) -> void:
	sliding = true
	slide_stopping = false
	slide_squish_duration = squish_time
	squatting = false
	squat_timer = 0.0
	squat_amount = 0.0
	dashing = false

func _jump_out_of_slide(dash_held: bool) -> void:
	sliding = false
	# Leftover slide speed above walking speed eases off like the end of a dash; D held through the slide doesn't dash
	if absf(velocity.x) > speed:
		dashing = true
		dash_direction = signf(velocity.x)
		dash_locked = dash_held

func _slide(direction: float, delta: float) -> void:
	if squatting:
		# D during a squat stands Hue straight up and hands control back (A is handled by the jump)
		if Input.is_action_just_pressed("dash"):
			sliding = false
			return
		if direction != 0:
			# Left or right turns the squat into a slowest-speed slide that way; the shape stretches forward below
			squatting = false
			slide_stopping = false
			slide_direction = direction
			slide_squish_duration = squat_to_slide_time
			velocity.x = direction * slide_lowest_speed
		# Otherwise squish all the way down, hold for squat_hold_time, then stand up over slide_squish_time
		elif not slide_stopping:
			squish = move_toward(squish, 1, delta / slide_squish_duration)
			if squish == 1:
				squat_timer += delta
				if squat_timer >= squat_hold_time:
					slide_stopping = true
					slide_stop_rate = 0.0
			_apply_squish()
			return
	else:
		squat_amount = move_toward(squat_amount, 0, delta / squat_to_slide_time)
	# Letting go of the arrows or running out of speed ends the slide: stop over slide_stop_time and unsquish
	if (direction == 0 or velocity.x == 0) and not slide_stopping:
		slide_stopping = true
		slide_stop_rate = absf(velocity.x) / slide_stop_time
	if slide_stopping:
		velocity.x = move_toward(velocity.x, 0, slide_stop_rate * delta)
		squish = move_toward(squish, 0, delta / slide_squish_time)
		if velocity.x == 0 and squish == 0:
			sliding = false
			# D held through the slide doesn't dash on getting up; it has to be pressed again
			dash_locked = Input.is_action_pressed("dash")
	else:
		velocity.x = move_toward(velocity.x, slide_direction * slide_lowest_speed, slide_friction * delta)
		squish = move_toward(squish, 1, delta / slide_squish_duration)
	_apply_squish()

func _apply_squish() -> void:
	var squish_scale := slide_squish_scale.lerp(squat_scale, squat_amount)
	var squish_size := stand_size * Vector2.ONE.lerp(squish_scale, squish)
	var size := squish_size * Vector2.ONE.lerp(crisis_shrink_scale, crisis_shrink)
	hitbox_shape.size = size
	# Keep the bottom edge in place so Hue squishes down instead of shrinking toward its center
	hitbox.position.y = (stand_size.y - size.y) / 2
	# Keep the back edge in place so Hue only stretches forward, and pulls the front back when getting up
	# (the crisis shrink stays centered)
	hitbox.position.x = slide_direction * (squish_size.x - stand_size.x) / 2
	color_rect.size = size
	color_rect.position = hitbox.position - size / 2 + shake_offset

func _draw() -> void:
	if not exploded:
		draw_rect(Rect2(hitbox.position - hitbox_shape.size / 2, hitbox_shape.size), hitbox_color)

func _crisis(delta: float) -> void:
	crisis_time += delta
	# MP comes in faster and faster: 1.5s, then 0.75s more, then 0.375s more...
	while crisis_time >= crisis_next_mp_time and crisis_next_mp_time < crisis_explode_time and crisis_mp_interval > 0:
		mp += 1
		_add_crisis_copy()
		crisis_mp_interval *= crisis_mp_interval_factor
		crisis_next_mp_time += crisis_mp_interval
	if crisis_time >= crisis_explode_time:
		_explode()
		return
	if crisis_time >= crisis_shake_start_time:
		# Shake jumps get more frequent and farther apart as the explosion nears
		var progress := pow(inverse_lerp(crisis_shake_start_time, crisis_explode_time, crisis_time), crisis_shake_ramp)
		shake_timer -= delta
		if shake_timer <= 0:
			shake_timer = lerpf(crisis_shake_start_interval, 0.0, progress)
			var reach := stand_size * crisis_shake_max_distance * progress
			shake_offset = Vector2(randf_range(-reach.x, reach.x), randf_range(-reach.y, reach.y))
			_apply_squish()
			# Each copy jumps to its own spot around the hitbox
			for copy in crisis_copies:
				var copy_offset := Vector2(randf_range(-reach.x, reach.x), randf_range(-reach.y, reach.y))
				copy.position = hitbox.position - copy.size / 2 + copy_offset

func _add_crisis_copy() -> void:
	var copy := ColorRect.new()
	copy.color = color_rect.color
	copy.size = color_rect.size
	copy.position = color_rect.position
	add_child(copy)
	crisis_copies.append(copy)

func _end_crisis() -> void:
	in_crisis = false
	crisis_locked = Input.is_action_pressed("crisis")
	shake_offset = Vector2.ZERO
	for copy in crisis_copies:
		copy.queue_free()
	crisis_copies.clear()
	_apply_squish()

func _explode() -> void:
	_end_crisis()
	exploded = true
	crisis_shrink = 0.0
	_apply_squish()
	health = 0
	velocity = Vector2.ZERO
	# Hue simply vanishes; _draw stops drawing the hitbox too
	color_rect.visible = false

func _debug_stats(delta: float) -> void:
	var health_direction := float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_W))
	health += health_direction * debug_health_rate * delta
	var mp_direction := int(Input.is_physical_key_pressed(KEY_E)) - int(Input.is_physical_key_pressed(KEY_R))
	if mp_direction == 0:
		debug_mp_timer = 0.0
		return
	# Change by one point right away on press, then once every debug_mp_interval while held
	debug_mp_timer -= delta
	if debug_mp_timer <= 0.0:
		mp += mp_direction
		debug_mp_timer = debug_mp_interval
