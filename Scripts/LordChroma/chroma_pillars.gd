class_name ChromaPillars
extends Node2D

## Green arena. Splits the arena into columns side by side, making up the whole floor and ceiling: each column is a
## pillar rising from the floor and one hanging from the ceiling. While free, each column's two pillars bob up and down
## together in a rough sine wave, so its gap stays the same size; each column runs a little behind the one on its left
## and its period wanders a little, so the floor ripples rather than moving as one block. The earth
## wave holds them still and slams columns shut one at a time: a red warning fades in and back out, then the two
## pillars meet, wiping out any slime puddles on them. A player
## caught in a closing column is hurt and put in the nearest column that's staying open. Put this node at the arena's
## top left corner; the pillars are built in code. Each time the arena turns green, the pillars grow back out from
## flush with the floor and ceiling, so they push out anything standing where they'd be.
## A column's floor pillar can also be dipped down, or rippled up then down, as by the wave dive. Its bob holds still while the dip runs, so
## only the dip moves it, and picks back up where it left off after; a dip wipes out any slime puddles on it the moment
## it starts. A dip never takes a pillar below the floor.

## Emitted when a closing column takes health off a player
signal hurt_player(body: Node2D)

@export var columns := 8
## Size of the space the columns fill, starting at this node's position
@export var arena_size := Vector2(1920, 900)
@export var pillar_color := Color(0.15, 0.35, 0.18)
## Color of the closing warning at its strongest, halfway through, like the other attacks' warnings
@export var warning_color := Color(1, 0, 0, 0.35)

@export_group("Heights")
## Middle height of the floor pillar, then the ceiling pillar, that each column bobs around
## The floor one sits high enough that, at the bottom of its bob, a dip as deep as the wave dive's still fits above
## the floor
@export var rest_heights := Vector2(230, 100)

@export_group("Bobbing")
## Pixels each pillar bobs above and below its middle height. Neighbors can differ by up to twice this once their
## periods drift apart; Hue jumps about 178 px, so keep it under about 85
@export var bob_amplitude := 70.0
## Seconds for one full bob up and down
@export var bob_period := 4.0
## Each column's period is bob_period times a random amount between 1 - this and 1 + this, picked at the start
@export_range(0, 0.5) var bob_period_jitter := 0.1
## Fraction of a full bob each column runs behind the one on its left
@export var column_phase_step := 0.125
## Pillars hold still at their middle heights while this is off
@export var bob := true

@export_group("Movement")
## Speed the pillars move at to catch back up to their bobbing, when growing in and when reopening after the earth wave
@export var pillar_speed := 200.0
## A player is crushed once a closing column's gap is less than their height plus this
@export var crush_margin := 4.0

enum ColumnState { FREE, HELD, WAIT, WARN, SLAM, CLOSED, OPENING }

class Column:
	var floor_body: AnimatableBody2D
	var ceiling_body: AnimatableBody2D
	var warning: ColorRect
	## Current heights of the floor and ceiling pillars, and the heights they're moving to
	var floor_height := 0.0
	var ceiling_height := 0.0
	var floor_goal := 0.0
	var ceiling_goal := 0.0
	var speed := 0.0
	## A ColumnState
	var state := 0
	var timer := 0.0
	## Where in its bob the column starts, as a fraction of a full bob, and its own period
	var phase := 0.0
	var period := 4.0
	## Earth wave settings for this column's slam
	var warning_time := 0.0
	var damage := 0
	var crushed := false
	## The dip running on the floor pillar: when it starts on bob_time, how deep it goes, and seconds pressing down,
	## holding, and coming back up. dip is how far down it is now
	var dip_start := 0.0
	var dip_depth := 0.0
	var dip_in := 0.0
	var dip_hold := 0.0
	var dip_out := 0.0
	var dip := 0.0
	## True for a ripple: one smooth rise then dip, dip_depth each way, over dip_in seconds
	var ripple := false
	## Seconds this column has bobbed for; it stops counting while a dip runs, so the bob holds still under it
	var bob_clock := 0.0

var cols: Array[Column] = []
## Columns a crushed player gets put in; the earth wave sets these
var safe_columns: Array[int] = []
## Seconds the bobbing has been running
var bob_time := 0.0
## A crushed player whose platform_floor_layers are off for a frame, and what to put back
var platform_reset_body: CharacterBody2D
var platform_reset_layers := 0

func _ready() -> void:
	add_to_group("chroma_pillars")
	for i in columns:
		var column := Column.new()
		column.floor_body = _make_pillar()
		column.ceiling_body = _make_pillar()
		column.warning = ColorRect.new()
		column.warning.color = warning_color
		column.warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.warning.visible = false
		add_child(column.warning)
		column.phase = -i * column_phase_step
		column.period = bob_period * randf_range(1.0 - bob_period_jitter, 1.0 + bob_period_jitter)
		cols.append(column)
	_grow_from_flush()
	visibility_changed.connect(_on_visibility_changed)

func _physics_process(delta: float) -> void:
	bob_time += delta
	if is_instance_valid(platform_reset_body):
		platform_reset_body.platform_floor_layers = platform_reset_layers
	platform_reset_body = null
	for i in cols.size():
		var c := cols[i]
		c.timer += delta
		if not _dipping(c):
			c.bob_clock += delta
		match c.state:
			ColumnState.FREE:
				_set_bob_goals(c)
				c.floor_height = c.floor_goal
				c.ceiling_height = c.ceiling_goal
			ColumnState.WAIT:
				if c.timer >= 0:
					c.state = ColumnState.WARN
					c.timer = 0.0
			ColumnState.WARN:
				if c.timer >= c.warning_time:
					# Meet in the middle of the gap as it is now
					var middle := (c.ceiling_height + arena_size.y - c.floor_height) / 2
					c.ceiling_goal = middle
					c.floor_goal = arena_size.y - middle
					c.state = ColumnState.SLAM
					c.timer = 0.0
			ColumnState.SLAM:
				_check_crush(i)
				if _arrived(c):
					c.state = ColumnState.CLOSED
					_clear_puddles(c)
			ColumnState.OPENING:
				_set_bob_goals(c)
		c.floor_height = move_toward(c.floor_height, c.floor_goal, c.speed * delta)
		c.ceiling_height = move_toward(c.ceiling_height, c.ceiling_goal, c.speed * delta)
		var was_dipped := c.dip != 0
		c.dip = _dip_at(c, bob_time - c.dip_start)
		if c.dip != 0 and not was_dipped:
			_clear_puddles(c)
		# Chases the bob until it catches up, then rides it
		if c.state == ColumnState.OPENING and _arrived(c):
			c.state = ColumnState.FREE
		_place(i)

## Holds every free column still where it is
func hold_all() -> void:
	for c in cols:
		if c.state == ColumnState.FREE or c.state == ColumnState.OPENING:
			_hold(c)

## After delay seconds, column i shows its warning for warning_time, then its pillars slam together at slam_speed
func close_column(i: int, delay: float, warning_time: float, slam_speed: float, damage: int) -> void:
	var c := cols[i]
	_hold(c)
	c.state = ColumnState.WAIT
	c.timer = -delay
	c.warning_time = warning_time
	c.speed = slam_speed
	c.damage = damage
	c.crushed = false

## Every held, waiting or closed column moves back to where its bob is now, then carries on bobbing
func release_all() -> void:
	for c in cols:
		if c.state != ColumnState.FREE:
			c.speed = pillar_speed
			c.state = ColumnState.OPENING

## True while a column is waiting, warning or slamming
func is_closing() -> bool:
	for c in cols:
		if c.state in [ColumnState.WAIT, ColumnState.WARN, ColumnState.SLAM]:
			return true
	return false

## True while any column isn't moving freely, or a dip is running or waiting to start
func is_busy() -> bool:
	for c in cols:
		if c.state != ColumnState.FREE or bob_time < c.dip_start + c.dip_in + c.dip_hold + c.dip_out:
			return true
	return false

## After delay seconds, column i's floor pillar presses down depth over press_time, stays down hold_time, and comes back
## up over rise_time. It won't go below the floor, and a new dip replaces any running on it
func dip_column(i: int, delay: float, depth: float, press_time: float, hold_time: float, rise_time: float) -> void:
	var c := cols[i]
	c.dip_start = bob_time + delay
	c.dip_depth = depth
	c.dip_in = press_time
	c.dip_hold = hold_time
	c.dip_out = rise_time
	c.ripple = false

## After delay seconds, column i's floor pillar rises height and dips back down height below where it started, one
## smooth swell over period seconds, then settles back
func ripple_column(i: int, delay: float, height: float, period: float) -> void:
	var c := cols[i]
	c.dip_start = bob_time + delay
	c.dip_depth = height
	c.dip_in = period
	c.dip_hold = 0.0
	c.dip_out = 0.0
	c.ripple = true

## Cuts every dip short, so the floor pillars come straight back up
func end_dips() -> void:
	for c in cols:
		c.dip_depth = 0.0

## True from when a column's dip starts until it's back up
func _dipping(c: Column) -> bool:
	return c.dip_depth > 0 and bob_time >= c.dip_start and bob_time < c.dip_start + c.dip_in + c.dip_hold + c.dip_out

func _dip_at(c: Column, t: float) -> float:
	if t < 0 or c.dip_depth <= 0:
		return 0.0
	if c.ripple:
		# A negative dip lifts the pillar, so it rises over the first half and sinks over the second
		return -c.dip_depth * sin(TAU * t / c.dip_in) if t < c.dip_in else 0.0
	if t < c.dip_in:
		return c.dip_depth * t / c.dip_in
	t -= c.dip_in
	if t < c.dip_hold:
		return c.dip_depth
	t -= c.dip_hold
	if t < c.dip_out:
		return c.dip_depth * (1.0 - t / c.dip_out)
	return 0.0

## Height of column i's floor pillar as it shows, dip included
func shown_floor_height(c: Column) -> float:
	return maxf(c.floor_height - c.dip, 0.0)

func column_width() -> float:
	return arena_size.x / columns

## Left edge of column i, in global x
func column_left(i: int) -> float:
	return global_position.x + i * column_width()

func column_center_x(i: int) -> float:
	return column_left(i) + column_width() / 2

## Column a global x is in, kept between the first and last
func column_at(x: float) -> int:
	return clampi(floori((x - global_position.x) / column_width()), 0, columns - 1)

## Global y of the top of column i's floor pillar
func floor_top(i: int) -> float:
	return global_position.y + arena_size.y - shown_floor_height(cols[i])

func _make_pillar() -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	var shape := RectangleShape2D.new()
	# As tall as the arena, so it never shows its far end however far it slides out of the floor or ceiling
	shape.size = Vector2(column_width(), arena_size.y)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var rect := ColorRect.new()
	rect.color = pillar_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = -shape.size / 2
	rect.size = shape.size
	body.add_child(rect)
	add_child(body)
	return body

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_grow_from_flush()

## Puts every pillar flush with the floor or ceiling and sends it out to catch up with its bob
func _grow_from_flush() -> void:
	for i in cols.size():
		var c := cols[i]
		c.floor_height = 0.0
		c.ceiling_height = 0.0
		_set_bob_goals(c)
		c.speed = pillar_speed
		c.state = ColumnState.OPENING
		c.warning.visible = false
		_place(i)

## Both pillars rise and fall together, so the gap between them stays the same size
func _set_bob_goals(c: Column) -> void:
	var offset := 0.0
	if bob and c.period > 0:
		offset = bob_amplitude * sin(TAU * (c.bob_clock / c.period + c.phase))
	c.floor_goal = rest_heights.x + offset
	c.ceiling_goal = rest_heights.y - offset

func _hold(c: Column) -> void:
	c.floor_goal = c.floor_height
	c.ceiling_goal = c.ceiling_height
	c.state = ColumnState.HELD

func _arrived(c: Column) -> bool:
	return c.floor_height == c.floor_goal and c.ceiling_height == c.ceiling_goal

func _place(i: int) -> void:
	var c := cols[i]
	var x := (i + 0.5) * column_width()
	c.floor_body.position = Vector2(x, arena_size.y - shown_floor_height(c) + arena_size.y / 2)
	c.ceiling_body.position = Vector2(x, c.ceiling_height - arena_size.y / 2)
	c.warning.visible = c.state == ColumnState.WARN
	if c.warning.visible:
		# Fades in over the first half of the warning and back out over the second
		var half := c.warning_time / 2
		var fade := clampf(minf(c.timer, c.warning_time - c.timer) / half, 0.0, 1.0) if half > 0 else 1.0
		c.warning.color = Color(warning_color, warning_color.a * fade)
	c.warning.position = Vector2(i * column_width(), c.ceiling_height)
	c.warning.size = Vector2(column_width(), maxf(arena_size.y - c.floor_height - c.ceiling_height, 0.0))

## Removes the slime puddles sitting on either of a column's pillars, once it's slammed shut
func _clear_puddles(c: Column) -> void:
	for puddle in get_tree().get_nodes_in_group("chroma_slime_puddle"):
		if puddle.ground == c.floor_body or puddle.ground == c.ceiling_body:
			puddle.queue_free()

## Hurts a player caught in a closing column, once per slam, and puts them in the nearest safe column
func _check_crush(i: int) -> void:
	var c := cols[i]
	if c.crushed:
		return
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		return
	var hitbox = player.get("hitbox")
	if not (hitbox is CollisionShape2D and hitbox.shape is RectangleShape2D):
		return
	var center: Vector2 = hitbox.global_position
	var height: float = hitbox.shape.size.y * absf(hitbox.global_scale.y)
	if column_at(center.x) != i or center.x < column_left(i) or center.x >= column_left(i) + column_width():
		return
	var gap := arena_size.y - c.floor_height - c.ceiling_height
	if gap >= height + crush_margin:
		return
	c.crushed = true
	if player.has_method("GetDamaged"):
		var health_before = player.get("health")
		player.GetDamaged(c.damage)
		if health_before != null and player.get("health") < health_before:
			hurt_player.emit(player)
	if safe_columns.is_empty():
		return
	var nearest := safe_columns[0]
	for s in safe_columns:
		if absi(s - i) < absi(nearest - i):
			nearest = s
	# Standing on the safe column's floor pillar
	var feet_offset: float = hitbox.global_position.y - player.global_position.y + height / 2
	player.global_position = Vector2(column_center_x(nearest), floor_top(nearest) - feet_offset - 1)
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	# The player still thinks they're standing on the slamming pillar, and would carry its speed and fly off; for one
	# frame, no platform counts, so they let go of it with nothing
	if player is CharacterBody2D and player != platform_reset_body:
		platform_reset_body = player
		platform_reset_layers = player.platform_floor_layers
		player.platform_floor_layers = 0
