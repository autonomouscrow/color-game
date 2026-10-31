extends ChromaMove

## Yellow. Chroma teleports into a quarter of the arena picked by weight around the player, freezes for freeze_time
## (he can still be hurt), then dashes in a straight line at the player for dash_distance, speeding up from edge_speed
## to peak_speed at the halfway point and back down. The dash's direction locks when the freeze ends. He hurts the
## player on touch during the dash. If the dash leaves him outside the arena, he teleports into a random quarter.

@export_group("Targeting")
## Weight of teleporting into the player's own quarter
@export var player_quadrant_weight := 3.0
## Weight of the quarter beside the player's, across whichever middle line the player is closer to
@export var near_quadrant_weight := 2.0
## Weight of the quarter beside the player's, across the middle line the player is farther from
@export var far_quadrant_weight := 0.0
## Weight of the quarter diagonally opposite the player's
@export var opposite_quadrant_weight := 1.0
## Chroma's teleport spot is kept at least this far from the player's center, so the dash has room to aim
@export var min_player_distance := 250.0
## Random spots tried in the picked quarter when looking for one far enough from the player
@export var spot_tries := 12

@export_group("Dash")
## Seconds Chroma hangs frozen after teleporting before he dashes
@export var freeze_time := 0.4
## Speed at the start and end of the dash
@export var edge_speed := 600.0
## Speed halfway through the dash
@export var peak_speed := 1200.0
@export var dash_distance := 1000.0
## Seconds Chroma stands still after the dash before his next move
@export var recover_time := 0.3
## Seconds the dash can last before Chroma gives up on it, in case something stops him
@export var max_dash_time := 3.0
@export var damage := 20
@export var knockback := Vector2(700, -350)
## Pixels the contact hitbox reaches past Chroma's body on every side; negative keeps it inside his body
@export var hitbox_margin := -15.0
## Area centered on the arena's middle that counts as inside the arena; a dash ending outside it teleports Chroma back
@export var arena_size := Vector2(1920, 900)

enum Phase { FREEZE, DASH, RECOVER }
var phase := Phase.FREEZE
var timer := 0.0
var dash_start := Vector2.ZERO
var dash_dir := Vector2.RIGHT
var contact: ChromaContact

func can_start(player: Node2D) -> bool:
	return player != null

func start(player: Node2D) -> void:
	var center := boss.player_center(player)
	boss.teleport_to(_pick_spot(_pick_quadrant(center), center))
	boss.face_toward(center.x)
	boss.frozen = true
	_make_contact()
	phase = Phase.FREEZE
	timer = 0.0

func tick(player: Node2D, delta: float) -> bool:
	timer += delta
	match phase:
		Phase.FREEZE:
			if timer >= freeze_time:
				# Toward wherever the player is now; a hidden player gets a dash the way Chroma was facing
				var to := boss.player_center(player) - boss.global_position if player else Vector2.ZERO
				dash_dir = to.normalized() if to != Vector2.ZERO else Vector2(boss.facing, 0)
				if dash_dir.x != 0:
					boss.facing = signf(dash_dir.x)
				dash_start = boss.global_position
				boss.frozen = false
				boss.move_velocity = true
				boss.velocity = dash_dir * edge_speed
				contact.active = true
				phase = Phase.DASH
				timer = 0.0
		Phase.DASH:
			var traveled := (boss.global_position - dash_start).dot(dash_dir)
			var blocked := timer > delta and boss.get_slide_collision_count() > 0
			if traveled >= dash_distance - 0.5 or blocked or timer >= max_dash_time:
				_end_dash()
				return false
			# Speed eases up from edge_speed to peak_speed halfway along, then back down
			var t := clampf(traveled / dash_distance, 0.0, 1.0)
			var speed := lerpf(edge_speed, peak_speed, sin(PI * t))
			# The last frame only covers what's left, so the dash stops right at dash_distance
			boss.velocity = dash_dir * minf(speed, (dash_distance - traveled) / delta)
		Phase.RECOVER:
			return timer >= recover_time
	return false

func finish() -> void:
	if is_instance_valid(contact):
		contact.queue_free()
	contact = null

func _end_dash() -> void:
	contact.active = false
	boss.move_velocity = false
	boss.velocity = Vector2.ZERO
	var arena := Rect2(boss.arena_middle() - arena_size / 2, arena_size)
	if not arena.has_point(boss.global_position):
		boss.teleport_to(boss.random_point_in_quadrant(randi() % 4))
	phase = Phase.RECOVER
	timer = 0.0

## The player's quarter, the one beside it across the nearer middle line, the one beside it across the farther line,
## or the one diagonally opposite, picked by their weights
func _pick_quadrant(center: Vector2) -> int:
	var q := boss.quadrant_of(center)
	var middle := boss.arena_middle()
	# q ^ 1 is across the vertical middle line, q ^ 2 across the horizontal one
	var near := q ^ 1 if absf(center.x - middle.x) <= absf(center.y - middle.y) else q ^ 2
	var far := near ^ 3
	var options: Array[int] = [q, near, far, q ^ 3]
	var weights: Array[float] = [player_quadrant_weight, near_quadrant_weight, far_quadrant_weight, opposite_quadrant_weight]
	var total := 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0:
		return q
	var roll := randf() * total
	for i in options.size():
		roll -= maxf(weights[i], 0.0)
		if roll <= 0:
			return options[i]
	return q

## A random spot in quarter q at least min_player_distance from the player's center, or the farthest spot tried
func _pick_spot(q: int, center: Vector2) -> Vector2:
	var best := boss.random_point_in_quadrant(q)
	for i in spot_tries:
		if best.distance_to(center) >= min_player_distance:
			break
		var spot := boss.random_point_in_quadrant(q)
		if spot.distance_to(center) > best.distance_to(center):
			best = spot
	return best

func _make_contact() -> void:
	finish()
	contact = ChromaContact.new()
	contact.size = boss.half_size * 2 + Vector2.ONE * hitbox_margin * 2
	contact.damage = damage
	contact.knockback = knockback
	contact.hurt_player.connect(boss.on_player_hurt)
	boss.add_child(contact)
