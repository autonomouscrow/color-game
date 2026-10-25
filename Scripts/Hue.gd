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

@export_group("Punch Attack")
@export var punch_scene: PackedScene = preload("res://Scenes/Prefabs/PunchAttack.tscn")
## Full size of the punch hitbox
@export var punch_size := Vector2(53, 48)
## Where the punch starts when facing right: x is the edge nearest Hue, y is the punch's vertical center (mirrored when facing left)
@export var punch_offset := Vector2(12, -3)
## Seconds for the punch to extend out to full size
@export var punch_extend_time := 0.05
## Seconds the punch stays at full size before disappearing
@export var punch_hold_time := 0.05
@export var punch_damage := 15.0
## Seconds after punching or uppercutting before S can attack again
@export var punch_cooldown := 0.1

@export_group("Uppercut Attack")
@export var uppercut_scene: PackedScene = preload("res://Scenes/Prefabs/UppercutAttack.tscn")
## Full size of the uppercut hitbox; it sits centered on top of Hue and extends upward
@export var uppercut_size := Vector2(53, 48)
## Seconds for the uppercut to extend up to full size
@export var uppercut_extend_time := 0.05
## Seconds the uppercut stays at full size before disappearing
@export var uppercut_hold_time := 0.05
@export var uppercut_damage := 15.0

@export_group("Slide Attack")
@export var slide_hitbox_scene: PackedScene = preload("res://Scenes/Prefabs/SlideAttack.tscn")
## Pixels the slide hitbox reaches past the front half of Hue on every side
@export var slide_hitbox_margin := 5.0
## Slide damage is this times Hue's speed when it hits, divided by walking speed
@export var slide_damage := 10.0

@export_group("Slam Attack")
@export var slam_hitbox_scene: PackedScene = preload("res://Scenes/Prefabs/SlamAttack.tscn")
## Fraction of Hue's height, from the bottom, that a straight-down slam's hitbox covers
@export var slam_hitbox_fraction := 0.25
## Pixels the slam hitbox reaches past that part of Hue on every side
@export var slam_hitbox_margin := 5.0
@export var slam_damage := 20.0

@export_group("Dive Attack")
@export var dive_hitbox_scene: PackedScene = preload("res://Scenes/Prefabs/DiveAttack.tscn")
## Side length of the square dive hitbox, which is turned 45 degrees and centered on Hue's lower front corner
@export var dive_hitbox_size := 32.0
@export var dive_damage := 20.0

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
var sliding := false:
	set(value):
		sliding = value
		# The slide hitbox goes away the moment the slide ends, however it ends
		if not sliding:
			_remove_hitbox(slide_hitbox)
			_remove_hitbox(slam_hitbox)
			_remove_hitbox(dive_hitbox)
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
## 1 when facing right, -1 when facing left; punches go this way
var facing := 1.0
var punch_cooldown_timer := 0.0
var current_punch: Node2D
var slide_hitbox: Node2D
var slam_hitbox: Node2D
var dive_hitbox: Node2D
## Which way the dive hitbox's corner faces: the direction of horizontal movement when the dive started
var dive_direction := 1.0

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
	if direction != 0:
		facing = direction
	punch_cooldown_timer -= delta
	if Input.is_action_just_pressed("punch") and punch_cooldown_timer <= 0:
		if Input.is_action_pressed("move_up"):
			_uppercut()
		else:
			_punch()
	var dash_held := Input.is_action_pressed("dash")
	if not dash_held:
		dash_locked = false

	var crisis_held := Input.is_action_pressed("crisis")
	if not crisis_held:
		crisis_locked = false
	var other_input := direction != 0 or dash_held or Input.is_action_pressed("jump") or Input.is_action_pressed("slide") or Input.is_action_pressed("punch")
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
			# The dive hitbox ends on landing, unless C is held into the slide: then it lasts until the slide hitbox appears
			if not Input.is_action_pressed("slide"):
				_remove_hitbox(dive_hitbox)
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
			# Straight down is a slam; with sideways speed it's a dive
			if velocity.x == 0:
				slam_hitbox = slam_hitbox_scene.instantiate()
				slam_hitbox.damage = slam_damage
				add_child(slam_hitbox)
			else:
				dive_direction = signf(velocity.x)
				dive_hitbox = dive_hitbox_scene.instantiate()
				dive_hitbox.damage = dive_damage
				add_child(dive_hitbox)
			_update_attack_hitboxes()
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

func _punch() -> void:
	punch_cooldown_timer = punch_cooldown
	# Only one punch at a time: a new punch replaces one that's still out
	if is_instance_valid(current_punch):
		current_punch.queue_free()
	var punch := punch_scene.instantiate()
	punch.size = punch_size
	punch.extend_time = punch_extend_time
	punch.hold_time = punch_hold_time
	punch.direction = Vector2(facing, 0)
	punch.damage = punch_damage
	punch.position = Vector2(facing * punch_offset.x, punch_offset.y)
	add_child(punch)
	current_punch = punch

func _uppercut() -> void:
	# Shares the punch's cooldown, and replaces a punch or uppercut that's still out
	punch_cooldown_timer = punch_cooldown
	if is_instance_valid(current_punch):
		current_punch.queue_free()
	var uppercut := uppercut_scene.instantiate()
	uppercut.size = uppercut_size
	uppercut.extend_time = uppercut_extend_time
	uppercut.hold_time = uppercut_hold_time
	uppercut.direction = Vector2.UP
	uppercut.damage = uppercut_damage
	# Starts from Hue's top edge, even when Hue is squished
	uppercut.position = Vector2(hitbox.position.x, hitbox.position.y - hitbox_shape.size.y / 2)
	add_child(uppercut)
	current_punch = uppercut

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
	_update_attack_hitboxes()

func _update_attack_hitboxes() -> void:
	var size := hitbox_shape.size
	# Slide hitbox: spawns once Hue is fully squished into a slide (not a squat), then follows its shape until the slide ends
	if sliding and not is_instance_valid(slide_hitbox) and squish == 1 and not squatting and squat_amount == 0:
		slide_hitbox = slide_hitbox_scene.instantiate()
		add_child(slide_hitbox)
	if is_instance_valid(slide_hitbox):
		var half := Vector2(size.x / 2, size.y) + Vector2.ONE * slide_hitbox_margin * 2
		# Front half of Hue's hitbox: from its center to the edge in the slide direction, plus the margin all around
		var front_center := hitbox.position + Vector2(slide_direction * size.x / 4, 0)
		slide_hitbox.set_rect(Rect2(front_center - half / 2, half))
		# Faster slides hit harder; the damage is whatever the speed is when the enemy is touched
		slide_hitbox.damage = slide_damage * absf(velocity.x) / speed
		_remove_hitbox(dive_hitbox)
	# Slam hitbox: the bottom part of Hue plus the margin, at full size right away, until the squat is fully squished
	if is_instance_valid(slam_hitbox):
		if sliding and squish == 1:
			_remove_hitbox(slam_hitbox)
		else:
			var bottom_size := Vector2(size.x, size.y * slam_hitbox_fraction) + Vector2.ONE * slam_hitbox_margin * 2
			var bottom := hitbox.position.y + size.y / 2 + slam_hitbox_margin
			slam_hitbox.set_rect(Rect2(hitbox.position.x - bottom_size.x / 2, bottom - bottom_size.y, bottom_size.x, bottom_size.y))
	# Dive hitbox: a turned square centered on Hue's lower front corner
	if is_instance_valid(dive_hitbox):
		dive_hitbox.position = hitbox.position + Vector2(dive_direction * size.x / 2, size.y / 2)
		dive_hitbox.set_rect(Rect2(-Vector2.ONE * dive_hitbox_size / 2, Vector2.ONE * dive_hitbox_size))

# Untyped so it also takes hitboxes that are already freed, which a Node2D parameter rejects
func _remove_hitbox(attack_hitbox) -> void:
	if is_instance_valid(attack_hitbox):
		attack_hitbox.queue_free()

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
