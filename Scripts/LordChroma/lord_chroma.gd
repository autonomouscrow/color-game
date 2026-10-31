class_name LordChroma
extends enemy

## The final boss. IDLE: waits idle_time, swaps color after every 1 or 2 standard attacks, then picks a move: an ult
## when the shared ult timer is up, otherwise a standard attack. REPOSITION: runs, jumps onto platforms and drops off
## them (or flies, in a flying color) until the move would hit, giving up after reposition_timeout. EXECUTE: runs it.
## Swapping color freezes Chroma in place, unhurtable, for swap_freeze_time, and he can't pick a move until
## swap_attack_delay after the swap.
## In a teleporting color, while idle or moving into position, Chroma rolls every teleport_check_interval seconds to
## teleport to a random spot in another quarter of the fly area; the farther the player, the likelier it is.
## Chroma can't be hurt during an ult. If the player gets through an ult without being hit by any of Chroma's attacks,
## they gain the ult's dodge_mp and Chroma is STUNNED: he drops to the floor and stands frozen for ult_stun_time.
## Moves are the ChromaMove children of the Moves node; each one lists the colors it can be picked in.
## The player walks through Chroma, and touching him does no damage; only his moves hurt.

## Emitted whenever Chroma's color changes; the arena listens to this to swap its look
signal color_changed(color: ChromaColor)
signal defeated

## Same order as Hue's HueColor enum, so the two can be compared directly
enum ChromaColor { WHITE, RED, BLUE, YELLOW, GREEN }
enum State { IDLE, REPOSITION, EXECUTE, STUNNED }
var current_state: State = State.IDLE

@export_group("Colors")
@export var current_color := ChromaColor.WHITE:
	set(value):
		var changed := value != current_color
		current_color = value
		_apply_color()
		_apply_flying()
		if changed:
			color_changed.emit(current_color)
## Display colors for each ChromaColor; they match Hue's default colors
@export var white_color := Color(1, 1, 1)
@export var red_color := Color(0.9, 0.15, 0.15)
@export var blue_color := Color(0.2, 0.4, 1.0)
@export var yellow_color := Color(1.0, 0.85, 0.1)
@export var green_color := Color(0.2, 0.8, 0.25)
## Chroma swaps color after a random number of standard attacks between x and y; ults don't count
@export var standard_attacks_per_color := Vector2i(3, 5)
## Colors Chroma can swap to; it never swaps to the color it already is
@export_flags("White", "Red", "Blue", "Yellow", "Green") var swap_colors := 15
## Seconds Chroma hangs frozen in place, and can't be hurt, after swapping color between moves
@export var swap_freeze_time := 0.5
## Seconds after a color swap before Chroma can pick his next move
@export var swap_attack_delay := 0.5

@export_group("Ults")
## Seconds into the fight before the first ult
@export var ult_first_delay := 30.0
## Seconds from the start of one ult until the next one is due; every ult shares this timer
@export var ult_interval := 60.0
## Seconds Chroma stands frozen on the floor after the player dodges a whole ult
@export var ult_stun_time := 5.0

@export_group("Flying")
## Colors Chroma flies in instead of walking: no gravity, through platforms, wandering around the arena
@export_flags("White", "Red", "Blue", "Yellow", "Green") var flying_colors := 10
@export var fly_speed := 250.0
## Fly speed in yellow; every other flying color uses fly_speed
@export var yellow_fly_speed := 150.0
## Size of the area Chroma's center flies around in, centered on arena_center
@export var fly_area_size := Vector2(1700, 700)

@export_group("Teleporting")
## Colors where Chroma can teleport to a random spot in one of the other three quarters of the fly area
@export_flags("White", "Red", "Blue", "Yellow", "Green") var teleport_colors := 8
## Seconds between rolls to teleport, while idle or moving into position
@export var teleport_check_interval := 2.0
## Teleport chance with the player at teleport_near_distance or closer
@export_range(0, 1) var teleport_min_chance := 0.0
## Teleport chance with the player at teleport_far_distance or farther; it climbs in a straight line between the two
@export_range(0, 1) var teleport_max_chance := 0.8
@export var teleport_near_distance := 200.0
@export var teleport_far_distance := 1200.0

@export_group("Movement")
@export var walk_speed := 300.0
@export var gravity := 1800.0
@export var max_fall_speed := 1200.0
## Close enough to a reposition target to stop walking
@export var arrive_distance := 8.0
## Seconds of moving before Chroma gives up on getting in position and picks again
@export var reposition_timeout := 10.0
## The middle of the arena, where Chroma teleports for moves like the quarter blast; the room sets it
@export var arena_center: Node2D

@export_group("Platforming")
## Horizontal speed while in the air
@export var air_speed := 350.0
## Highest Chroma will jump to get onto a platform, measured from where his feet start to the platform's top
@export var max_jump_height := 450.0
## How far above a platform's top Chroma's jump peaks, so he clears its edge
@export var jump_clearance := 60.0
## Gap between Chroma's side and a platform's edge when he jumps up beside it
@export var takeoff_gap := 12.0
## Seconds Chroma ignores a one-way platform he drops through
@export var drop_through_time := 0.4

@export_group("Between Moves")
## Seconds standing still between moves, picked at random between x and y each time
@export var idle_time := Vector2(0.6, 1.2)
## Chroma stays idle while the player is farther away than this
@export var aggro_range := 2000.0

@export_group("Ult Camera")
## Seconds the camera takes to zoom out over the whole arena when an ult starts, and again to go back after it
@export var ult_camera_time := 0.5
## Area the camera fits on screen during an ult, centered on arena_center; by default the arena with its walls
@export var ult_camera_view := Vector2(2040, 1020)

@export_group("Airbrush Display")
## How far from Chroma's center the airbrush is held
@export var airbrush_distance := 56.0
## Opacity of Chroma while it can't be hurt
@export var invulnerable_alpha := 0.6

@export_group("Health Bar")
## Width of the bar as a fraction of the screen's width; it's centered horizontally
@export_range(0.1, 1.0) var health_bar_width := 0.6
@export var health_bar_height := 20.0
## Distance from the top of the screen to the top of the bar
@export var health_bar_top := 170.0
@export var health_bar_border := 2.0
@export var health_bar_border_color := Color(0.2, 0.2, 0.2)
@export var health_bar_back_color := Color(0.5, 0.5, 0.5)
@export var health_bar_fill_color := Color(0.85, 0.1, 0.1)

@export_group("Debug")
## 0 cycles Chroma's color, for testing the arena
@export var debug_color_key := false
@export_group("")

@onready var color_rect: ColorRect = $Color
@onready var airbrush: Node2D = $Airbrush

var moves: Array[ChromaMove] = []
var current_move: ChromaMove
var player: Node2D
## 1 when facing right, -1 when facing left
var facing := 1.0
var idle_left := 0.0
var reposition_left := 0.0
## Standard attacks left before the next color swap
var attacks_until_swap := 1
## Seconds until the next ult is due
var ult_left := 0.0
## Where Chroma is flying to while he wanders
var wander_target := Vector2.ZERO
var has_wander_target := false
## Seconds left of the freeze after a color swap
var swap_freeze_left := 0.0
## Seconds left before Chroma can pick a move after a color swap
var swap_attack_left := 0.0
## Seconds until the next teleport roll
var teleport_check_left := 0.0
## Chroma's own collision mask; flying clears it so he passes through everything
var ground_mask := 1
var spawn_position := Vector2.ZERO
var debug_key_held := false
var health_bar_fill: ColorRect
## True once any of Chroma's attacks has hurt the player during the ult running now
var ult_hit := false
var stun_left := 0.0
## True while a move holds Chroma still in the air, with no gravity, like the quarter blast
var frozen := false
## True while a move sets Chroma's velocity itself, like the blue dive and slide; gravity is skipped
var move_velocity := false
## Half of Chroma's body size, read from its shape
var half_size := Vector2(40, 80)
## Every floor and platform top in the level, rebuilt each time Chroma starts moving into position
var surfaces: Array[Surface] = []
## The platform Chroma is jumping up onto, so he can steer onto it once his feet clear its edge
var jump_target: Surface
var drop_body: PhysicsBody2D
var drop_left := 0.0
## The camera the ult view is borrowing, and its zoom and offset from before, put back when the ult view ends
var ult_camera: Camera2D
var ult_camera_zoom := Vector2.ONE
var ult_camera_offset := Vector2.ZERO
## 0 is the camera's normal view following the player, 1 is the whole arena; tweened between the two
var ult_camera_blend := 0.0
var ult_camera_tween: Tween

## The walkable top edge of one floor or platform
class Surface:
	## Range Chroma's center can stand in; it reaches past the rectangle by most of his half-width
	var left: float
	var right: float
	## The rectangle's own edges
	var rect_left: float
	var rect_right: float
	var rect_bottom: float
	var top: float
	var one_way: bool
	var body: PhysicsBody2D
## True while hits do nothing, like during the quarter blast's warning
var invulnerable := false:
	set(value):
		invulnerable = value
		modulate.a = invulnerable_alpha if invulnerable else 1.0

func _ready() -> void:
	for child in $Moves.get_children():
		if child is ChromaMove:
			child.boss = self
			moves.append(child)
	_apply_color()
	hide_airbrush()
	_build_health_bar()
	var body_shape := $Body.shape as RectangleShape2D
	if body_shape:
		half_size = body_shape.size / 2
	idle_left = randf_range(idle_time.x, idle_time.y)
	ult_left = ult_first_delay
	attacks_until_swap = randi_range(standard_attacks_per_color.x, standard_attacks_per_color.y)
	ground_mask = collision_mask
	spawn_position = global_position
	_apply_flying()

func _process(_delta: float) -> void:
	_update_ult_camera()

func _exit_tree() -> void:
	_release_ult_camera()

func _physics_process(delta: float) -> void:
	var found := get_tree().get_first_node_in_group("Player") as Node2D
	player = found if can_see(found) else null
	_pass_through_player()
	if debug_color_key and Input.is_physical_key_pressed(KEY_0) and not debug_key_held:
		swap_color((current_color + 1) % ChromaColor.size())
	debug_key_held = Input.is_physical_key_pressed(KEY_0)

	for move in moves:
		move.cooldown_left = maxf(move.cooldown_left - delta, 0.0)
	swap_attack_left = maxf(swap_attack_left - delta, 0.0)
	if swap_freeze_left > 0:
		swap_freeze_left -= delta
		if swap_freeze_left <= 0:
			frozen = false
			invulnerable = false

	var engaged := player != null and global_position.distance_to(player.global_position) <= aggro_range
	# The ult timer runs through moves too, but the ult itself waits for the next pick
	if engaged or current_state != State.IDLE:
		ult_left -= delta

	match current_state:
		State.IDLE:
			_update_teleport(delta)
			if is_flying():
				_wander()
			else:
				velocity.x = 0.0
			if engaged:
				idle_left -= delta
				if idle_left <= 0:
					if attacks_until_swap <= 0:
						_swap_to_random_color()
					if swap_attack_left <= 0 and swap_freeze_left <= 0:
						_pick_move()

		State.REPOSITION:
			if not player:
				_end_move()
			elif current_move.in_position(player) and (is_on_floor() or is_flying()):
				velocity.x = 0.0
				if is_flying():
					velocity = Vector2.ZERO
				face_toward(player.global_position.x)
				if current_move.ult:
					ult_left = ult_interval
					ult_hit = false
					invulnerable = true
					_start_ult_camera()
				current_move.times_used += 1
				current_state = State.EXECUTE
				current_move.start(player)
			else:
				reposition_left -= delta
				_update_teleport(delta)
				if is_flying():
					_fly_toward(current_move.reposition_point(player))
				else:
					_navigate(current_move.reposition_point(player))
				if velocity.x != 0:
					facing = signf(velocity.x)
				else:
					face_toward(player.global_position.x)
				if reposition_left <= 0:
					_end_move()

		State.EXECUTE:
			if is_flying():
				if current_move.wander_during:
					_wander()
				else:
					velocity = Vector2.ZERO
			# Moves can't see a hidden player, but finish what they started
			if current_move.tick(player, delta):
				_end_move()

		State.STUNNED:
			velocity.x = 0.0
			stun_left -= delta
			if stun_left <= 0:
				_apply_flying()
				idle_left = randf_range(idle_time.x, idle_time.y)
				current_state = State.IDLE

	_update_drop_through(delta)
	if frozen:
		velocity = Vector2.ZERO
		return
	if move_velocity:
		move_and_slide()
		return
	if is_flying() and current_state != State.STUNNED:
		# Flying back up after a stun starts outside the area; he wanders back in rather than snapping there
		var area := _fly_area().grow(arrive_distance)
		var was_inside := area.has_point(global_position)
		move_and_slide()
		if was_inside:
			global_position = global_position.clamp(area.position, area.end)
		return
	if is_on_floor() and velocity.y > 0:
		velocity.y = 0.0
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()

func _pick_move() -> void:
	# Moves can check the level's surfaces in can_start
	_build_surfaces()
	# A due ult goes first, and keeps its turn until it actually starts
	if ult_left <= 0:
		var ult := _pick_ult()
		if ult:
			current_move = ult
			_start_reposition()
			return
	var options: Array[ChromaMove] = []
	for move in moves:
		if move.ult:
			continue
		if move.allowed_in(current_color) and move.cooldown_left <= 0 and move.weight > 0 and move.can_start(player):
			options.append(move)
	if options.is_empty():
		idle_left = randf_range(idle_time.x, idle_time.y)
		return
	# Moves with a fixed chance in this color take exactly that much; the rest share what's left by weight. With only
	# fixed-chance moves, or only weighted ones, plain weights decide
	var fixed_share := 0.0
	var free_total := 0.0
	for move in options:
		if move.has_fixed_chance(current_color):
			fixed_share += move.fixed_chance
		else:
			free_total += move.weight
	var use_fixed := fixed_share > 0 and free_total > 0
	var weights: Array[float] = []
	var total := 0.0
	for move in options:
		var w := move.weight
		if use_fixed:
			w = move.fixed_chance if move.has_fixed_chance(current_color) else move.weight / free_total * maxf(1.0 - fixed_share, 0.0)
		weights.append(w)
		total += w
	var roll := randf() * total
	current_move = options.back()
	for i in options.size():
		roll -= weights[i]
		if roll <= 0:
			current_move = options[i]
			break
	_start_reposition()

func _start_reposition() -> void:
	reposition_left = reposition_timeout
	jump_target = null
	_build_surfaces()
	current_state = State.REPOSITION

## An ult exclusive to Chroma's color that hasn't been used yet comes first; otherwise any ult allowed in his color
func _pick_ult() -> ChromaMove:
	var allowed: Array[ChromaMove] = []
	var unused_exclusive: Array[ChromaMove] = []
	for move in moves:
		if move.ult and move.allowed_in(current_color) and move.can_start(player):
			allowed.append(move)
			if move.colors == 1 << current_color and move.times_used == 0:
				unused_exclusive.append(move)
	if not unused_exclusive.is_empty():
		return unused_exclusive.pick_random()
	return allowed.pick_random() if not allowed.is_empty() else null

func _end_move() -> void:
	var dodged := false
	if current_move:
		current_move.finish()
		current_move.cooldown_left = current_move.cooldown
		# Only a standard attack that actually went off counts toward the next color swap
		if not current_move.ult and current_state == State.EXECUTE:
			attacks_until_swap -= 1
		dodged = current_move.ult and current_state == State.EXECUTE and not ult_hit
		if dodged:
			_reward_dodge(current_move.dodge_mp)
		if current_move.ult:
			_end_ult_camera()
	current_move = null
	frozen = false
	move_velocity = false
	invulnerable = false
	hide_airbrush()
	velocity.x = 0.0
	idle_left = randf_range(idle_time.x, idle_time.y)
	current_state = State.IDLE
	if dodged:
		stun()

## Call when one of Chroma's attacks takes health off the player, so a hit during an ult cancels the dodge reward
func on_player_hurt(_body: Node2D = null) -> void:
	if current_state == State.EXECUTE and current_move and current_move.ult:
		ult_hit = true

## MP for the player, the same way Hue gains it from kills
func _reward_dodge(amount: int) -> void:
	var found := get_tree().get_first_node_in_group("Player")
	if found and "mp" in found:
		found.mp += amount

## Drops Chroma to the floor, even in a flying color, and holds him there for ult_stun_time; he can be hurt meanwhile
func stun() -> void:
	frozen = false
	move_velocity = false
	invulnerable = false
	collision_mask = ground_mask
	velocity = Vector2.ZERO
	stun_left = ult_stun_time
	current_state = State.STUNNED

func swap_color(color: int) -> void:
	current_color = color as ChromaColor
	attacks_until_swap = randi_range(standard_attacks_per_color.x, standard_attacks_per_color.y)
	swap_attack_left = swap_attack_delay
	# Only between moves; a swap in the middle of one (the debug key) doesn't freeze him
	if current_state == State.IDLE and swap_freeze_time > 0:
		swap_freeze_left = swap_freeze_time
		frozen = true
		invulnerable = true

func _swap_to_random_color() -> void:
	var options: Array[int] = []
	for i in ChromaColor.size():
		if i != current_color and swap_colors & (1 << i):
			options.append(i)
	if options.is_empty():
		attacks_until_swap = randi_range(standard_attacks_per_color.x, standard_attacks_per_color.y)
		return
	swap_color(options.pick_random())

func is_flying() -> bool:
	return flying_colors & (1 << current_color) != 0

## Flying passes through walls and platforms, kept inside the fly area instead
func _apply_flying() -> void:
	if not is_inside_tree():
		return
	collision_mask = 0 if is_flying() else ground_mask
	has_wander_target = false
	teleport_check_left = teleport_check_interval
	if not is_flying() and not frozen:
		velocity = Vector2.ZERO

func _fly_area() -> Rect2:
	var center := arena_center.global_position if arena_center else spawn_position
	return Rect2(center - fly_area_size / 2, fly_area_size)

## Flies to random points around the fly area, one after another
func _wander() -> void:
	if not has_wander_target or global_position.distance_to(wander_target) <= arrive_distance:
		var area := _fly_area()
		wander_target = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		has_wander_target = true
	_fly_toward(wander_target)

func _fly_toward(goal: Vector2) -> void:
	var to := goal - global_position
	velocity = Vector2.ZERO if to.length() <= arrive_distance else to.normalized() * current_fly_speed()

func current_fly_speed() -> float:
	return yellow_fly_speed if current_color == ChromaColor.YELLOW else fly_speed

func can_teleport() -> bool:
	return teleport_colors & (1 << current_color) != 0

## Every teleport_check_interval seconds, rolls to teleport into another quarter, likelier the farther the player is
func _update_teleport(delta: float) -> void:
	if not can_teleport() or player == null or swap_freeze_left > 0:
		return
	teleport_check_left -= delta
	if teleport_check_left > 0:
		return
	teleport_check_left = teleport_check_interval
	var distance := global_position.distance_to(player_center(player))
	var t := clampf(inverse_lerp(teleport_near_distance, teleport_far_distance, distance), 0.0, 1.0)
	if randf() < lerpf(teleport_min_chance, teleport_max_chance, t):
		teleport_to(random_point_in_quadrant(_random_other_quadrant()))

## Center of the arena, which splits it into quarters
func arena_middle() -> Vector2:
	return arena_center.global_position if arena_center else spawn_position

## Quarter of the arena pos is in: bit 1 set means the right half, bit 2 set means the bottom half. So q ^ 1 is the
## quarter beside q, q ^ 2 the one above or below it, and q ^ 3 the one diagonally opposite
func quadrant_of(pos: Vector2) -> int:
	var middle := arena_middle()
	return (1 if pos.x >= middle.x else 0) | (2 if pos.y >= middle.y else 0)

## A random spot in quarter q of the fly area, so Chroma's whole body stays where he can fly
func random_point_in_quadrant(q: int) -> Vector2:
	var area := _fly_area()
	var middle := arena_middle().clamp(area.position, area.end)
	var x_range := Vector2(middle.x, area.end.x) if q & 1 else Vector2(area.position.x, middle.x)
	var y_range := Vector2(middle.y, area.end.y) if q & 2 else Vector2(area.position.y, middle.y)
	return Vector2(randf_range(x_range.x, x_range.y), randf_range(y_range.x, y_range.y))

func _random_other_quadrant() -> int:
	return (quadrant_of(global_position) + randi_range(1, 3)) % 4

## Moves Chroma straight to pos and forgets where he was wandering to
func teleport_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	has_wander_target = false

func _apply_color() -> void:
	if color_rect == null:
		return
	color_rect.color = [white_color, red_color, blue_color, yellow_color, green_color][current_color]

func face_toward(x: float) -> void:
	var side := signf(x - global_position.x)
	if side != 0:
		facing = side

## Holds the airbrush out from Chroma's center toward dir; progress 0 to 1 grows it out, for the pull-out animation
func show_airbrush(dir: Vector2, progress := 1.0) -> void:
	airbrush.visible = true
	airbrush.position = dir.normalized() * airbrush_distance
	airbrush.rotation = dir.angle()
	airbrush.scale = Vector2.ONE * clampf(progress, 0.0, 1.0)

func hide_airbrush() -> void:
	airbrush.visible = false

## Middle of the player's hitbox, which follows Hue's squish
func player_center(body: Node2D) -> Vector2:
	var center := body.global_position
	var hitbox = body.get("hitbox")
	if hitbox:
		center += hitbox.position
	return center

## True if Chroma's body, moved from center by motion, wouldn't touch anything solid. Unlike test_move, one-way
## platforms count as solid whichever way he's going
func sweep_clear(center: Vector2, motion: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $Body.shape
	query.transform = Transform2D(0, center)
	query.motion = motion
	query.collision_mask = ground_mask
	var exclude: Array[RID] = [get_rid()]
	for node in get_tree().get_nodes_in_group("Player"):
		if node is CollisionObject2D:
			exclude.append(node.get_rid())
	query.exclude = exclude
	return get_world_2d().direct_space_state.cast_motion(query)[0] >= 1.0

## Top middle of the player's hitbox
func player_head(body: Node2D) -> Vector2:
	var head := player_center(body)
	var hitbox = body.get("hitbox")
	if hitbox is CollisionShape2D and hitbox.shape is RectangleShape2D:
		head.y -= hitbox.shape.size.y * absf(hitbox.global_scale.y) / 2
	return head

func take_damage(amount: float) -> void:
	if invulnerable:
		return
	super(amount)
	_update_health_bar()

## Zooms the camera out to fit ult_camera_view and centers it on the arena, over ult_camera_time
func _start_ult_camera() -> void:
	if ult_camera == null:
		ult_camera = get_viewport().get_camera_2d()
		if ult_camera == null:
			return
		ult_camera_zoom = ult_camera.zoom
		ult_camera_offset = ult_camera.offset
	_tween_ult_camera(1.0)

## Puts the camera back to following the player, over ult_camera_time
func _end_ult_camera() -> void:
	if ult_camera:
		_tween_ult_camera(0.0)

func _tween_ult_camera(to: float) -> void:
	if ult_camera_tween:
		ult_camera_tween.kill()
	ult_camera_tween = create_tween()
	ult_camera_tween.tween_property(self, "ult_camera_blend", to, ult_camera_time)
	if to <= 0.0:
		ult_camera_tween.tween_callback(_release_ult_camera)

## Blends zoom and offset between the camera's own view and the arena view. The camera keeps following the player
## underneath; the offset cancels that out, and an offset isn't held in by the camera's room limits
func _update_ult_camera() -> void:
	if not is_instance_valid(ult_camera):
		ult_camera = null
		return
	var screen := get_viewport_rect().size
	var fit := minf(screen.x / ult_camera_view.x, screen.y / ult_camera_view.y)
	ult_camera.zoom = ult_camera_zoom.lerp(Vector2.ONE * fit, ult_camera_blend)
	var center := arena_center.global_position if arena_center else spawn_position
	var normal := ult_camera.get_screen_center_position() - ult_camera.offset
	ult_camera.offset = ult_camera_offset.lerp(center - normal, ult_camera_blend)

func _release_ult_camera() -> void:
	if ult_camera_tween:
		ult_camera_tween.kill()
	ult_camera_blend = 0.0
	if is_instance_valid(ult_camera):
		ult_camera.zoom = ult_camera_zoom
		ult_camera.offset = ult_camera_offset
	ult_camera = null

## Built in code on its own CanvasLayer so it stays put on screen while the camera moves; freed along with Chroma
func _build_health_bar() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var border := ColorRect.new()
	border.color = health_bar_border_color
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.anchor_left = 0.5 - health_bar_width / 2
	border.anchor_right = 0.5 + health_bar_width / 2
	border.offset_top = health_bar_top
	border.offset_bottom = health_bar_top + health_bar_height
	layer.add_child(border)
	var back := ColorRect.new()
	back.color = health_bar_back_color
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.offset_left = health_bar_border
	back.offset_top = health_bar_border
	back.offset_right = -health_bar_border
	back.offset_bottom = -health_bar_border
	border.add_child(back)
	health_bar_fill = ColorRect.new()
	health_bar_fill.color = health_bar_fill_color
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(health_bar_fill)
	_update_health_bar()

## The red fill shrinks from the right as Chroma loses health
func _update_health_bar() -> void:
	if health_bar_fill:
		health_bar_fill.anchor_right = float(health) / max_health if max_health > 0 else 0.0

func die() -> void:
	if current_move:
		current_move.finish()
	defeated.emit()
	super()

## Moves Chroma one step toward standing with his center at goal: running, jumping up onto a platform, or dropping off
## one, planning the route across the level's floors and platforms again every frame
func _navigate(goal: Vector2) -> void:
	if not is_on_floor():
		if jump_target:
			# Jumping up beside a platform: hold still until his feet clear its top, then steer onto it
			var feet := global_position.y + half_size.y
			var beside := global_position.x + half_size.x <= jump_target.rect_left or global_position.x - half_size.x >= jump_target.rect_right
			if feet > jump_target.top - 2 and beside and not jump_target.one_way:
				velocity.x = 0.0
			else:
				velocity.x = _speed_toward(clampf(goal.x, jump_target.left, jump_target.right), air_speed)
		else:
			velocity.x = _speed_toward(goal.x, air_speed)
		return
	jump_target = null
	var here := _surface_standing_on()
	var there := surface_under(goal)
	if here == null or there == null or here == there:
		velocity.x = _speed_toward(goal.x, walk_speed)
		return
	var hop := _first_hop(here, there)
	if hop.is_empty():
		velocity.x = _speed_toward(goal.x, walk_speed)
		return
	var to: Surface = hop["to"]
	var x: float = hop["x"]
	match hop["kind"]:
		"up":
			if absf(x - global_position.x) <= arrive_distance:
				velocity.x = 0.0
				velocity.y = -sqrt(2.0 * gravity * (here.top - to.top + jump_clearance))
				jump_target = to
			else:
				velocity.x = _speed_toward(x, walk_speed)
		"drop":
			if absf(x - global_position.x) <= arrive_distance:
				velocity.x = 0.0
				drop_body = here.body
				drop_left = drop_through_time
				add_collision_exception_with(drop_body)
			else:
				velocity.x = _speed_toward(x, walk_speed)
		"off":
			# x is past the edge, so running toward it takes Chroma off and he falls
			velocity.x = _speed_toward(x, walk_speed)

func _speed_toward(x: float, speed: float) -> float:
	var dx := x - global_position.x
	return signf(dx) * speed if absf(dx) > arrive_distance else 0.0

## Breadth-first search over the surfaces; returns the first hop of the shortest route, as kind, to and x
func _first_hop(from: Surface, to: Surface) -> Dictionary:
	var first_hop := {from: {}}
	var queue: Array[Surface] = [from]
	while not queue.is_empty():
		var a: Surface = queue.pop_front()
		for b in surfaces:
			if first_hop.has(b):
				continue
			var hop := _hop(a, b)
			if hop.is_empty():
				continue
			first_hop[b] = hop if a == from else first_hop[a]
			if b == to:
				return first_hop[b]
			queue.append(b)
	return {}

## How Chroma gets straight from surface a to surface b, or empty if he can't. x is where on a he starts the hop,
## picked nearest to where he is now
func _hop(a: Surface, b: Surface) -> Dictionary:
	var rise := a.top - b.top
	var options: Array[float] = []
	if rise > 4 and rise <= max_jump_height:
		# A one-way platform overhead can be jumped up through; anything else is jumped onto from beside its edge
		if b.one_way:
			var lo := maxf(a.left, b.left)
			var hi := minf(a.right, b.right)
			if lo <= hi:
				var under := clampf(global_position.x, lo, hi)
				if _headroom(under, a, b):
					options.append(under)
		# From beside b's edge, as close as a allows; the jump can carry him sideways onto b once his feet clear it
		var reach := air_speed * 2.0 * sqrt(2.0 * jump_clearance / gravity) * 0.8
		var from_left := minf(a.right, b.rect_left - half_size.x - takeoff_gap)
		if from_left >= a.left and b.rect_left + 8 - half_size.x - from_left <= reach and _headroom(from_left, a, b):
			options.append(from_left)
		var from_right := maxf(a.left, b.rect_right + half_size.x + takeoff_gap)
		if from_right <= a.right and from_right - (b.rect_right - 8 + half_size.x) <= reach and _headroom(from_right, a, b):
			options.append(from_right)
		return _nearest_hop("up", b, options)
	if rise < -4:
		if a.one_way:
			var lo := maxf(a.left, b.left)
			var hi := minf(a.right, b.right)
			if lo <= hi:
				options.append(clampf(global_position.x, lo, hi))
				return _nearest_hop("drop", b, options)
		# Running off either edge drops Chroma straight down past it
		for x in [a.left - half_size.x - takeoff_gap, a.right + half_size.x + takeoff_gap]:
			if x >= b.left and x <= b.right:
				options.append(x)
		return _nearest_hop("off", b, options)
	return {}

## True if nothing solid is in the way of a jump straight up at x, from standing on a to clearing the top of b
func _headroom(x: float, a: Surface, b: Surface) -> bool:
	var head_start := a.top - 2 * half_size.y
	var head_peak := b.top - jump_clearance - 2 * half_size.y
	for s in surfaces:
		if s == a or s == b or s.one_way:
			continue
		var overlaps_x := s.rect_right > x - half_size.x and s.rect_left < x + half_size.x
		if overlaps_x and s.rect_bottom <= head_start and s.rect_bottom > head_peak:
			return false
	return true

func _nearest_hop(kind: String, to: Surface, options: Array[float]) -> Dictionary:
	if options.is_empty():
		return {}
	var best := options[0]
	for x in options:
		if absf(x - global_position.x) < absf(best - global_position.x):
			best = x
	return {"kind": kind, "to": to, "x": best}

## Collects the top of every visible, enabled rectangle in the level. left and right are the range Chroma's center can
## stand in, which reaches past the rectangle by most of his half-width
func _build_surfaces() -> void:
	surfaces.clear()
	var root := get_tree().current_scene
	if root == null:
		return
	for body in root.find_children("*", "StaticBody2D", true, false):
		if not (body.is_visible_in_tree() and body.can_process()):
			continue
		for child in body.get_children():
			var shape_node := child as CollisionShape2D
			if shape_node == null or shape_node.disabled or not (shape_node.shape is RectangleShape2D):
				continue
			var xform := shape_node.global_transform
			var size: Vector2 = (shape_node.shape as RectangleShape2D).size * xform.get_scale().abs()
			var surface := Surface.new()
			surface.rect_left = xform.origin.x - size.x / 2
			surface.rect_right = xform.origin.x + size.x / 2
			surface.left = surface.rect_left - half_size.x + 8
			surface.right = surface.rect_right + half_size.x - 8
			surface.top = xform.origin.y - size.y / 2
			surface.rect_bottom = xform.origin.y + size.y / 2
			surface.one_way = shape_node.one_way_collision
			surface.body = body
			surfaces.append(surface)

## The surface straight below pos, or null
func surface_under(pos: Vector2) -> Surface:
	var query := PhysicsRayQueryParameters2D.create(pos, pos + Vector2(0, 4000), ground_mask)
	var exclude: Array[RID] = [get_rid()]
	for node in get_tree().get_nodes_in_group("Player"):
		if node is CollisionObject2D:
			exclude.append(node.get_rid())
	query.exclude = exclude
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return _surface_of(hit["collider"], hit["position"])

func _surface_standing_on() -> Surface:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y < -0.5:
			var surface := _surface_of(collision.get_collider(), collision.get_position())
			if surface:
				return surface
	return surface_under(global_position)

func _surface_of(body: Object, point: Vector2) -> Surface:
	var best: Surface = null
	for surface in surfaces:
		if surface.body == body and (best == null or absf(surface.top - point.y) < absf(best.top - point.y)):
			best = surface
	return best

## Stops ignoring a one-way platform once Chroma has dropped through it
func _update_drop_through(delta: float) -> void:
	if drop_left <= 0:
		return
	drop_left -= delta
	if drop_left <= 0 and is_instance_valid(drop_body):
		remove_collision_exception_with(drop_body)
		drop_body = null

## Chroma walks through the player both ways; re-added every frame since Hue's dash clears its exceptions when it ends
func _pass_through_player() -> void:
	for node in get_tree().get_nodes_in_group("Player"):
		if node is PhysicsBody2D:
			add_collision_exception_with(node)
			node.add_collision_exception_with(self)
