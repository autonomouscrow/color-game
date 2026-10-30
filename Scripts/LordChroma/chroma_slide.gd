extends ChromaMove

## Blue. Chroma gets onto the floor or platform the player is on, jumps straight up, dives back down dive_angle off
## straight down toward the player, then slides along the platform he lands on all the way to its far edge.
## He hurts the player on touch during the dive and the slide.

## How high the top of the jump is above where Chroma's center starts
@export var jump_height := 300.0
## Degrees from straight down the dive leans toward the player
@export_range(0, 80) var dive_angle := 10.0
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
var contact: ChromaContact

## The nearest point to Chroma on whatever the player is standing on or above
func reposition_point(player: Node2D) -> Vector2:
	var surface := boss.surface_under(player.global_position)
	if surface == null:
		return Vector2(player.global_position.x, boss.global_position.y)
	var x := clampf(boss.global_position.x, surface.rect_left + boss.half_size.x, surface.rect_right - boss.half_size.x)
	return Vector2(x, surface.top - boss.half_size.y)

func in_position(player: Node2D) -> bool:
	if not boss.is_on_floor():
		return false
	var here := boss._surface_standing_on()
	return here != null and here == boss.surface_under(player.global_position)

func start(_player: Node2D) -> void:
	boss.velocity = Vector2(0, -sqrt(2.0 * boss.gravity * jump_height))
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
				# Toward wherever the player is now; a hidden player keeps the way he was facing
				if player and player.global_position.x != boss.global_position.x:
					side = signf(player.global_position.x - boss.global_position.x)
				else:
					side = boss.facing
				boss.facing = side
				boss.move_velocity = true
				boss.velocity = Vector2.DOWN.rotated(-side * deg_to_rad(dive_angle)) * dive_speed
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
