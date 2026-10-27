extends enemy

## IDLE: patrols until it sees the player. CHASE: runs at the player while the jump is on cooldown or the player is out of JumpArea.
## JUMP: leaps toward the player. DIVE: shoots down at the player at dive_angle. LAND: falls back to the floor after a dive or a parry bounce.
enum State { IDLE, CHASE, JUMP, DIVE, LAND }
var current_state: State = State.IDLE

@export_group("Idle")
## Total width of the side to side patrol while the player is out of DetectionArea
@export var idle_patrol_width := 30.0
@export var idle_speed := 10.0

@export_group("Chase")
@export var chase_speed := 200.0

@export_group("Jump")
## Upward launch speed is the player's jump_velocity times this
@export var jump_velocity_multiplier := 1.5
## Used instead of the player's jump_velocity if the player doesn't have one
@export var fallback_jump_velocity := 800.0
@export var jump_horizontal_speed := 400.0
## Seconds from the start of one jump until the next one can start; the Diver chases in between
@export var jump_cooldown := 3.0

@export_group("Dive")
## The dive starts at this speed and speeds up by dive_acceleration every second, like falling; gravity itself is off during the dive
@export var dive_start_speed := 800.0
@export var dive_acceleration := 1800.0
## Top speed of the dive; 0 means no limit
@export var dive_max_speed := 0.0
## Degrees below horizontal
@export var dive_angle := 45.0
## The dive starts once the Diver is at least this far above the player's head, and high enough that dive_angle lands where
## the player will be by the time the dive gets there, assuming they run away from the Diver at their walking speed
@export var min_dive_height := 64.0
## Used instead of the player's speed (walking speed) if the player doesn't have one
@export var fallback_player_speed := 300.0
@export var dive_damage := 20
@export var dive_knockback := Vector2(500, -500)

@export_group("Parry")
## A dive is parried when it hits the player within this many seconds of their uppercut reaching full size
@export var parry_window := 0.1
## Extra damage the Diver takes from a parry, as a multiple of the player's uppercut_damage; added on top of the uppercut's own hit
@export var parry_damage_multiplier := 2.0
## Used instead of the player's uppercut_damage if the player doesn't have one
@export var fallback_uppercut_damage := 15.0
## Speed the Diver bounces away at: x away from the player, y upward
@export var parry_bounce := Vector2(300, 700)

@export_group("Recoil")
## Speed the Diver hops off at after its dive hits the player, or whenever it lands on or bumps into them, so it never stands on their head.
## x carries on in the direction it was already going, y is upward
@export var recoil := Vector2(250, 500)

@export_group("Contact")
## Damage from touching the Diver outside a dive
@export var contact_damage := 10
@export var contact_knockback := Vector2(500, -500)

@export_group("Physics")
@export var gravity := 1800.0
@export var max_fall_speed := 1000.0

## The player in DetectionArea that the Diver can see; null while they're hidden in a color zone
var player: Node2D = null
## The player in DetectionArea, seen or not
var detected_player: Node2D = null
var idle_center := Vector2.ZERO
var idle_dir := 1.0
var in_jump_area := false
var dive_dir := 1.0
var dive_speed := 0.0

@onready var jump_timer: Timer = $JumpTimer
@onready var contact_area: Area2D = $Area2D

func _ready() -> void:
	idle_center = global_position

func _physics_process(delta: float) -> void:
	var seen_player: Node2D = detected_player if can_see(detected_player) else null
	if seen_player != player:
		player = seen_player
		# A jump, dive or landing already under way finishes first
		if current_state == State.IDLE or current_state == State.CHASE:
			_ground_state()

	match current_state:
		State.IDLE:
			velocity.x = idle_dir * idle_speed
			var offset := global_position.x - idle_center.x
			if (offset >= idle_patrol_width / 2 and idle_dir > 0) or (offset <= -idle_patrol_width / 2 and idle_dir < 0) or is_on_wall():
				idle_dir = -idle_dir

		State.CHASE:
			velocity.x = _side_to_player() * chase_speed
			if in_jump_area and jump_timer.is_stopped() and is_on_floor():
				_jump()

		State.JUMP:
			# Dives once dive_angle from here lands on the player, or at the top of the jump if it never lines up
			if is_instance_valid(player):
				var to_target := _predicted_target() - global_position
				var height_needed := maxf(absf(to_target.x) * tan(deg_to_rad(dive_angle)), min_dive_height)
				if to_target.y >= height_needed or velocity.y >= 0:
					_dive(to_target.x)
			elif velocity.y >= 0:
				current_state = State.LAND

		State.DIVE:
			dive_speed += dive_acceleration * delta
			if dive_max_speed > 0:
				dive_speed = minf(dive_speed, dive_max_speed)
			var angle := deg_to_rad(dive_angle)
			velocity = Vector2(dive_dir * cos(angle), sin(angle)) * dive_speed

		State.LAND:
			if is_on_floor():
				velocity.x = 0.0
				_ground_state()

	if current_state != State.DIVE and not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	# Bumping into the player stops the Diver, so remember which way it was going first
	var heading := signf(velocity.x)
	move_and_slide()

	if current_state == State.DIVE:
		var hit_player := _touching_player()
		if hit_player:
			_dive_hit(hit_player)
		elif is_on_floor() or is_on_wall() or is_on_ceiling():
			current_state = State.LAND
	else:
		var bumped := _bumped_player()
		if bumped:
			_hop_off(heading if heading != 0 else signf(global_position.x - bumped.global_position.x))

func _ground_state() -> void:
	if player:
		current_state = State.CHASE
	else:
		idle_center = global_position
		current_state = State.IDLE

func _jump() -> void:
	var launch: float = player.get("jump_velocity") if player.get("jump_velocity") != null else fallback_jump_velocity
	velocity = Vector2(_side_to_player() * jump_horizontal_speed, -launch * jump_velocity_multiplier)
	jump_timer.start(jump_cooldown)
	current_state = State.JUMP

## to_target_x: horizontal offset to the predicted landing point; a jump that carries the Diver past it dives back the other way
func _dive(to_target_x: float) -> void:
	dive_dir = signf(to_target_x)
	if dive_dir == 0:
		dive_dir = _side_to_player()
	dive_speed = dive_start_speed
	var angle := deg_to_rad(dive_angle)
	velocity = Vector2(dive_dir * cos(angle), sin(angle)) * dive_speed
	current_state = State.DIVE

## Where the top of the player's head will be when a dive started now reaches it, if they run straight away from the Diver at walking speed
func _predicted_target() -> Vector2:
	var head := _player_head()
	var drop := head.y - global_position.y
	if drop <= 0:
		return head
	var run_speed: float = player.get("speed") if player.get("speed") != null else fallback_player_speed
	var away := 1.0 if head.x >= global_position.x else -1.0
	var path := drop / sin(deg_to_rad(dive_angle))
	return head + Vector2(away * run_speed * _dive_time(path), 0)

## Seconds for the dive to cover distance, starting at dive_start_speed and speeding up by dive_acceleration
func _dive_time(distance: float) -> float:
	var v0 := dive_start_speed
	var a := dive_acceleration
	var time := distance / maxf(v0, 1.0) if a <= 0 else (-v0 + sqrt(v0 * v0 + 2 * a * distance)) / a
	if dive_max_speed > 0 and a > 0 and dive_max_speed > v0:
		# Past top speed, the rest of the way is covered at a constant speed
		var accel_time := (dive_max_speed - v0) / a
		var accel_distance := v0 * accel_time + a * accel_time * accel_time / 2
		if distance > accel_distance:
			time = accel_time + (distance - accel_distance) / dive_max_speed
	return time

func _dive_hit(body: Node2D) -> void:
	if body.has_method("parried_within") and body.parried_within(parry_window):
		var uppercut_damage: float = body.get("uppercut_damage") if body.get("uppercut_damage") != null else fallback_uppercut_damage
		var health_before := health
		velocity = Vector2(-dive_dir * parry_bounce.x, -parry_bounce.y)
		current_state = State.LAND
		take_damage(uppercut_damage * parry_damage_multiplier)
		# A parry that kills counts as an attack kill, so the player still gains MP
		if health_before > 0 and health <= 0 and body.has_method("on_attack_kill"):
			body.on_attack_kill()
		return
	_hurt(body, dive_damage, dive_knockback)
	_hop_off(dive_dir)

## Hops up and onward in direction (-1 or 1), then falls back to the floor
func _hop_off(direction: float) -> void:
	if direction == 0:
		direction = idle_dir
	velocity = Vector2(direction * recoil.x, -recoil.y)
	current_state = State.LAND

## The player if the Diver ran into or landed on them during this frame's move
func _bumped_player() -> Node2D:
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider is Node2D and collider.is_in_group("Player"):
			return collider
	return null

func _hurt(body: Node2D, damage: int, knockback: Vector2) -> void:
	var push_dir := signf(body.global_position.x - global_position.x)
	if push_dir == 0:
		push_dir = 1.0
	if body.has_method("SetKnockback"):
		body.SetKnockback(Vector2(push_dir * knockback.x, knockback.y))
	if body.has_method("GetDamaged"):
		body.GetDamaged(damage)

func _touching_player() -> Node2D:
	for body in contact_area.get_overlapping_bodies():
		if body.is_in_group("Player"):
			return body
	return null

## -1 or 1, toward the player's side
func _side_to_player() -> float:
	if not is_instance_valid(player):
		return idle_dir
	return 1.0 if player.global_position.x >= global_position.x else -1.0

## Top middle of the player's hitbox, which follows Hue's squish
func _player_head() -> Vector2:
	var head := player.global_position
	var hitbox = player.get("hitbox")
	var shape = player.get("hitbox_shape")
	if hitbox and shape:
		head += hitbox.position - Vector2(0, shape.size.y / 2)
	return head

func _on_detection_body_entered(body: Node2D) -> void:
	# Switching to CHASE happens in _physics_process once the player can be seen
	if body.is_in_group("Player"):
		detected_player = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body == detected_player:
		detected_player = null

func _on_jump_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		in_jump_area = true

func _on_jump_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		in_jump_area = false

func _on_area_2d_body_entered(body: Node2D) -> void:
	# A dive deals its own damage, checked every frame in _physics_process
	if body.is_in_group("Player") and current_state != State.DIVE:
		_hurt(body, contact_damage, contact_knockback)
