extends ChromaMove

## Blue. Chroma gets onto the floor or platform the player is on, jumps straight up, dives back down dive_angle off
## straight down toward the player, then slides along the platform he lands on all the way to its far edge.
## He hurts the player on touch during the dive and the slide. He jumps only as high as lets the dive come back down to
## where he started without touching anything, so he doesn't jump up between two platforms and dive into one's side.

## Highest the top of the jump goes above where Chroma's center starts; he jumps lower when the dive from this high
## would hit something
@export var jump_height := 300.0
## Lowest jump Chroma will do; with no clear dive from at least this high, he moves along the platform to find one
@export var min_jump_height := 80.0
## Pixels between the jump heights tried, from jump_height down to min_jump_height
@export var jump_height_step := 20.0
## Degrees from straight down the dive leans toward the player
@export_range(0, 80) var dive_angle := 45.0
## Spacing of the spots along the platform Chroma tries when there's no clear dive from where he stands
@export var reposition_step := 80.0
@export var dive_speed := 1500.0
@export var slide_speed := 1000.0
## Gap Chroma stops short of the platform's edge at the end of the slide, so he doesn't fall off
@export var edge_margin := 4.0
## Small downward speed during the slide that keeps Chroma pressed onto the platform, since gravity is off
@export var slide_press := 20.0
## Seconds Chroma stands still after the slide before its next move
@export var recover_time := 0.4
## Seconds any one phase can last before Chroma moves on, in case he's stuck
@export var max_phase_time := 3.0
@export var damage := 20
@export var knockback := Vector2(700, -350)
## Pixels the contact hitbox reaches past Chroma's body on every side
@export var hitbox_margin := 4.0

enum Phase { JUMP, DIVE, SLIDE, RECOVER }
var phase := Phase.JUMP
var timer := 0.0
## 1 when sliding right, -1 left
var side := 1.0
## Where Chroma's center stops at the end of the slide
var slide_end := 0.0
## Height of the jump running now, picked in start
var height := 0.0
var contact: ChromaContact

## The nearest point to Chroma on whatever the player is standing on or above; if he can't jump and dive at the
## player from there, the nearest spot on it, tried every reposition_step, that he can
func reposition_point(player: Node2D) -> Vector2:
	var surface := boss.surface_under(player.global_position)
	if surface == null:
		return Vector2(player.global_position.x, boss.global_position.y)
	var low := surface.rect_left + boss.half_size.x
	var high := surface.rect_right - boss.half_size.x
	var y := surface.top - boss.half_size.y
	var x := clampf(boss.global_position.x, low, high)
	if _clear_height(Vector2(x, y), _side_toward(player, x)) > 0:
		return Vector2(x, y)
	var step := maxf(reposition_step, 1.0)
	var offset := step
	while x - offset >= low or x + offset <= high:
		for spot in [x - offset, x + offset]:
			if spot >= low and spot <= high and _clear_height(Vector2(spot, y), _side_toward(player, spot)) > 0:
				return Vector2(spot, y)
		offset += step
	return Vector2(x, y)

func in_position(player: Node2D) -> bool:
	if not boss.is_on_floor():
		return false
	var here := boss._surface_standing_on()
	if here == null or here != boss.surface_under(player.global_position):
		return false
	return _clear_height(boss.global_position, _side_toward(player, boss.global_position.x)) > 0

func start(player: Node2D) -> void:
	side = _side_toward(player, boss.global_position.x)
	height = _clear_height(boss.global_position, side)
	if height <= 0:
		height = min_jump_height
	boss.velocity = Vector2(0, -sqrt(2.0 * boss.gravity * height))
	_make_contact()
	phase = Phase.JUMP
	timer = 0.0

func tick(player: Node2D, delta: float) -> bool:
	timer += delta
	match phase:
		Phase.JUMP:
			# Normal gravity carries the jump; the top is where he stops rising
			boss.velocity.x = 0.0
			if boss.velocity.y >= 0 or timer >= max_phase_time:
				# Toward wherever the player is now, unless that way's dive isn't clear; then the side picked at the jump
				var toward := _side_toward(player, boss.global_position.x)
				if toward != side and _dive_clear(boss.global_position, toward, height):
					side = toward
				boss.facing = side
				boss.move_velocity = true
				boss.velocity = _dive_direction(side) * dive_speed
				contact.active = true
				phase = Phase.DIVE
				timer = 0.0
		Phase.DIVE:
			if boss.is_on_floor() and timer > delta:
				_start_slide()
			elif boss.get_slide_collision_count() > 0 and timer > delta or timer >= max_phase_time:
				# Hit a wall or ceiling on the way down: let gravity take him the rest of the way
				_stop()
		Phase.SLIDE:
			boss.velocity = Vector2(side * slide_speed, slide_press)
			var arrived := side * (boss.global_position.x - slide_end) >= 0
			if arrived or boss.is_on_wall() or not boss.is_on_floor() or timer >= max_phase_time:
				if arrived:
					boss.global_position.x = slide_end
				_stop()
		Phase.RECOVER:
			return timer >= recover_time
	return false

func finish() -> void:
	if is_instance_valid(contact):
		contact.queue_free()
	contact = null

## Slides to the far edge, in the direction of the dive, of whatever Chroma landed on
func _start_slide() -> void:
	var surface := boss._surface_standing_on()
	if surface == null:
		_stop()
		return
	if side > 0:
		slide_end = surface.rect_right - boss.half_size.x - edge_margin
	else:
		slide_end = surface.rect_left + boss.half_size.x + edge_margin
	boss.velocity = Vector2(side * slide_speed, slide_press)
	phase = Phase.SLIDE
	timer = 0.0

## 1 if the player is to the right of x, -1 to the left; a hidden player, or one straight above or below, keeps the way
## Chroma is facing
func _side_toward(player: Node2D, x: float) -> float:
	if player and player.global_position.x != x:
		return signf(player.global_position.x - x)
	return boss.facing

func _dive_direction(s: float) -> Vector2:
	return Vector2.DOWN.rotated(-s * deg_to_rad(dive_angle))

## Highest jump from jump_height down to min_jump_height, every jump_height_step, whose way straight up from center
## and dive toward side s back down to center's height are both clear; 0 if none is
func _clear_height(center: Vector2, s: float) -> float:
	var h := jump_height
	while h >= min_jump_height:
		if boss.sweep_clear(center, Vector2(0, -h)) and _dive_clear(center + Vector2(0, -h), s, h):
			return h
		h -= maxf(jump_height_step, 1.0)
	return 0.0

## True if the dive from peak toward side s, down h, wouldn't touch anything; it stops just short of the platform
## Chroma jumped from, so that one doesn't count
func _dive_clear(peak: Vector2, s: float, h: float) -> bool:
	var length := maxf(h - 2.0, 0.0) / cos(deg_to_rad(dive_angle))
	return boss.sweep_clear(peak, _dive_direction(s) * length)

func _stop() -> void:
	contact.active = false
	boss.move_velocity = false
	boss.velocity = Vector2.ZERO
	phase = Phase.RECOVER
	timer = 0.0

func _make_contact() -> void:
	finish()
	contact = ChromaContact.new()
	contact.size = boss.half_size * 2 + Vector2.ONE * hitbox_margin * 2
	contact.damage = damage
	contact.knockback = knockback
	contact.hurt_player.connect(boss.on_player_hurt)
	boss.add_child(contact)

## The dive and the slide after it share the slide animation
func anim_state() -> StringName:
	match phase:
		Phase.JUMP:
			return &"float"
		Phase.DIVE, Phase.SLIDE:
			return &"slide"
	return &"landing"
