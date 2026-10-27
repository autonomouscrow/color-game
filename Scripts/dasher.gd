extends enemy

## WANDER: flies to a random point wander_distance away in a sine wave, then picks a new one. Holds still while the player
## is outside DetectionArea.
## WINDUP: hangs in the air for windup_time before each dash. DASH: flies dash_distance toward where the player was when
## the windup ended, through the player and other enemies, and skims along walls in the way. dashes_per_attack dashes make one attack.
enum State { WANDER, WINDUP, DASH }
var current_state: State = State.WANDER

@export_group("Wander")
## How far away each new wander point is
@export var wander_distance := 200.0
## Speed along the straight line to the wander point; the sine wave sways side to side on top of this
@export var wander_speed := 100.0
## How far the sine wave sways to either side of the straight line
@export var wave_amplitude := 16.0
## Full waves on the way to each wander point
@export var waves_per_leg := 1.0
## While the player is seen but out of AggroArea, wander points are picked in a cone this many degrees wide toward them; 0 turns this off
@export_range(0, 360) var approach_cone := 90.0
## While the player is in DetectionArea and the current wander point is more than a screen height above them, the next
## wander point is picked within this many degrees of straight down
@export_range(0, 180) var return_down_angle := 45.0

@export_group("Dash")
## Seconds hanging still in the air before each dash; the dash aims at the player at the end of it
@export var windup_time := 0.5
@export var dash_distance := 1000.0
## Top speed, reached halfway through the dash; the speed eases up from 0 and back down to 0 at the end
@export var dash_peak_speed := 3000.0
@export var dashes_per_attack := 3
## Seconds from the start of one attack until the next one can start
@export var attack_cooldown := 7.0
@export var dash_damage := 10
@export var dash_knockback := Vector2(500, -500)

@export_group("Contact")
## Damage from touching the Dasher outside a dash
@export var contact_damage := 10
@export var contact_knockback := Vector2(500, -500)

## The player in DetectionArea that the Dasher can see; null while they're hidden in a color zone
var player: Node2D = null
## The player in DetectionArea, seen or not
var detected_player: Node2D = null
var in_aggro_area := false

var leg_start := Vector2.ZERO
var leg_dir := Vector2.RIGHT
var leg_length := 0.0
var leg_travelled := 0.0

var windup_left := 0.0
var dashes_left := 0
var dash_dir := Vector2.RIGHT
var dash_time := 0.0
## Distance along dash_dir the dash has planned so far; walls can make the real path shorter
var dash_planned := 0.0
## Bodies already hit by the current dash, so each one only takes damage once per dash
var dash_hits: Array[Node] = []

@onready var attack_timer: Timer = $AttackTimer
@onready var contact_area: Area2D = $Area2D

func _ready() -> void:
	_pass_through_bodies()
	_new_leg()

func _physics_process(delta: float) -> void:
	player = detected_player if can_see(detected_player) else null

	match current_state:
		State.WANDER:
			if player and in_aggro_area and attack_timer.is_stopped():
				_start_attack()
			elif not detected_player:
				velocity = Vector2.ZERO
			else:
				leg_travelled = minf(leg_travelled + wander_speed * delta, leg_length)
				var progress := leg_travelled / leg_length if leg_length > 0 else 1.0
				var sway := wave_amplitude * sin(TAU * waves_per_leg * progress)
				var target := leg_start + leg_dir * leg_travelled + leg_dir.orthogonal() * sway
				velocity = (target - global_position) / delta

		State.WINDUP:
			velocity = Vector2.ZERO
			windup_left -= delta
			if windup_left <= 0:
				# A player who hides during the attack ends it
				if player:
					_dash()
				else:
					_end_attack()

		State.DASH:
			# Speed follows peak * sin^2, so it starts and ends at 0 and averages half the peak
			dash_time += delta
			var duration := 2.0 * dash_distance / maxf(dash_peak_speed, 1.0)
			var u := minf(dash_time / duration, 1.0)
			var goal := dash_distance * (u - sin(TAU * u) / TAU)
			# Planned motion, not real motion, so a wall slowing the slide doesn't make the dash speed up to catch up;
			# move_and_slide keeps only the part along the wall
			velocity = dash_dir * maxf(goal - dash_planned, 0.0) / delta
			dash_planned = goal

	move_and_slide()
	var bumped := get_slide_collision_count() > 0

	match current_state:
		State.WANDER:
			if bumped:
				_new_leg(get_slide_collision(0).get_normal())
			elif leg_travelled >= leg_length:
				_new_leg()

		State.DASH:
			_hit_players()
			if dash_time >= 2.0 * dash_distance / maxf(dash_peak_speed, 1.0):
				dashes_left -= 1
				if dashes_left > 0:
					_windup()
				else:
					_end_attack()

func _start_attack() -> void:
	dashes_left = dashes_per_attack
	attack_timer.start(attack_cooldown)
	_windup()

func _windup() -> void:
	velocity = Vector2.ZERO
	windup_left = windup_time
	current_state = State.WINDUP

func _dash() -> void:
	# The player and enemies may have spawned since the last dash
	_pass_through_bodies()
	dash_dir = global_position.direction_to(_player_center())
	if dash_dir == Vector2.ZERO:
		dash_dir = Vector2.RIGHT
	dash_planned = 0.0
	dash_time = 0.0
	dash_hits.clear()
	current_state = State.DASH

func _end_attack() -> void:
	current_state = State.WANDER
	_new_leg()

## Starts a sine wave flight toward a new random point. away_from: the normal of a wall just bumped into, so the new point is on the open side
func _new_leg(away_from := Vector2.ZERO) -> void:
	var angle := randf() * TAU
	if player and not in_aggro_area and approach_cone > 0:
		var to_player := global_position.direction_to(_player_center())
		angle = to_player.angle() + deg_to_rad(randf_range(-approach_cone, approach_cone) / 2)
	var leg_end := leg_start + leg_dir * leg_length
	if detected_player and leg_end.y < detected_player.global_position.y - get_viewport_rect().size.y:
		angle = PI / 2 + deg_to_rad(randf_range(-return_down_angle, return_down_angle))
	var dir := Vector2.from_angle(angle)
	if away_from != Vector2.ZERO and dir.dot(away_from) < 0:
		dir = dir.bounce(away_from)
	leg_start = global_position
	leg_dir = dir
	leg_length = wander_distance
	leg_travelled = 0.0

func _hit_players() -> void:
	for body in contact_area.get_overlapping_bodies():
		if body.is_in_group("Player") and not dash_hits.has(body):
			dash_hits.append(body)
			_hurt(body, dash_damage, dash_knockback)

## The Dasher flies through the player and other enemies at all times, so only walls stop it
func _pass_through_bodies() -> void:
	for group in ["Player", "enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			if node != self and node is PhysicsBody2D:
				add_collision_exception_with(node)
				node.add_collision_exception_with(self)

func _hurt(body: Node2D, damage: int, knockback: Vector2) -> void:
	var push_dir := signf(dash_dir.x) if current_state == State.DASH else signf(body.global_position.x - global_position.x)
	if push_dir == 0:
		push_dir = 1.0
	if body.has_method("SetKnockback"):
		body.SetKnockback(Vector2(push_dir * knockback.x, knockback.y))
	if body.has_method("GetDamaged"):
		body.GetDamaged(damage)

## Middle of the player's hitbox, which follows Hue's squish
func _player_center() -> Vector2:
	var center := player.global_position
	var hitbox = player.get("hitbox")
	if hitbox:
		center += hitbox.position
	return center

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		detected_player = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body == detected_player:
		detected_player = null

func _on_aggro_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		in_aggro_area = true

func _on_aggro_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		in_aggro_area = false

func _on_area_2d_body_entered(body: Node2D) -> void:
	# A dash deals its own damage, checked every frame in _physics_process
	if body.is_in_group("Player") and current_state != State.DASH:
		_hurt(body, contact_damage, contact_knockback)
