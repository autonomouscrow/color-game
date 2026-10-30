extends ChromaMove

## Blue. Chroma jumps at jump_angle to one side of straight up, hangs frozen at the top for freeze_time (he can still be
## hurt), then dives in a straight line at the top of the player's head, speeding up as he falls, until he lands.
## The dive's target is locked the moment he jumps; it doesn't follow the player after. Chroma moves until a jump to
## one side or the other is clear and the dive from its top would be clear and steep enough.

## Degrees from straight up that Chroma jumps at
@export_range(5, 85) var jump_angle := 45.0
## How high the top of the jump is above where Chroma's center starts
@export var jump_height := 400.0
## Seconds Chroma hangs frozen at the top of the jump before diving
@export var freeze_time := 0.2
## Speed the dive starts at
@export var dive_speed := 900.0
## How fast the dive speeds up, in px/s per second, like gravity
@export var dive_acceleration := 1800.0
## Steepest the dive can be is straight down; this is how far from straight down it's allowed to lean, in degrees
@export_range(0, 89) var max_dive_angle := 50.0
## Seconds Chroma stands still after landing before its next move
@export var recover_time := 0.4
## Seconds the dive can last before Chroma gives up on landing, in case he's stuck
@export var max_dive_time := 3.0
@export var damage := 20
@export var knockback := Vector2(600, -400)
## Spacing of the spots Chroma tries when looking for somewhere to jump from
@export var reposition_step := 80.0
## Degrees steeper than max_dive_angle that the spot Chroma heads for has to allow
@export var reposition_angle_margin := 8.0
## Pixels the contact hitbox reaches past Chroma's body on every side
@export var hitbox_margin := 4.0

enum Phase { JUMP, FREEZE, DIVE, RECOVER }
var phase := Phase.JUMP
var timer := 0.0
## Side of the jump picked by in_position: 1 right, -1 left
var side := 1.0
## Where Chroma's center dives toward, locked at the jump
var target := Vector2.ZERO
var dive_dir := Vector2.DOWN
var speed := 0.0
var contact: ChromaContact

## The nearest spot to Chroma, on any floor or platform, that he could jump and dive at the player from. Spots are tried
## every reposition_step along the way out to either side of the player
func reposition_point(player: Node2D) -> Vector2:
	var spot = _find_spot(player)
	return spot if spot != null else boss.global_position

## Only picked when there's somewhere to jump and dive at the player from, like when they're high on a narrow platform
func can_start(player: Node2D) -> bool:
	return player != null and _find_spot(player) != null

## The spot reposition_point heads for, or null if there's none
func _find_spot(player: Node2D):
	var head := boss.player_head(player)
	var dive_target := _dive_target(player)
	var reach := absf(_peak_offset(1.0).x)
	var best = null
	var steps := int(reach / reposition_step) + 1
	for s in [-1.0, 1.0]:
		for i in range(-steps, steps + 1):
			var x: float = head.x - s * (reach + i * reposition_step)
			var surface := boss.surface_under(Vector2(x, head.y - jump_height))
			if surface == null or x < surface.left or x > surface.right:
				continue
			var point := Vector2(x, surface.top - boss.half_size.y)
			if best != null and absf(point.x - boss.global_position.x) >= absf(best.x - boss.global_position.x):
				continue
			# A little steeper than needed, so stopping a few pixels short still leaves him in position
			if _best_side(point, dive_target, max_dive_angle - reposition_angle_margin) != 0:
				best = point
	return best

func in_position(player: Node2D) -> bool:
	if not boss.is_on_floor():
		return false
	side = _best_side(boss.global_position, _dive_target(player))
	return side != 0

func start(player: Node2D) -> void:
	target = _dive_target(player)
	boss.facing = side
	var offset := _peak_offset(side)
	# Launch speed that peaks jump_height up under Chroma's gravity, split by jump_angle
	var up := sqrt(2.0 * boss.gravity * jump_height)
	boss.velocity = Vector2(side * offset.x * boss.gravity / up, -up)
	_make_contact()
	phase = Phase.JUMP
	timer = 0.0

func tick(_player: Node2D, delta: float) -> bool:
	timer += delta
	match phase:
		Phase.JUMP:
			# Normal gravity carries the jump; the top is where he stops rising
			if boss.velocity.y >= 0 or timer > 2.0:
				boss.frozen = true
				phase = Phase.FREEZE
				timer = 0.0
		Phase.FREEZE:
			if timer >= freeze_time:
				boss.frozen = false
				boss.move_velocity = true
				var to := target - boss.global_position
				dive_dir = to.normalized() if to != Vector2.ZERO else Vector2.DOWN
				if dive_dir.x != 0:
					boss.facing = signf(dive_dir.x)
				speed = dive_speed
				boss.velocity = dive_dir * speed
				contact.active = true
				phase = Phase.DIVE
				timer = 0.0
		Phase.DIVE:
			# Collisions from before the dive are stale until Chroma has moved once
			if timer > delta and (boss.get_slide_collision_count() > 0 or timer >= max_dive_time):
				_land()
				return false
			speed += dive_acceleration * delta
			# Past the target he keeps going the same way until something stops him
			boss.velocity = dive_dir * speed
		Phase.RECOVER:
			return timer >= recover_time
	return false

func finish() -> void:
	if is_instance_valid(contact):
		contact.queue_free()
	contact = null

func _land() -> void:
	contact.active = false
	boss.move_velocity = false
	boss.velocity = Vector2.ZERO
	phase = Phase.RECOVER
	timer = 0.0

## Where Chroma's center has to go for his feet to land on the top of the player's head
func _dive_target(player: Node2D) -> Vector2:
	return boss.player_head(player) - Vector2(0, boss.half_size.y)

## From where Chroma starts to the top of the jump; at 45 degrees the top is twice as far sideways as up
func _peak_offset(s: float) -> Vector2:
	return Vector2(s * 2.0 * jump_height * tan(deg_to_rad(jump_angle)), -jump_height)

## The side, 1 or -1, whose jump from center is clear and whose dive at dive_target is clear and within max_angle, the
## steeper dive if both are; 0 if neither works
func _best_side(center: Vector2, dive_target: Vector2, max_angle := max_dive_angle) -> float:
	var best := 0.0
	var best_angle := INF
	for s in [-1.0, 1.0]:
		var peak := center + _peak_offset(s)
		var to := dive_target - peak
		if to.y <= 0:
			continue
		var angle := absf(to.angle_to(Vector2.DOWN))
		if angle <= deg_to_rad(max_angle) and angle < best_angle and _jump_clear(center, s) and boss.sweep_clear(peak, to):
			best = s
			best_angle = angle
	return best

## True if nothing solid is along the jump's arc from center, checked a few straight pieces at a time
func _jump_clear(center: Vector2, s: float) -> bool:
	var offset := _peak_offset(s)
	var xform := Transform2D(0, center)
	var steps := 6
	var last := Vector2.ZERO
	for i in range(1, steps + 1):
		var t := float(i) / steps
		# Height of a thrown arc that peaks at the end: rises fast, then levels off
		var point := Vector2(offset.x * t, offset.y * (2.0 * t - t * t))
		if boss.test_move(xform, point - last):
			return false
		xform.origin += point - last
		last = point
	return true

func _make_contact() -> void:
	finish()
	contact = ChromaContact.new()
	contact.size = boss.half_size * 2 + Vector2.ONE * hitbox_margin * 2
	contact.damage = damage
	contact.knockback = knockback
	contact.hurt_player.connect(boss.on_player_hurt)
	boss.add_child(contact)
