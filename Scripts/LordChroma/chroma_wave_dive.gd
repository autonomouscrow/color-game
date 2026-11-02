extends ChromaMove

## Green. Chroma walks along the ceiling until he's over the player, shows a warning column below him for warning_time,
## then turns his gravity back down and dives straight down onto the floor pillar under him, hurting the player on
## touch on the way. The landing presses that pillar down and sends a wave out through the floor pillars on either
## side, one column further each wave_step_delay; any column the dip or the wave moves loses its slime puddles. Only
## the dive itself hurts. Chroma stays down for stay_time, then his gravity flips back and he falls up onto the ceiling.
## Needs a ChromaPillars in the arena; without one it's never picked.

## Chroma dives once he's at most this far to the side of the player's center
@export var position_tolerance := 30.0
## Seconds the warning takes to fade in and back out before the dive
@export var warning_time := 0.3
## Pixels the warning column reaches past Chroma's body on each side
@export var warning_margin := 20.0
@export var warning_color := Color(1, 0, 0, 0.35)
@export var dive_speed := 2000.0
@export var damage := 25
@export var knockback := Vector2(700, -400)
## Pixels the dive's contact hitbox reaches past Chroma's body on every side
@export var hitbox_margin := 4.0
## Seconds Chroma stays down on the floor pillar after landing
@export var stay_time := 2.0
## Seconds any one phase can last before Chroma moves on, in case he's stuck
@export var max_phase_time := 3.0

@export_group("Wave")
## How far the landing presses the pillar under Chroma down; it stays down while he does
@export var press_depth := 150.0
## Seconds for the landing to press the pillar down, and for it to come back up once Chroma leaves
@export var press_time := 0.08
@export var press_rise_time := 0.4
## How far the wave lifts the columns beside the landing, and then dips them below where they were; each column
## further out moves wave_falloff times as far
@export var wave_depth := 140.0
@export_range(0, 1) var wave_falloff := 0.9
## Seconds the wave takes to reach each next column out
@export var wave_step_delay := 0.25
## Seconds for each column's whole ripple, rising then dipping then settling
@export var wave_period := 2.4

enum Phase { WARNING, DIVE, DOWN, RISE }
var phase := Phase.WARNING
var timer := 0.0
var pillars: ChromaPillars
var contact: ChromaContact
var warning: Node2D

func can_start(player: Node2D) -> bool:
	pillars = get_tree().get_first_node_in_group("chroma_pillars") as ChromaPillars
	return player != null and boss.on_ceiling() and pillars != null and pillars.is_visible_in_tree() and not pillars.is_busy()

func reposition_point(player: Node2D) -> Vector2:
	return Vector2(boss.player_center(player).x, boss.global_position.y)

func in_position(player: Node2D) -> bool:
	return absf(boss.player_center(player).x - boss.global_position.x) <= position_tolerance

func start(_player: Node2D) -> void:
	phase = Phase.WARNING
	timer = 0.0
	_make_contact()
	warning = Node2D.new()
	warning.top_level = true
	warning.z_index = 5
	warning.draw.connect(_draw_warning)
	boss.get_parent().add_child(warning)
	warning.global_position = Vector2.ZERO

func tick(_player: Node2D, delta: float) -> bool:
	timer += delta
	match phase:
		Phase.WARNING:
			warning.queue_redraw()
			if timer >= warning_time:
				warning.queue_free()
				boss.gravity_override = 1.0
				boss.move_velocity = true
				boss.velocity = Vector2(0, dive_speed)
				contact.active = true
				_next(Phase.DIVE)
		Phase.DIVE:
			boss.velocity = Vector2(0, dive_speed)
			if boss.is_on_floor() and timer > delta or timer >= max_phase_time:
				_land()
		Phase.DOWN:
			if timer >= stay_time:
				boss.gravity_override = 0.0
				_next(Phase.RISE)
		Phase.RISE:
			# Back on the ceiling, which counts as his floor again now
			return boss.is_on_floor() and timer > delta or timer >= max_phase_time
	return false

func finish() -> void:
	if is_instance_valid(contact):
		contact.queue_free()
	contact = null
	if is_instance_valid(warning):
		warning.queue_free()
	warning = null
	boss.gravity_override = 0.0

func _next(p: Phase) -> void:
	phase = p
	timer = 0.0

## Presses the column under Chroma down for as long as he stays, and sends the wave out both ways from it
func _land() -> void:
	contact.active = false
	boss.move_velocity = false
	boss.velocity = Vector2.ZERO
	var center := pillars.column_at(boss.global_position.x)
	pillars.dip_column(center, 0.0, press_depth, press_time, stay_time, press_rise_time)
	for i in pillars.columns:
		var steps := absi(i - center)
		if steps > 0:
			var depth := wave_depth * pow(wave_falloff, steps - 1)
			pillars.ripple_column(i, steps * wave_step_delay, depth, wave_period)
	_next(Phase.DOWN)

func _make_contact() -> void:
	contact = ChromaContact.new()
	contact.size = boss.half_size * 2 + Vector2.ONE * hitbox_margin * 2
	contact.damage = damage
	contact.knockback = knockback
	contact.hurt_player.connect(boss.on_player_hurt)
	boss.add_child(contact)

## From Chroma's feet down to the top of the floor pillar under him, fading in and back out
func _draw_warning() -> void:
	var half := warning_time / 2
	var fade := clampf(minf(timer, warning_time - timer) / half, 0.0, 1.0) if half > 0 else 1.0
	var column := pillars.column_at(boss.global_position.x)
	var top := boss.global_position.y + boss.half_size.y
	var half_width := boss.half_size.x + warning_margin
	var rect := Rect2(boss.global_position.x - half_width, top, half_width * 2, maxf(pillars.floor_top(column) - top, 0.0))
	warning.draw_rect(rect, Color(warning_color, warning_color.a * fade))

## Idle upside down on the ceiling through the warning, floats down, summons the pillars as he presses one, floats
## back up
func anim_state() -> StringName:
	match phase:
		Phase.DIVE, Phase.RISE:
			return &"float"
		Phase.DOWN:
			return &"summon_pillars"
	return &""
