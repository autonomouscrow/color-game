extends CharacterBody2D

enum HueColor { WHITE, RED, BLUE, YELLOW, GREEN }

const BURST_SHOCKWAVE_SCRIPT := preload("res://Scripts/BurstShockwave.gd")
const COLOR_ACTIONS := ["color_white", "color_red", "color_blue", "color_yellow", "color_green"]  ## Input action for each color, in HueColor order

@export var CanColor: Array = [ true, false, false, false, false ]

@export_group("Walk")
@export var speed := 300.0

@export_group("Dash")
@export var dash_speed := 1200.0  ## Horizontal speed for the whole dash; vertical speed stays at zero
@export var dash_run_speed := 600.0  ## Horizontal speed kept after the dash ends while Shift is still held, on the ground and in the air
@export var dash_time := 0.2  ## Seconds a dash lasts; it can't be cancelled, and Hue has i-frames and passes through enemies the whole time
@export var dash_cooldown := 1  ## Seconds from the start of one dash until Shift can dash again
@export var dash_release_time := 0.2  ## Seconds to ease down to walking speed when Shift is released after a dash with an arrow held

@export_group("Slide")
@export var slide_friction := 200.0
@export var slide_min_speed := 450.0
@export var slide_lowest_speed := 150.0  ## Friction never slows a slide below this; letting go of the arrows still stops it
@export var slide_squish_scale := Vector2(2.0, 0.5)  ## Hue's size while fully squished into a slide, as a fraction of its normal width and height
@export var slide_squish_time := 0.1
@export var slide_stop_time := 0.1
@export var slide_to_squat_time := 0.1  ## Seconds for a slide to pull into a squat when the arrows are let go under a ceiling too low to stand in; the squat lasts until there's room
@export var stand_check_margin := 1.0  ## Pixels the standing-room check shrinks Hue's standing hitbox by at the top and sides, so a ceiling or wall just touching it doesn't count as blocked

@export_group("Jump")
@export var gravity := 1800.0
@export var max_fall_speed := 1000.0
@export var jump_velocity := 800.0
@export var jump_release_cut := 0.5  ## Upward speed is multiplied by this when A is released early, for shorter hops
@export var coyote_time := 0.1  ## Seconds after walking off a ledge that A still jumps
@export var jump_buffer_time := 0.1  ## Seconds before landing that an A press is remembered and jumps on touchdown
@export var slide_jump_unsquish_time := 0.05  ## Seconds to unsquish when jumping out of a slide with A
@export var slide_jump_slowdown_time := 0.2  ## Seconds for leftover slide speed above walking speed to ease off after jumping out of a slide

@export_group("Glide")  ## Pressing A in mid-air (outside coyote time) or Shift in mid-air starts a glide that lasts while A or Shift is held
@export var glide_gravity := 150.0
@export var glide_max_fall_speed := 300.0
@export var glide_speed := 300.0  ## Horizontal speed while gliding; any dash speed being carried is dropped when the glide starts
@export var glide_cooldown := 0.5  ## Seconds from the start of one glide until A or Shift can start another

@export_group("Slam")
@export var slam_speed := 1500.0  ## Downward speed of the mid-air Shift slam and dive (Blue)
@export var slam_squish_time := 0.05  ## Seconds to squish into a slide when a slam hits the ground
@export var squat_scale := Vector2(1.0, 0.5)  ## Hue's size while squatting after a straight-down slam, as a fraction of its normal width and height
@export var squat_hold_time := 0.2  ## Seconds a straight-down slam stays squished before standing up, if no other input cuts it short
@export var squat_to_slide_time := 0.1  ## Seconds for a squat to stretch forward into a slide when left or right is held

@export_group("Cling Grip")  ## Only while cling_color (Green): moving into a wall in mid-air grabs it, stopping vertical movement
@export var cling_height_scale := 0.75  ## Hue's height while clinging, as a fraction of its normal height; it shrinks equally from the top and bottom
@export var cling_shrink_time := 0.1  ## Seconds to shrink when grabbing a wall, and to grow back when letting go
@export var cling_hold_time := 0.1  ## Seconds Hue hangs still after grabbing a wall before sliding down it
@export var cling_gravity_scale := 0.5  ## Gravity while sliding down a wall, as a fraction of normal gravity
@export var wall_jump_coyote_time := 0.1  ## Seconds after letting go of a wall (by pushing away or sliding off its edge) that A still jumps off it
@export var cling_coyote_time := 0.1  ## Seconds after touching a wall that pressing toward it still grabs it; Hue snaps back to the wall
@export var cling_buffer_time := 0.1  ## Seconds an arrow press toward a wall is remembered, so it grabs the wall once Hue touches it
@export var cling_snap_distance := 16.0  ## Farthest Hue snaps back to a wall it just left when grabbing it during coyote time, in pixels
@export var wall_jump_angle := 45.0  ## Angle above horizontal of a jump off the wall; the jump's total speed is jump_velocity times wall_jump_velocity_scale
@export var wall_jump_velocity_scale := 1.5
@export var wall_jump_ease_time := 0.3  ## Seconds for the wall jump's sideways speed to ease to walking speed (or to a stop with no arrows held)
@export var cling_release_on_away := true  ## Holding the arrow away from the wall lets go of it

@export_group("Mental Health Crisis")
@export var crisis_first_mp_time := 1.5  ## Seconds of holding Z for the first MP; each MP after takes crisis_mp_interval_factor times as long as the last
@export var crisis_mp_interval_factor := 0.5
@export var crisis_shrink_scale := Vector2(0.8, 0.6)  ## Hue's size while in a crisis, as a fraction of its normal width and height
@export var crisis_shrink_time := 0.1  ## Seconds to shrink when a crisis starts, and to grow back when it ends
@export var crisis_death_time := 2.999  ## Seconds into the crisis that Hue dies
@export_subgroup("Shake")
@export var crisis_shake_start_time := 0.5  ## Seconds into the crisis that Hue starts shaking
@export var crisis_shake_ramp := 2.0  ## Higher values keep the shaking gentle for longer before it ramps up near crisis_death_time
@export var crisis_shake_start_interval := 0.15  ## Seconds between shake jumps when shaking starts; shrinks to one jump per frame by crisis_death_time
@export var crisis_shake_max_distance := 1.5  ## How far the color rectangle can jump from the hitbox by crisis_death_time, in multiples of Hue's size

@export_group("Healing")  ## Hold X on the ground to heal; any other input cancels it, keeping whatever MP was already drained
@export var heal_time := 2.0  ## Seconds X must be held for the heal to finish
@export var heal_fraction := 1.0 / 3.0  ## Fraction of max_health restored when the heal finishes
@export var heal_squash_scale := Vector2(1.2, 0.6)  ## Hue's size while healing, as a fraction of its normal width and height; the bottom edge stays put
@export var heal_squash_time := 0.15  ## Seconds to squash down when a heal starts, and to stand back up when it ends
@export_subgroup("Shake")  ## A sped-up crisis shake that builds up over heal_build_time, then plays backwards for the rest of the heal
@export var heal_build_time := 0.5  ## Seconds for the copies to pile up and spread out to their peak; they pull back in and get absorbed over the rest of heal_time
@export var heal_copy_count := 12  ## Copies of Hue around it at the peak; the last one is absorbed as the heal finishes
@export var heal_copy_ramp := 2.0  ## Higher values hold back the copies for longer near the start and end, crowding them around the peak
@export var heal_shake_ramp := 2.0  ## Higher values keep the shaking gentle for longer near the start and end, and wilder only around the peak
@export var heal_shake_calm_interval := 0.15  ## Seconds between shake jumps at the very start and end of the heal; it's one jump per frame at the peak
@export var heal_shake_max_distance := 1.5  ## How far the color rectangle and copies can jump from the hitbox at the peak, in multiples of Hue's size
@export_subgroup("")

@export_group("MP Costs")  ## Movement is free; only the gun, heal and a dash that hits something cost MP
@export var dash_mp_cost := 1  ## Spent when a dash ends, only if it hit at least one enemy; a dash started with less than this still goes, but passes through enemies without damaging them
@export var heal_mp_cost := 5  ## Needed to start a heal; drained one point at a time at an even rate over heal_time, with no refund on cancel

@export_group("MP Gain")
@export var mp_per_kill := 1  ## MP gained for each enemy an attack kills, from any attack or move; hits that don't kill give none

@export_group("Punch Attack")
@export var punch_scene: PackedScene = preload("res://Scenes/Prefabs/PunchAttack.tscn")
@export var punch_size := Vector2(100, 50)  ## Full size of the punch hitbox
@export var punch_offset := Vector2(12, -3)  ## Where the punch starts when facing right: x is the edge nearest Hue, y is the punch's vertical center (mirrored when facing left)
@export var punch_extend_time := 0.05  ## Seconds for the punch to extend out to full size
@export var punch_hold_time := 0.05  ## Seconds the punch stays at full size before disappearing
@export var punch_damage := 15.0
@export var punch_cooldown := 0.3  ## Seconds after punching or uppercutting before S can attack again

@export_group("Uppercut Attack")
@export var uppercut_scene: PackedScene = preload("res://Scenes/Prefabs/UppercutAttack.tscn")
@export var uppercut_size := Vector2(65, 80)  ## Full size of the uppercut hitbox; it sits centered on top of Hue and extends upward
@export var uppercut_extend_time := 0.05  ## Seconds for the uppercut to extend up to full size
@export var uppercut_hold_time := 0.05  ## Seconds the uppercut stays at full size before disappearing
@export var uppercut_damage := 15.0

@export_group("Gun Attack")  ## D shoots in any color, toward the arrows held (8 directions), or the way Hue faces with none held
@export var bullet_scene: PackedScene = preload("res://Scenes/Prefabs/Bullet.tscn")
@export var bullet_size := Vector2(20, 10)  ## Length along the flight direction, then width
@export var bullet_spawn_offset := Vector2(0, -15)  ## Where bullets start, relative to Hue's center
@export var bullet_speed := 2000.0
@export var bullet_lifetime := 5.0  ## Seconds before a bullet that hasn't hit anything disappears
@export var bullet_damage := 15.0
@export var gun_mp_cost := 1
@export var gun_cooldown := 0.5  ## Seconds after shooting before D can shoot again

@export_group("Burst Attack")  ## Hold Ctrl for burst_charge_time, on the ground or in the air, in any color; letting go, taking a hit, or a dash, slide or slam during the charge cancels it
@export var burst_bullet_scene: PackedScene = preload("res://Scenes/Prefabs/Bullet.tscn")
@export var burst_charge_time := 0.15  ## Seconds Ctrl must be held before the burst goes off
@export var burst_shrink_scale := Vector2(0.9, 0.7)  ## Hue's size while charging, as a fraction of its normal width and height; the bottom edge stays put
@export var burst_shrink_time := 0.1  ## Seconds to shrink at the start of the charge, and to grow back once the burst goes off (or the charge is cancelled)
@export var burst_freeze_time := 0.25  ## Seconds after the burst goes off that Hue is frozen in place with i-frames; nothing can interrupt it
@export var burst_bullet_count := 16  ## Projectiles fired, evenly spaced in all directions
@export var burst_bullet_size := Vector2(20, 10)  ## Length along the flight direction, then width
@export var burst_bullet_speed := 1500.0
@export var burst_bullet_lifetime := 0.3  ## Seconds before a burst projectile that hasn't hit anything disappears
@export var burst_damage := 15.0  ## Damage per projectile
@export var burst_health_cost := 0.2  ## Fraction of max_health drained when the burst goes off; at or below this much health, it leaves Hue at 1 health instead
@export var burst_min_health := 0.05  ## Fraction of max_health Hue needs to start or fire a burst
@export var burst_cooldown := 2.0  ## Seconds from one burst going off until Ctrl can start another charge
@export_subgroup("Shockwave")  ## A ring that grows from Hue with the projectile front and hits each enemy it reaches once
@export var burst_shockwave_radius := 500.0  ## Pixels from Hue's center that the shockwave reaches
@export var burst_shockwave_damage := 5.0
@export var burst_shockwave_push := 800.0  ## Speed added to each enemy hit, directly away from Hue
@export var burst_shockwave_push_drain_time := 0.2  ## Seconds for that push to drain away to nothing
@export_subgroup("")

@export_group("Slide Attack")
@export var slide_hitbox_scene: PackedScene = preload("res://Scenes/Prefabs/SlideAttack.tscn")
@export var slide_hitbox_margin := 5.0  ## Pixels the slide hitbox reaches past the front half of Hue on every side
@export var slide_damage := 10.0  ## Slide damage is this times Hue's speed when it hits, divided by walking speed

@export_group("Slam Attack")
@export var slam_hitbox_scene: PackedScene = preload("res://Scenes/Prefabs/SlamAttack.tscn")
@export var slam_hitbox_fraction := 0.25  ## Fraction of Hue's height, from the bottom, that a straight-down slam's hitbox covers
@export var slam_hitbox_margin := 5.0  ## Pixels the slam hitbox reaches past that part of Hue on every side
@export var slam_damage := 20.0

@export_group("Dive Attack")
@export var dive_hitbox_scene: PackedScene = preload("res://Scenes/Prefabs/DiveAttack.tscn")
@export var dive_hitbox_size := 45.0  ## Side length of the square dive hitbox, which is turned 45 degrees and centered on Hue's lower front corner
@export var dive_damage := 20.0

@export_group("Dash Attack")
@export var dash_hitbox_scene: PackedScene = preload("res://Scenes/Prefabs/DashAttack.tscn")
@export var dash_hitbox_margin := 5.0  ## Pixels the dash hitbox reaches past Hue on every side
@export var dash_damage := 20.0  ## Damage to each enemy in the dash's path, once per enemy per dash

@export_group("Colors")
@export var current_color := HueColor.WHITE:  ## Hue's current color; Q/W/E/R/F swap to white/red/blue/yellow/green, except during a dash, slam or dive, or where Hue has no room to stand
	set(value):
		current_color = value
		_apply_color()
@export var white_color := Color(1, 1, 1)
@export var red_color := Color(0.9, 0.15, 0.15)
@export var blue_color := Color(0.2, 0.4, 1.0)
@export var yellow_color := Color(1.0, 0.85, 0.1)
@export var green_color := Color(0.2, 0.8, 0.25)
@export_subgroup("Ability Colors")  ## Abilities usable only in one color; everything else works in all colors
@export var glide_color := HueColor.RED  ## Swapping away from it mid-glide ends the glide
@export var dash_color := HueColor.YELLOW  ## Swapping away from it while still running after a dash eases down to walking speed
@export var slide_color := HueColor.BLUE  ## Also covers the mid-air slam and dive
@export var cling_color := HueColor.GREEN  ## Cling grip and wall jumps; swapping away from it lets go of the wall
@export_subgroup("")
@export var color_swap_pause_time := 0.6  ## Seconds the whole game freezes on a color swap; presses during it still count afterwards. 0 turns it off
@export var color_buffer_time := 0.1  ## Seconds a color press is remembered while swapping is blocked; matches jump_buffer_time for now

@export_group("Color Zones")
@export var hidden_alpha := 0.5  ## Hue's opacity while hidden from enemies in a color zone that matches its color

@export_group("Display")
@export var hitbox_color := Color(0.6, 0.2, 1.0, 0.4)  ## Color the true hitbox is drawn in, underneath the white color rectangle

@export_group("Stats")
@export var max_health := 100.0:
	set(value):
		max_health = maxf(value, 0.0)
		health = minf(health, max_health)
@export var health := 100.0:
	set(value):
		health = clampf(value, 0.0, max_health)
@export var max_mp := 6:
	set(value):
		max_mp = maxi(value, 0)
		mp = mini(mp, max_mp)
@export var mp := 0:
	set(value):
		# Spending MP breaks color zone hiding until the zone's reveal_time has passed
		if value < mp:
			time_since_mp_spent = 0.0
		mp = clampi(value, 0, max_mp)

@export_group("Animation")  ## The AnimationTree state machine is driven from _update_animation(); see the state names there
@export var anim_xfade_time := 0.05  ## Crossfade seconds used by every transition when anim_override_xfade is on
@export var anim_override_xfade := true  ## Turn off to use each transition's own Xfade Time set in the AnimationTree editor instead
@export var anim_run_threshold := 10.0  ## Horizontal speed on the ground above which the run animation plays instead of idle
@export var anim_flip_with_facing := true  ## Mirrors the Sprite when Hue faces left; turn off if the art handles facing itself
@export var anim_sprite_faces_right := true  ## Which way the Sprite's frames are drawn facing

@export_group("Palette Swap")  ## Recolors the Sprite's art for each color mode, so one set of animations works in every color
@export var palette_source := PackedColorArray()  ## The colors the art is drawn with, as they appear in the sprite sheet (up to 16)
@export var palette_white := PackedColorArray()  ## Replacements for palette_source in White, in the same order; leave empty to keep the art's own colors
@export var palette_red := PackedColorArray()
@export var palette_blue := PackedColorArray()
@export var palette_yellow := PackedColorArray()
@export var palette_green := PackedColorArray()
@export var palette_tolerance := 0.02  ## How close a pixel must be to a palette_source color to be swapped; raise it if some pixels don't change

@export_group("Debug")
@export var debug_stat_keys := true  ## 1/2 raise/lower health and 3/4 raise/lower MP while held, for testing the HUD
@export var debug_health_rate := 50.0  ## Health per second gained or lost while 1 or 2 is held
@export var debug_mp_interval := 0.3  ## Seconds between each MP point gained or lost while 3 or 4 is held
@export_group("")

@onready var hitbox: CollisionShape2D = $Hitbox
@onready var color_rect: ColorRect = $Color
@onready var sprite: Sprite2D = $Sprite
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var anim_state_machine: AnimationNodeStateMachine = animation_tree.tree_root
@onready var anim_playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")

## Attacks and hits that play once and can't be cut off by movement; only ANIM_INTERRUPTS (or another attack) can cut them short
const ANIM_ONE_SHOTS: Array[StringName] = [&"punch", &"uppercut", &"gun", &"burst"]
const ANIM_INTERRUPTS: Array[StringName] = [&"dash", &"burst"]
## One-shot animation asked for this frame by an event (punch, uppercut, gun); _update_animation() plays it and clears it
var anim_request: StringName = &""
var anim_was_on_floor := true

var dashing := false
var dash_direction := 1.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_hitbox: Node2D
## Enemies Hue stopped colliding with for the current dash or straight-down slam, so they can be restored when it ends
var dash_passed_enemies: Array[PhysicsBody2D] = []
## True while Shift is still held after a dash ends: Hue runs at dash_run_speed, with gravity and collisions back as usual
var dash_carrying := false
## True while extra speed eases down to walking speed, after a dash or after jumping out of a slide
var speed_easing := false
var speed_ease_rate := 0.0
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
## True while A or Shift is held after a mid-air press of either; ends on releasing both, landing, dash, slam, dive, punch or uppercut
var gliding := false
var glide_cooldown_timer := 0.0
var jump_buffer_timer := 0.0
var hitbox_shape: RectangleShape2D
var stand_size: Vector2
## False while Hue's standing hitbox wouldn't fit where it is, like under a low ceiling; checked once at the start of each physics frame
var can_stand_up := true
var stand_check_shape := RectangleShape2D.new()
var debug_mp_timer := 0.0
## Color pressed while swapping was blocked, applied once it's allowed if color_buffer_timer hasn't run out
var buffered_color := HueColor.WHITE
var color_buffer_timer := 0.0
## Actions pressed or released during the last color swap pause; they count as just pressed or released on the first frame after it
var buffered_presses: Array = []
var buffered_releases: Array = []
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
## True from death until Hue has been placed at the checkpoint; knockback stays at zero and can't be set meanwhile
var respawning := false
var healing := false
## X has to be released and pressed again after a heal ends
var heal_locked := false
var heal_time_elapsed := 0.0
## MP drained so far this heal
var heal_mp_spent := 0
## Copies of the color rectangle scattered around Hue this heal; freed one by one as they're absorbed
var heal_copies: Array[ColorRect] = []
## 0 is normal size, 1 is fully squashed into heal_squash_scale
var heal_squash := 0.0
## True while Green Hue grips a wall in mid-air
var clinging := false
## 1 when the wall is to Hue's right, -1 when it's to the left
var cling_wall_dir := 1.0
## Seconds since grabbing the current wall
var cling_timer := 0.0
## 0 is normal height, 1 is fully shrunk into cling_height_scale
var cling_amount := 0.0
## Last arrow direction pressed, remembered for cling_buffer_time
var cling_press_dir := 0.0
var cling_press_timer := 0.0
## Side of the last wall Hue touched, remembered for cling_coyote_time
var wall_touch_dir := 0.0
var wall_touch_timer := 0.0
## Seconds left that A still jumps off the wall Hue just let go of
var wall_jump_coyote_timer := 0.0
## 1 when facing right, -1 when facing left; punches go this way
var facing := 1.0
var punch_cooldown_timer := 0.0
var gun_cooldown_timer := 0.0
## True while Ctrl is held for a burst that hasn't gone off yet
var burst_charging := false
var burst_charge_timer := 0.0
## True for burst_freeze_time after a burst goes off: Hue is frozen in place and invincible
var bursting := false
var burst_freeze_timer := 0.0
var burst_cooldown_timer := 0.0
## 0 is normal size, 1 is fully shrunk into burst_shrink_scale
var burst_shrink := 0.0
var current_punch: Node2D
## Engine time in msec when the last uppercut reached full size; -1 before the first one. A Diver's dive is parried within its window after this
var uppercut_extended_msec := -1
var slide_hitbox: Node2D
var slam_hitbox: Node2D
var dive_hitbox: Node2D
## Which way the dive hitbox's corner faces: the direction of horizontal movement when the dive started
var dive_direction := 1.0

var knockback: Vector2 = Vector2.ZERO
## Color zones Hue is overlapping right now; untyped so their zone_color and reveal_time can be read
var color_zones := []
## Seconds since Hue last spent MP; starts high so a zone hides Hue right away
var time_since_mp_spent := INF
## Multiplier on walking, gliding and post-dash running speed from hazards like Lord Chroma's slime; 1 is full speed
var slow_factor := 1.0
var slow_left := 0.0

func _ready() -> void:
	# Own copy of the shape so resizing it doesn't affect other Hue instances
	hitbox_shape = hitbox.shape.duplicate()
	hitbox.shape = hitbox_shape
	stand_size = hitbox_shape.size
	_apply_color()
	if anim_override_xfade:
		for i in anim_state_machine.get_transition_count():
			anim_state_machine.get_transition(i).xfade_time = anim_xfade_time
	animation_tree.active = true

func _physics_process(delta: float) -> void:
	_physics_step(delta)
	_update_animation()

## Everything Hue does each physics frame; split from _physics_process so its early returns still let _update_animation() run
func _physics_step(delta: float) -> void:
	var buffered: Dictionary = Pause.take_buffered_inputs()
	buffered_presses = buffered.pressed
	buffered_releases = buffered.released
	if debug_stat_keys:
		_debug_stats(delta)
	queue_redraw()
	time_since_mp_spent += delta
	slow_left = maxf(slow_left - delta, 0.0)
	if slow_left <= 0:
		slow_factor = 1.0
	color_rect.modulate.a = hidden_alpha if is_hidden() else 1.0
	sprite.modulate.a = color_rect.modulate.a
	can_stand_up = _can_stand()
	_update_color_swap(delta)
	_drop_moves_outside_color()
	# A straight-down slam passes through enemies until its hitbox goes away, once Hue is fully squished
	if not dashing and not is_instance_valid(slam_hitbox) and not dash_passed_enemies.is_empty():
		_restore_enemy_collisions()
	var direction := signf(Input.get_axis("move_left", "move_right"))
	if direction != 0:
		facing = direction
	_update_punch(delta)
	_update_gun(delta)
	var dash_held := Input.is_action_pressed("dash")
	dash_cooldown_timer -= delta
	glide_cooldown_timer -= delta

	var crisis_held := Input.is_action_pressed("crisis")
	if not crisis_held:
		crisis_locked = false
	var heal_held := Input.is_action_pressed("heal")
	if not heal_held:
		heal_locked = false
	var move_input := direction != 0 or dash_held or Input.is_action_pressed("jump") or Input.is_action_pressed("slide") or Input.is_action_pressed("punch") or Input.is_action_pressed("shoot") or Input.is_action_pressed("burst")
	# Crisis and healing each count the other's key as another input that cancels them
	if _update_heal(heal_held, move_input or crisis_held, delta):
		return
	if _update_crisis(crisis_held, move_input or heal_held, delta):
		return
	_update_cling_shrink(delta)
	if _update_burst(delta):
		return

	# A dash would stand Hue up, so it can't start from a slide under a low ceiling
	if _just_pressed("dash") and current_color == dash_color and not dashing and dash_cooldown_timer <= 0 and (can_stand_up or not sliding):
		# Dashing off a wall always goes away from it
		_start_dash(-cling_wall_dir if clinging else direction)
	if dashing:
		_dash(direction, delta)
		return

	_land_and_fall(delta)
	# Knockback takes over from all the controls below, and is applied last so nothing overrides it
	var knocked_back := knockback.length() > 100.0
	if not knocked_back:
		_update_jump(direction, delta)
		_update_slide_input()
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
		_update_walk(direction, dash_held, delta)
	if knocked_back:
		_apply_knockback(delta)
	move_and_slide()
	_update_cling(direction, delta)

## Ends whichever moves don't belong to the current color
func _drop_moves_outside_color() -> void:
	# Changing to a color without the slide stands Hue up out of a slide or squat over the normal stopping time, once there's room
	if sliding and current_color != slide_color and not slide_stopping and can_stand_up:
		slide_stopping = true
		slide_stop_rate = absf(velocity.x) / slide_stop_time
	# Changing color on the wall lets go right away and Hue falls
	if clinging and current_color != cling_color:
		_end_cling()
	# Changing color mid-glide ends the glide, and changing out of the dash color stops the post-dash run
	if gliding and current_color != glide_color:
		gliding = false
	if dash_carrying and current_color != dash_color:
		dash_carrying = false
		_ease_from_dash(signf(Input.get_axis("move_left", "move_right")))

## S punches, or uppercuts with up held
func _update_punch(delta: float) -> void:
	punch_cooldown_timer -= delta
	if _just_pressed("punch") and punch_cooldown_timer <= 0:
		if Input.is_action_pressed("move_up"):
			_uppercut()
		else:
			_punch()
		_play_attack_sound()

func _play_attack_sound() -> void:
	var audio := get_tree().get_first_node_in_group("AudioSkeff")
	if audio:
		audio.play_attack()

## Plays one of AudioSkeff's ability sounds, e.g. _play_sound(&"gun"); ignore_pause keeps it playing while the game is paused
func _play_sound(ability: StringName, ignore_pause := false) -> void:
	var audio := get_tree().get_first_node_in_group("AudioSkeff")
	if audio:
		audio.play_ability(ability, ignore_pause)

## Like Input.is_action_just_pressed, but also true for a press made during the last color swap pause
func _just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action) or action in buffered_presses

func _just_released(action: StringName) -> bool:
	return Input.is_action_just_released(action) or action in buffered_releases

## D shoots a bullet toward the arrows held, or the way Hue faces with none held
func _update_gun(delta: float) -> void:
	gun_cooldown_timer -= delta
	if not _just_pressed("shoot") or gun_cooldown_timer > 0 or mp < gun_mp_cost:
		return
	var aim := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down")).sign()
	if aim == Vector2.ZERO:
		aim = Vector2(facing, 0)
	gun_cooldown_timer = gun_cooldown
	mp -= gun_mp_cost
	_play_sound(&"gun")
	anim_request = &"gun"
	var bullet := bullet_scene.instantiate()
	bullet.direction = aim.normalized()
	bullet.speed = bullet_speed
	bullet.lifetime = bullet_lifetime
	bullet.bullet_size = bullet_size
	bullet.damage = bullet_damage
	bullet.shooter = self
	bullet.get_node("Color").color = color_rect.color
	# Added to the world rather than Hue, so it doesn't move with Hue; starts from Hue's center plus bullet_spawn_offset, even when Hue is squished
	get_parent().add_child(bullet)
	bullet.global_position = hitbox.global_position + bullet_spawn_offset

## Starts, cancels and runs a heal; returns true when Hue is healing and has already moved this frame
func _update_heal(heal_held: bool, other_input: bool, delta: float) -> bool:
	if healing and (not heal_held or other_input or not is_on_floor()):
		_end_heal()
	elif not bursting and not healing and not in_crisis and heal_held and not heal_locked and not other_input and is_on_floor() and not sliding and not slamming and not dashing and squish == 0 and mp >= heal_mp_cost:
		healing = true
		_play_sound(&"heal")
		dash_carrying = false
		speed_easing = false
		heal_time_elapsed = 0.0
		heal_mp_spent = 0
		shake_timer = 0.0
	if healing:
		velocity.x = 0
		heal_squash = move_toward(heal_squash, 1, delta / heal_squash_time)
		crisis_shrink = move_toward(crisis_shrink, 0, delta / crisis_shrink_time)
		_apply_squish()
		_heal(delta)
		move_and_slide()
		return true
	elif heal_squash > 0:
		heal_squash = move_toward(heal_squash, 0, delta / heal_squash_time)
		_apply_squish()
	return false

## Starts, cancels and runs a crisis; returns true when Hue is in a crisis and has already moved this frame
func _update_crisis(crisis_held: bool, other_input: bool, delta: float) -> bool:
	if in_crisis and (not crisis_held or other_input or not is_on_floor()):
		# Any other input breaks out of the crisis and then does its normal thing below
		_end_crisis()
	elif not bursting and not in_crisis and crisis_held and not crisis_locked and not other_input and is_on_floor() and not sliding and not slamming and not dashing and squish == 0:
		in_crisis = true
		_play_sound(&"crisis")
		dash_carrying = false
		speed_easing = false
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
		return true
	elif crisis_shrink > 0:
		crisis_shrink = move_toward(crisis_shrink, 0, delta / crisis_shrink_time)
		_apply_squish()
	return false

## Charges, fires and runs a burst; returns true while Hue is frozen after one goes off
func _update_burst(delta: float) -> bool:
	burst_cooldown_timer -= delta
	if bursting:
		# Frozen in place for the whole freeze: no gravity, no knockback, no controls
		velocity = Vector2.ZERO
		knockback = Vector2.ZERO
		burst_shrink = move_toward(burst_shrink, 0, delta / burst_shrink_time)
		_apply_squish()
		burst_freeze_timer -= delta
		if burst_freeze_timer <= 0:
			bursting = false
		return true
	if burst_charging and not Input.is_action_pressed("burst"):
		burst_charging = false
	elif not burst_charging and _just_pressed("burst") and burst_cooldown_timer <= 0 and _has_burst_health() and not dashing and not sliding and not slamming:
		burst_charging = true
		burst_charge_timer = 0.0
	if burst_charging:
		# Hue keeps moving normally while it charges
		burst_shrink = move_toward(burst_shrink, 1, delta / burst_shrink_time)
		_apply_squish()
		burst_charge_timer += delta
		if burst_charge_timer >= burst_charge_time:
			if not _has_burst_health():
				burst_charging = false
				return false
			_fire_burst()
			return true
	elif burst_shrink > 0:
		burst_shrink = move_toward(burst_shrink, 0, delta / burst_shrink_time)
		_apply_squish()
	return false

## Fires burst_bullet_count projectiles and a shockwave all around, drains health, turns Hue white and starts the freeze
func _fire_burst() -> void:
	burst_charging = false
	bursting = true
	burst_freeze_timer = burst_freeze_time
	_play_sound(&"burst")
	burst_cooldown_timer = burst_cooldown
	# A burst that would drain Hue to 0 leaves it at 1 instead
	if health <= max_health * burst_health_cost:
		health = 1.0
	else:
		health -= max_health * burst_health_cost
	current_color = HueColor.WHITE
	color_buffer_timer = 0.0
	_end_cling()
	gliding = false
	dash_carrying = false
	speed_easing = false
	knockback = Vector2.ZERO
	jump_buffer_timer = 0
	velocity = Vector2.ZERO
	for i in burst_bullet_count:
		var bullet := burst_bullet_scene.instantiate()
		bullet.direction = Vector2.RIGHT.rotated(TAU * i / burst_bullet_count)
		bullet.speed = burst_bullet_speed
		bullet.lifetime = burst_bullet_lifetime
		bullet.bullet_size = burst_bullet_size
		bullet.damage = burst_damage
		bullet.shooter = self
		bullet.get_node("Color").color = color_rect.color
		# Added to the world rather than Hue, starting from the center of Hue's hitbox
		get_parent().add_child(bullet)
		bullet.global_position = hitbox.global_position
	var shockwave := BURST_SHOCKWAVE_SCRIPT.new()
	shockwave.speed = burst_bullet_speed
	shockwave.max_radius = burst_shockwave_radius
	shockwave.damage = burst_shockwave_damage
	shockwave.push_speed = burst_shockwave_push
	shockwave.push_drain_time = burst_shockwave_push_drain_time
	shockwave.ring_color = color_rect.color
	shockwave.shooter = self
	get_parent().add_child(shockwave)
	shockwave.global_position = hitbox.global_position

## Below burst_min_health, Hue can't start or fire a burst
func _has_burst_health() -> bool:
	return health >= max_health * burst_min_health

## Getting hit, dashing, sliding or slamming during the charge cancels it; Hue grows back to normal size
func _cancel_burst_charge() -> void:
	burst_charging = false

## Shrink into the cling, or grow back after letting go, even during a dash
func _update_cling_shrink(delta: float) -> void:
	var cling_target := 1.0 if clinging else 0.0
	if cling_amount != cling_target:
		cling_amount = move_toward(cling_amount, cling_target, delta / cling_shrink_time)
		_apply_squish()

## Lands on the floor, or falls with the gravity of whatever Hue is doing in the air
func _land_and_fall(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		gliding = false
		if slamming:
			_land_from_slam()
	else:
		coyote_timer -= delta
		if slamming:
			velocity.y = slam_speed
		elif clinging:
			# Hang still for cling_hold_time, then slide down the wall with reduced gravity
			cling_timer += delta
			if cling_timer < cling_hold_time:
				velocity.y = 0
			else:
				velocity.y = minf(velocity.y + gravity * cling_gravity_scale * delta, max_fall_speed)
		elif gliding:
			velocity.y = minf(velocity.y + glide_gravity * delta, glide_max_fall_speed)
		else:
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

## A slam that hits the ground turns straight into a slide, keeping its horizontal speed
func _land_from_slam() -> void:
	slamming = false
	if velocity.x != 0:
		slide_direction = signf(velocity.x)
	_start_slide(slam_squish_time)
	squatting = velocity.x == 0
	squat_amount = 1.0 if squatting else 0.0
	# The dive hitbox ends on landing, unless Shift is held into the slide: then it lasts until the slide hitbox appears
	if not Input.is_action_pressed("slide"):
		_remove_hitbox(dive_hitbox)

## Pushes Hue with the knockback, which fades out over time
func _apply_knockback(delta: float) -> void:
	velocity.x = knockback.x
	# Pop the player upward once, then zero it out so gravity can pull them down
	if knockback.y != 0:
		velocity.y = knockback.y
		knockback.y = 0.0
	knockback = knockback.move_toward(Vector2.ZERO, 800.0 * delta)
	# A slide that knockback ended stands back up over slide_squish_time while Hue is pushed
	if not sliding and squish > 0:
		squish = move_toward(squish, 0, delta / slide_squish_time)
		_apply_squish()

## A: wall jumps, buffered and coyote jumps, starting and ending a glide (Shift can start one too), and cutting a jump short on release
func _update_jump(direction: float, delta: float) -> void:
	if _just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	# A on the wall, or just after letting go of it, jumps off it at wall_jump_angle
	var can_wall_jump := clinging or (wall_jump_coyote_timer > 0 and current_color == cling_color and not is_on_floor() and not slamming)
	if can_wall_jump and _just_pressed("jump"):
		_wall_jump(direction)
	# A buffered press jumps as soon as Hue is on the floor, or just walked off it; a slide under a low ceiling can't jump out
	elif jump_buffer_timer > 0 and coyote_timer > 0 and not slamming and (can_stand_up or not sliding):
		if sliding:
			_jump_out_of_slide()
		velocity.y = -jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
	# A mid-air press that didn't jump starts a glide
	elif _just_pressed("jump") and current_color == glide_color and not is_on_floor() and not slamming and not sliding and glide_cooldown_timer <= 0:
		_start_glide()
	# Shift in mid-air also starts a glide, unless the glide color also has the slam, which keeps Shift
	elif _just_pressed("slide") and current_color == glide_color and current_color != slide_color and not is_on_floor() and not clinging and not slamming and not sliding and glide_cooldown_timer <= 0:
		_start_glide()
	# Letting go of both A and Shift falls as normal
	if gliding and not Input.is_action_pressed("jump") and not Input.is_action_pressed("slide"):
		gliding = false
	# Letting go of A while still rising cuts the jump short
	if _just_released("jump") and velocity.y < 0:
		velocity.y *= jump_release_cut

## Falling stops and any carried dash speed is dropped
func _start_glide() -> void:
	gliding = true
	glide_cooldown_timer = glide_cooldown
	velocity.y = 0
	dash_carrying = false
	speed_easing = false

## Shift slides on the ground at walking speed or faster, and slams or dives in the air
func _update_slide_input() -> void:
	if _just_pressed("slide") and current_color == slide_color and not sliding:
		if is_on_floor():
			if absf(velocity.x) >= speed:
				slide_direction = signf(velocity.x)
				# Slides start at least at slide_min_speed; faster slides keep their speed
				if absf(velocity.x) < slide_min_speed:
					velocity.x = slide_direction * slide_min_speed
				_start_slide(slide_squish_time)
		elif not slamming:
			_start_slam()

## Straight down is a slam; with sideways speed it's a dive
func _start_slam() -> void:
	# Clinging has no sideways speed, so Shift on the wall is a straight-down slam
	_end_cling()
	_cancel_burst_charge()
	slamming = true
	gliding = false
	velocity.y = slam_speed
	if velocity.x == 0:
		slam_hitbox = slam_hitbox_scene.instantiate()
		slam_hitbox.damage = slam_damage
		add_child(slam_hitbox)
		_pass_through_enemies()
	else:
		dive_direction = signf(velocity.x)
		dive_hitbox = dive_hitbox_scene.instantiate()
		dive_hitbox.damage = dive_damage
		add_child(dive_hitbox)
	_update_attack_hitboxes()

## Sets horizontal speed for clinging, gliding, the post-dash run, easing off extra speed, or walking
func _update_walk(direction: float, dash_held: bool, delta: float) -> void:
	if dash_carrying and not dash_held:
		dash_carrying = false
		_ease_from_dash(direction)
	if clinging:
		velocity.x = 0
	elif gliding:
		velocity.x = direction * glide_speed * slow_factor
	elif dash_carrying:
		velocity.x = dash_direction * dash_run_speed * slow_factor
	elif speed_easing:
		# Extra speed eases down to walking speed, or to a stop if no arrows are held
		var target_speed := direction * speed * slow_factor
		velocity.x = move_toward(velocity.x, target_speed, speed_ease_rate * delta)
		if velocity.x == target_speed:
			speed_easing = false
	else:
		velocity.x = direction * speed * slow_factor

## Grabs a wall while cling_color (Green) and airborne when an arrow toward it and a touch of it line up, within the buffer and coyote times;
## lets go on landing, leaving the wall, or pushing away
func _update_cling(direction: float, delta: float) -> void:
	wall_jump_coyote_timer -= delta
	if direction != 0:
		cling_press_dir = direction
		cling_press_timer = cling_buffer_time
	else:
		cling_press_timer -= delta
	var touching_dir := 0.0
	for side in [-1.0, 1.0]:
		if _wall_on_side(side, 2.0):
			touching_dir = side
	if touching_dir != 0:
		wall_touch_dir = touching_dir
		wall_touch_timer = cling_coyote_time
	else:
		wall_touch_timer -= delta
	if clinging:
		var pushing_away := cling_release_on_away and direction == -cling_wall_dir
		if is_on_floor() or pushing_away or touching_dir != cling_wall_dir:
			# Pressing the arrow away a moment before A still wall jumps
			if not is_on_floor():
				wall_jump_coyote_timer = wall_jump_coyote_time
			_end_cling()
		return
	if current_color != cling_color or is_on_floor() or knockback.length() > 100.0:
		return
	if dashing or sliding or slamming or in_crisis:
		return
	if cling_press_timer <= 0 or wall_touch_timer <= 0 or cling_press_dir != wall_touch_dir:
		return
	if touching_dir != wall_touch_dir:
		# Coyote grab: snap back to the wall Hue just left, if it's still beside Hue
		var snap := move_and_collide(Vector2(wall_touch_dir * cling_snap_distance, 0), true)
		if snap == null or not _wall_on_side(wall_touch_dir, cling_snap_distance):
			return
		global_position += snap.get_travel()
	_start_cling(wall_touch_dir)

## True when a mostly vertical surface that isn't an enemy is within reach pixels on that side (1 right, -1 left)
func _wall_on_side(side: float, reach: float) -> bool:
	var collision := move_and_collide(Vector2(side * reach, 0), true)
	if collision == null:
		return false
	var collider := collision.get_collider()
	return absf(collision.get_normal().x) > 0.7 and not (collider is Node and collider.is_in_group("enemy"))

func _start_cling(wall_dir: float) -> void:
	clinging = true
	cling_wall_dir = wall_dir
	cling_timer = 0.0
	velocity = Vector2.ZERO
	gliding = false
	dash_carrying = false
	speed_easing = false
	jump_buffer_timer = 0

func _end_cling() -> void:
	clinging = false

## Jumps away from the wall at wall_jump_angle with jump_velocity total speed; the sideways speed then eases off
func _wall_jump(direction: float) -> void:
	_end_cling()
	var away := -cling_wall_dir
	var angle := deg_to_rad(wall_jump_angle)
	velocity = Vector2(away * cos(angle), -sin(angle)) * jump_velocity * wall_jump_velocity_scale
	facing = away
	# Don't grab the same wall again from the buffered press or the touch that's still remembered
	cling_press_timer = 0
	wall_touch_timer = 0
	wall_jump_coyote_timer = 0
	jump_buffer_timer = 0
	coyote_timer = 0
	speed_easing = true
	speed_ease_rate = absf(velocity.x - direction * speed) / wall_jump_ease_time

func _punch() -> void:
	punch_cooldown_timer = punch_cooldown
	# Attacking ends a glide; A has to be pressed again to glide again
	gliding = false
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
	anim_request = &"punch"

func _uppercut() -> void:
	# Shares the punch's cooldown, and replaces a punch or uppercut that's still out
	punch_cooldown_timer = punch_cooldown
	gliding = false
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
	uppercut.fully_extended.connect(func(): uppercut_extended_msec = Pause.game_msec())
	add_child(uppercut)
	current_punch = uppercut
	anim_request = &"uppercut"

func _start_slide(squish_time: float) -> void:
	sliding = true
	_cancel_burst_charge()
	slide_stopping = false
	slide_squish_duration = squish_time
	squatting = false
	squat_timer = 0.0
	squat_amount = 0.0
	speed_easing = false
	dash_carrying = false

func _jump_out_of_slide() -> void:
	sliding = false
	# Leftover slide speed above walking speed eases off over slide_jump_slowdown_time
	if absf(velocity.x) > speed:
		speed_easing = true
		speed_ease_rate = absf(velocity.x) / slide_jump_slowdown_time

## With an arrow held, eases from the current speed down to walking speed over dash_release_time; otherwise Hue just stops
func _ease_from_dash(direction: float) -> void:
	if direction == 0:
		return
	speed_easing = true
	speed_ease_rate = absf(velocity.x - direction * speed) / dash_release_time

func _start_dash(direction: float) -> void:
	dashing = true
	_play_sound(&"dash")
	_cancel_burst_charge()
	dash_timer = dash_time
	dash_cooldown_timer = dash_cooldown
	dash_direction = direction if direction != 0 else facing
	facing = dash_direction
	_end_cling()
	# A dash cuts off a slide, squat or slam (their hitboxes go with them) and any knockback
	sliding = false
	slamming = false
	gliding = false
	squatting = false
	squat_amount = 0.0
	speed_easing = false
	dash_carrying = false
	knockback = Vector2.ZERO
	jump_buffer_timer = 0
	_pass_through_enemies()
	_remove_hitbox(dash_hitbox)
	# Without enough MP to pay for a hit, the dash just passes through enemies and does no damage
	if mp >= dash_mp_cost:
		dash_hitbox = dash_hitbox_scene.instantiate()
		dash_hitbox.damage = dash_damage
		add_child(dash_hitbox)
		_update_attack_hitboxes()

func _dash(direction: float, delta: float) -> void:
	# Straight across at dash speed with no gravity, until dash_time runs out
	velocity = Vector2(dash_direction * dash_speed, 0)
	if squish > 0:
		squish = move_toward(squish, 0, delta / slide_jump_unsquish_time)
		_apply_squish()
	move_and_slide()
	_update_attack_hitboxes()
	dash_timer -= delta
	if dash_timer <= 0:
		_end_dash(direction)

func _end_dash(direction: float) -> void:
	dashing = false
	velocity.y = 0
	# Holding Shift keeps running at dash_run_speed after the dash; letting go with an arrow held eases down to walking speed
	if Input.is_action_pressed("dash"):
		dash_carrying = true
		velocity.x = dash_direction * dash_run_speed
	else:
		_ease_from_dash(direction)
	# The dash only costs MP if its hitbox touched an enemy at any point
	if is_instance_valid(dash_hitbox) and not dash_hitbox.hit_enemies.is_empty():
		mp -= dash_mp_cost
	_remove_hitbox(dash_hitbox)
	_restore_enemy_collisions()

## Pass through enemies both ways: Hue doesn't bump into them, and they don't bump into Hue
func _pass_through_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is PhysicsBody2D and node not in dash_passed_enemies:
			add_collision_exception_with(node)
			node.add_collision_exception_with(self)
			dash_passed_enemies.append(node)

func _restore_enemy_collisions() -> void:
	for node in dash_passed_enemies:
		if is_instance_valid(node):
			remove_collision_exception_with(node)
			node.remove_collision_exception_with(self)
	dash_passed_enemies.clear()

func _slide(direction: float, delta: float) -> void:
	var blocked := not can_stand_up
	# Under a ceiling too low to stand in, letting go of the arrows (or starting to stand up) squats in place instead
	if blocked and not squatting and (slide_stopping or direction == 0):
		squatting = true
		slide_stopping = false
		squat_timer = 0.0
		slide_stop_rate = absf(velocity.x) / slide_stop_time
	if squatting:
		# A squat that started standing up waits until there's room again
		if blocked:
			slide_stopping = false
		# Shift during a squat stands Hue straight up and hands control back (A is handled by the jump); in Blue, Shift is the slide key, so it does nothing here
		if _just_pressed("dash") and current_color != slide_color and not blocked:
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
			# A slide that turned into a squat pulls its shape in and slows to a stop over slide_stop_time
			velocity.x = move_toward(velocity.x, 0, slide_stop_rate * delta)
			squat_amount = move_toward(squat_amount, 1, delta / slide_to_squat_time)
			squish = move_toward(squish, 1, delta / slide_squish_duration)
			if squish == 1:
				squat_timer += delta
				# Under a low ceiling the squat lasts until there's room to stand
				if squat_timer >= squat_hold_time and not blocked:
					slide_stopping = true
					slide_stop_rate = absf(velocity.x) / slide_stop_time
			_apply_squish()
			return
	else:
		squat_amount = move_toward(squat_amount, 0, delta / squat_to_slide_time)
	# Letting go of the arrows or running out of speed ends the slide: stop over slide_stop_time and unsquish
	# (under a low ceiling, holding an arrow into a wall keeps pushing against it in the slide)
	if (direction == 0 or velocity.x == 0) and not slide_stopping and not blocked:
		slide_stopping = true
		slide_stop_rate = absf(velocity.x) / slide_stop_time
	if slide_stopping:
		velocity.x = move_toward(velocity.x, 0, slide_stop_rate * delta)
		squish = move_toward(squish, 0, delta / slide_squish_time)
		if velocity.x == 0 and squish == 0:
			sliding = false
	else:
		velocity.x = move_toward(velocity.x, slide_direction * slide_lowest_speed, slide_friction * delta)
		squish = move_toward(squish, 1, delta / slide_squish_duration)
	_apply_squish()

func _apply_squish() -> void:
	var squish_scale := slide_squish_scale.lerp(squat_scale, squat_amount)
	var squish_size := stand_size * Vector2.ONE.lerp(squish_scale, squish)
	var size := squish_size * Vector2.ONE.lerp(crisis_shrink_scale, crisis_shrink) * Vector2.ONE.lerp(heal_squash_scale, heal_squash) * Vector2.ONE.lerp(burst_shrink_scale, burst_shrink)
	# Keep the bottom edge in place so Hue squishes down instead of shrinking toward its center
	hitbox.position.y = (stand_size.y - size.y) / 2
	# Clinging shrinks equally from the top and bottom, around the center
	size.y *= lerpf(1.0, cling_height_scale, cling_amount)
	hitbox_shape.size = size
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
	# Dropping into a squat (like under a low ceiling) takes the slide hitbox away; it comes back once Hue is sliding again
	if squatting and is_instance_valid(slide_hitbox):
		_remove_hitbox(slide_hitbox)
		slide_hitbox = null
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
	# Dash hitbox: all of Hue plus the margin, for the whole dash
	if is_instance_valid(dash_hitbox):
		var dash_size := size + Vector2.ONE * dash_hitbox_margin * 2
		dash_hitbox.set_rect(Rect2(hitbox.position - dash_size / 2, dash_size))
	# Dive hitbox: a turned square centered on Hue's lower front corner
	if is_instance_valid(dive_hitbox):
		dive_hitbox.position = hitbox.position + Vector2(dive_direction * size.x / 2, size.y / 2)
		dive_hitbox.set_rect(Rect2(-Vector2.ONE * dive_hitbox_size / 2, Vector2.ONE * dive_hitbox_size))

# Untyped so it also takes hitboxes that are already freed, which a Node2D parameter rejects
func _remove_hitbox(attack_hitbox) -> void:
	if is_instance_valid(attack_hitbox):
		attack_hitbox.queue_free()

func _draw() -> void:
	draw_rect(Rect2(hitbox.position - hitbox_shape.size / 2, hitbox_shape.size), hitbox_color)

func _crisis(delta: float) -> void:
	crisis_time += delta
	# MP comes in faster and faster: 1.5s, then 0.75s more, then 0.375s more...
	while crisis_time >= crisis_next_mp_time and crisis_next_mp_time < crisis_death_time and crisis_mp_interval > 0:
		mp += 1
		_add_crisis_copy()
		crisis_mp_interval *= crisis_mp_interval_factor
		crisis_next_mp_time += crisis_mp_interval
	if crisis_time >= crisis_death_time:
		# Holding the crisis too long kills Hue
		_end_crisis()
		die()
		return
	if crisis_time >= crisis_shake_start_time:
		# Shake jumps get more frequent and farther apart as death nears
		var progress := pow(inverse_lerp(crisis_shake_start_time, crisis_death_time, crisis_time), crisis_shake_ramp)
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

func _heal(delta: float) -> void:
	heal_time_elapsed += delta
	# Rises from 0 to 1 over heal_build_time, then falls back to 0 as the heal finishes
	var intensity := 1.0
	if heal_time_elapsed < heal_build_time:
		intensity = heal_time_elapsed / heal_build_time
	elif heal_time > heal_build_time:
		intensity = 1.0 - clampf((heal_time_elapsed - heal_build_time) / (heal_time - heal_build_time), 0.0, 1.0)
	# Copies pile up like a crisis, then get absorbed one by one in reverse
	var copies_wanted := ceili(heal_copy_count * pow(intensity, heal_copy_ramp))
	while heal_copies.size() < copies_wanted:
		_add_heal_copy()
	while heal_copies.size() > copies_wanted:
		heal_copies.pop_back().queue_free()
	# MP drains at a steady rate: with 5 MP over 2s, one point every 0.4s
	while heal_mp_spent < heal_mp_cost and heal_time_elapsed >= heal_time * (heal_mp_spent + 1) / heal_mp_cost:
		if mp < 1:
			_end_heal()
			return
		mp -= 1
		heal_mp_spent += 1
	if heal_time_elapsed >= heal_time:
		health += max_health * heal_fraction
		_end_heal()
		return
	# Shake jumps get faster and farther apart up to the peak, then slow down and close in on the hitbox
	var progress := pow(intensity, heal_shake_ramp)
	shake_timer -= delta
	if shake_timer <= 0:
		shake_timer = lerpf(heal_shake_calm_interval, 0.0, progress)
		var reach := stand_size * heal_shake_max_distance * progress
		shake_offset = Vector2(randf_range(-reach.x, reach.x), randf_range(-reach.y, reach.y))
		_apply_squish()
		# Each copy jumps to its own spot around the hitbox
		for copy in heal_copies:
			copy.size = color_rect.size
			var copy_offset := Vector2(randf_range(-reach.x, reach.x), randf_range(-reach.y, reach.y))
			copy.position = hitbox.position - copy.size / 2 + copy_offset

func _add_heal_copy() -> void:
	var copy := ColorRect.new()
	copy.color = color_rect.color
	copy.size = color_rect.size
	copy.position = color_rect.position
	add_child(copy)
	heal_copies.append(copy)

func _end_heal() -> void:
	healing = false
	heal_locked = Input.is_action_pressed("heal")
	shake_offset = Vector2.ZERO
	for copy in heal_copies:
		copy.queue_free()
	heal_copies.clear()
	_apply_squish()

## True when the space Hue's standing hitbox would grow into above its current top edge is clear of anything solid; enemies don't count
func _can_stand() -> bool:
	# Standing, the hitbox sits at Hue's origin; only the part above the current hitbox is checked, so slopes and walls Hue is already touching don't block it
	var stand_top := -stand_size.y / 2 + stand_check_margin
	var current_top := hitbox.position.y - hitbox_shape.size.y / 2
	if current_top - stand_top <= 0:
		return true
	stand_check_shape.size = Vector2(stand_size.x - stand_check_margin * 2, current_top - stand_top)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = stand_check_shape
	query.transform = global_transform * Transform2D(0, Vector2(0, (stand_top + current_top) / 2))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var collider = result.collider
		if not (collider is Node and collider.is_in_group("enemy")):
			return false
	return true

## Q/W/E/R/F presses are buffered for color_buffer_time, so a press during a dash, slam, dive or burst freeze, or under a low ceiling, swaps right after it
func _update_color_swap(delta: float) -> void:
	for i in COLOR_ACTIONS.size():
		if _just_pressed(COLOR_ACTIONS[i]):
			if CanColor[i]:
				buffered_color = i as HueColor
				color_buffer_timer = color_buffer_time
	if color_buffer_timer <= 0:
		return
	color_buffer_timer -= delta
	# Slamming covers both the straight-down slam and the dive; a swap mid-slide is fine as long as Hue has room to stand,
	# since a color without the slide stands Hue up
	if not dashing and not slamming and not bursting and can_stand_up:
		var swapped := current_color != buffered_color
		current_color = buffered_color
		color_buffer_timer = 0.0
		if swapped:
			# The sound plays through the pause, which starts right after the new color shows
			_play_sound(&"color_swap", true)
			Pause.hitstop(color_swap_pause_time)

func _apply_color() -> void:
	if color_rect == null:
		return
	color_rect.color = [white_color, red_color, blue_color, yellow_color, green_color][current_color]
	_apply_palette()

## Points the Sprite's palette swap shader at the current color's palette
func _apply_palette() -> void:
	var sprite_node := get_node_or_null("Sprite") as Sprite2D
	if sprite_node == null or not sprite_node.material is ShaderMaterial:
		return
	var target: PackedColorArray = [palette_white, palette_red, palette_blue, palette_yellow, palette_green][current_color]
	var count := mini(mini(palette_source.size(), target.size()), 16)
	var sources := palette_source.duplicate()
	var targets := target.duplicate()
	sources.resize(16)
	targets.resize(16)
	var mat := sprite_node.material as ShaderMaterial
	mat.set_shader_parameter("color_count", count)
	mat.set_shader_parameter("source_colors", sources)
	mat.set_shader_parameter("target_colors", targets)
	mat.set_shader_parameter("tolerance", palette_tolerance)

func _debug_stats(delta: float) -> void:
	var health_direction := float(Input.is_physical_key_pressed(KEY_1)) - float(Input.is_physical_key_pressed(KEY_2))
	health += health_direction * debug_health_rate * delta
	var mp_direction := int(Input.is_physical_key_pressed(KEY_3)) - int(Input.is_physical_key_pressed(KEY_4))
	if mp_direction == 0:
		debug_mp_timer = 0.0
		return
	# Change by one point right away on press, then once every debug_mp_interval while held
	debug_mp_timer -= delta
	if debug_mp_timer <= 0.0:
		# Lowering MP with the debug key doesn't count as spending it
		var spent_time := time_since_mp_spent
		mp += mp_direction
		time_since_mp_spent = spent_time
		debug_mp_timer = debug_mp_interval

## I-frames: dashing, the freeze after a burst, and a straight-down slam until Hue is fully squished, ignore knockback and damage (both also pass through enemies)
func _invincible() -> bool:
	# A slam or dive is invincible in mid-air, and a slam stays so until its hitbox goes away after landing
	return dashing or slamming or is_instance_valid(slam_hitbox) or bursting

func SetKnockback(force: Vector2) -> void:
	if _invincible() or respawning:
		return
	_cancel_burst_charge()
	dash_carrying = false
	speed_easing = false
	gliding = false
	_end_cling()
	# Knockback ends a slide or squat, unless Hue has no room to stand; then the slide waits out the knockback
	if sliding and can_stand_up:
		sliding = false
		squatting = false
	# Knockback breaks out of a heal or crisis; the key has to be pressed again to start another
	if healing:
		_end_heal()
	if in_crisis:
		_end_crisis()
	knockback = force

## Slows Hue to factor of its usual speed for the next duration seconds; the strongest slow running wins
func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor if slow_left <= 0 else minf(slow_factor, factor)
	slow_left = maxf(slow_left, duration)

func GetDamaged(damage: int) -> void:
	if _invincible():
		return
	_cancel_burst_charge()
	health -= damage
	var audio := get_tree().get_first_node_in_group("AudioSkeff")
	if audio:
		audio.play_hurt()
	if health <= 0:
		die()

## True if an uppercut reached full size within the last window seconds; a Diver's dive that hits Hue then is parried
func parried_within(window: float) -> bool:
	return uppercut_extended_msec >= 0 and Pause.game_msec() - uppercut_extended_msec <= window * 1000.0

## Called by Attack each time one of Hue's hitboxes kills an enemy; gaining MP never breaks color zone hiding
func on_attack_kill() -> void:
	mp += mp_per_kill

func enter_color_zone(zone: Area2D) -> void:
	if zone not in color_zones:
		color_zones.append(zone)

func exit_color_zone(zone: Area2D) -> void:
	color_zones.erase(zone)

## True while Hue overlaps a color zone of its own color and hasn't spent MP within that zone's reveal_time; enemies ignore Hue then
func is_hidden() -> bool:
	for zone in color_zones:
		if is_instance_valid(zone) and zone.zone_color == current_color and time_since_mp_spent >= zone.reveal_time:
			return true
	return false
	
func die() -> void:
	# A second fatal hit before the first respawn finishes is ignored
	if respawning:
		return
	respawning = true
	_play_sound(&"death")
	knockback = Vector2.ZERO
	velocity = Vector2.ZERO
	var skeff = get_tree().get_first_node_in_group("spawnSkeff")
	await skeff.Respawn()
	knockback = Vector2.ZERO
	velocity = Vector2.ZERO
	health = 100
	mp = 0
	respawning = false

func unlockColor(o: int) -> void:
	CanColor[o] = true

func moreCrystal(o: int) -> void:
	max_mp += o

## Picks the animation state from what Hue is doing this frame and moves the AnimationTree there.
## Transitions drawn in the AnimationTree editor are used when they exist (with their xfade and switch mode);
## a jump between two states with no transition drawn snaps straight across.
func _update_animation() -> void:
	var on_floor := is_on_floor()
	var target := _anim_base_state()
	var just_landed := on_floor and not anim_was_on_floor
	anim_was_on_floor = on_floor
	# Attacks asked for this frame play over movement, but not over a dash or burst
	var requested := anim_request
	anim_request = &""
	if requested != &"" and target not in [&"burst", &"dash"]:
		target = requested
	elif just_landed and target == &"idle":
		target = &"land"

	if anim_flip_with_facing:
		sprite.flip_h = (facing < 0) == anim_sprite_faces_right

	var current := anim_playback.get_current_node()
	var current_done := anim_playback.get_current_play_position() >= anim_playback.get_current_length()
	# A one-shot that's still playing holds until it ends, unless something important cuts in
	if current in ANIM_ONE_SHOTS and not current_done and requested == &"" and target not in ANIM_INTERRUPTS:
		return
	# Landing plays out unless Hue starts doing something else
	if current == &"land" and not current_done and target == &"idle":
		return
	if target == current:
		# The same attack again restarts it
		if requested == target:
			anim_playback.start(target, true)
		return
	if anim_state_machine.has_transition(current, target):
		anim_playback.travel(target)
	else:
		anim_playback.start(target, true)

## The looping or held state for what Hue is doing, before one-shot attacks and landing are layered on
func _anim_base_state() -> StringName:
	if bursting:
		return &"burst"
	if in_crisis:
		return &"crisis"
	if healing:
		return &"heal"
	if dashing:
		return &"dash"
	if slamming:
		# A straight-down slam has a slam hitbox; one with sideways speed is a dive
		return &"slam" if is_instance_valid(slam_hitbox) else &"dive"
	if sliding:
		return &"squat" if squatting else &"slide"
	if clinging:
		return &"cling"
	if burst_charging:
		return &"burst_charge"
	if not is_on_floor():
		if gliding:
			return &"glide"
		# Wall jumps and knockback pops share the jump; the top of the arc turns into the fall
		return &"jump" if velocity.y < 0 else &"fall"
	return &"run" if absf(velocity.x) > anim_run_threshold else &"idle"
