extends Area2D

## Each throw rolls a random flight equation of forward distance x (y is down): a nearly straight shot, a lopsided
## hump that can be a gentle arc or a big climb, plus an optional damped wave. On top of that, lift from speed bends the
## path up when the plane is fast and lets it sink when slow. The tilt term m*x is re-solved with the lift included so
## the path still passes through the aim point, like Graphwar. Speed comes from energy along the path, and wherever
## the plane is fast enough it may pull a loop.

## Seconds before the plane disappears if it hasn't hit anything
@export var lifetime := 5.0

## Ranges below are (min, max): a random value between them is picked per throw.
@export_group("Straight Shot")
## Chance a throw goes in a nearly straight line toward the aim point; these may start flat or angled down
@export_range(0, 1) var straight_chance := 0.35
## How far it bows up above the straight line to the aim point
@export var straight_arc_height := Vector2(0, 20)

@export_group("Arc")
## How far the hump rises above the straight line to the aim point
@export var arc_height := Vector2(10, 80)
## Where the hump peaks, as a fraction of the distance to the aim point
@export var arc_peak := Vector2(0.3, 0.6)
## Smallest climb at launch for arcs, high climbs and waves, as height per px forward (straight shots skip this)
@export var min_launch_climb := 0.25

@export_group("High Climb")
## Chance a throw goes up a lot first to build speed for a fast dive
@export_range(0, 1) var high_climb_chance := 0.3
@export var high_climb_height := Vector2(120, 250)
## High climbs peak early, as a fraction of the distance to the aim point
@export var high_climb_peak := Vector2(0.15, 0.4)

@export_group("Wave")
## Chance a throw adds a dipping wave on top of its arc
@export_range(0, 1) var wave_chance := 0.4
## Height of the first rise of the wave; it then dips and shrinks
@export var wave_amplitude := Vector2(30, 80)
## Distance of one full up-and-down wave
@export var wave_length := Vector2(250, 450)
## Distance over which the waves shrink to about a third
@export var wave_damping := Vector2(200, 350)

@export_group("Loops")
## The plane can start a loop whenever it's flying at least this fast, which it reaches by diving
@export var loop_min_speed := 650.0
## No loops in the first this many px after the throw
@export var loop_min_distance := 100.0
## Chance of looping each time it's fast enough and the cooldown is over
@export_range(0, 1) var loop_chance := 0.6
## Distance flown after a loop (or a skipped chance) before it can roll again
@export var loop_cooldown_distance := 200.0
## Loop height as a fraction of the height its speed could carry it (v^2 / 2g); faster planes loop bigger
@export var loop_size := Vector2(0.25, 0.4)
@export var loop_max_half_height := 100.0
## Loop width relative to its height
@export var loop_width := Vector2(0.7, 1.3)
## How far along its path the plane moves during the loop, relative to the loop width; more makes a stretched teardrop
@export var loop_drift := Vector2(1.0, 2.5)
## Makes the loop lopsided, tighter on one side; 0 is symmetric
@export var loop_skew := Vector2(-0.3, 0.3)

@export_group("Glide Out")
## Past the aim point, the plane eases into a straight glide at this dive angle in degrees
@export var glide_out_angle := Vector2(3, 12)
## Distance over which it settles into that glide
@export var glide_out_distance := 250.0

@export_group("Physics")
## Speed at launch, in px/s
@export var launch_speed := Vector2(600, 750)
## Pull on the plane's speed: climbing slows it and diving speeds it up
@export var plane_gravity := 1200.0
## Air drag; higher loses speed faster over distance
@export var drag := 0.00025
## Above this speed lift bends the path upward, below it the plane sinks
@export var lift_speed := 650.0
## How hard lift bends the path per px flown
@export var lift_strength := 0.0008
## Most lift can tilt the path away from its equation, as height per px forward
@export var max_lift_slope := 1.2
## The plane never flies slower than this
@export var min_speed := 120.0

@export_group("Debug")
## Draws the plane's whole flight path until the plane disappears
@export var show_debug_path := false
@export var debug_path_color := Color(1, 1, 1, 0.5)

## Set by the thrower before the plane is added, so the plane ignores it and knows where the ground is
var thrower: Node2D = null

const STEP := 2.0
const RETRIES := 8
const PLANE_HALF_HEIGHT := 5.0

var params := {}
## World positions along the flight and the time the plane reaches each one
var points := PackedVector2Array()
var times := PackedFloat32Array()
var time_alive := 0.0
var launched := false
## How far along the path the last loop drifted, so _add_loops knows how much path it replaced
var loop_drift_used := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## Builds a random flight that passes through target; call after the plane is added and positioned
func launch(target: Vector2) -> void:
	var start := global_position
	var dir_sign := 1.0 if target.x >= start.x else -1.0
	var to_target := Vector2(maxf(absf(target.x - start.x), 50.0), target.y - start.y)
	# Ground under the thrower, relative to the launch point; the flight must stay above it before reaching the aim point
	var floor_y := INF
	if thrower:
		floor_y = thrower.global_position.y + 32.0 - start.y
	var launch_v := _rand(launch_speed)
	var local := PackedVector2Array()
	for attempt in RETRIES:
		if not _roll_params(to_target):
			continue
		local = _solve_with_lift(to_target, launch_v)
		if _clears_ground(local, to_target.x, floor_y):
			break
	if local.is_empty():
		# Every roll launched too flat; fall back to the last roll anyway
		local = _solve_with_lift(to_target, launch_v)
	var target_index := local.size() - 1
	_add_glide_out(local, launch_v)
	local = _add_loops(local, launch_v, target_index, to_target.x, floor_y)
	points.clear()
	for p in local:
		points.append(start + Vector2(p.x * dir_sign, p.y))
	times = _times_for(points, launch_v)
	launched = true
	rotation = (points[1] - points[0]).angle()
	if show_debug_path:
		_draw_debug_path()

func _physics_process(delta: float) -> void:
	if not launched:
		return
	time_alive += delta
	if time_alive >= lifetime or time_alive >= times[times.size() - 1]:
		queue_free()
		return
	var i := clampi(times.bsearch(time_alive) - 1, 0, times.size() - 2)
	var t := inverse_lerp(times[i], times[i + 1], time_alive)
	var next := points[i].lerp(points[i + 1], t)
	if next != global_position:
		rotation = (next - global_position).angle()
	global_position = next

## Picks the random shape, then solves the tilt m so the curve's height at the aim point's distance is the aim point's height.
## Returns false if the shape would launch too flat.
func _roll_params(to_target: Vector2) -> bool:
	var tx := to_target.x
	var ty := to_target.y
	var roll := randf()
	var straight := roll < straight_chance
	var high := not straight and roll < straight_chance + high_climb_chance
	params = {
		"h": _rand(straight_arc_height) if straight else (_rand(high_climb_height) if high else _rand(arc_height)),
		"c": _rand(high_climb_peak) if high else _rand(arc_peak),
		"a": -_rand(wave_amplitude) if not straight and randf() < wave_chance else 0.0,
		"w": _rand(wave_length),
		"d": _rand(wave_damping),
	}
	params["m"] = (ty + params.h * _hump(1.0) - _wave(tx)) / tx
	if straight:
		return true
	var launch_slope: float = params.m - params.h * exp(1.0) / (params.c * tx) + params.a * TAU / params.w
	return launch_slope <= -min_launch_climb

## Hump that rises from 0, peaks at 1 when s = c, then eases off
func _hump(s: float) -> float:
	return (s / params.c) * exp(1.0 - s / params.c)

## Damped wave; negative a means it rises first
func _wave(x: float) -> float:
	return params.a * exp(-x / params.d) * sin(TAU * x / params.w)

func _equation(x: float, tx: float) -> float:
	return params.m * x - params.h * _hump(x / tx) + _wave(x)

## Flies the equation up to the aim point with lift added, then nudges the tilt m until the path hits the aim point again
func _solve_with_lift(to_target: Vector2, launch_v: float) -> PackedVector2Array:
	var path := _march(to_target.x, launch_v)
	for i in 5:
		params["m"] = params.m - (path[path.size() - 1].y - to_target.y) / to_target.x
		path = _march(to_target.x, launch_v)
	return path

## Steps forward along the equation, tracking speed from energy; lift from that speed bends an extra offset into the path
func _march(tx: float, launch_v: float) -> PackedVector2Array:
	var result := PackedVector2Array([Vector2.ZERO])
	var energy := launch_v * launch_v / 2.0
	var lift_slope := 0.0
	var lift_offset := 0.0
	var x := 0.0
	while x < tx:
		x = minf(x + STEP, tx)
		var p := Vector2(x, _equation(x, tx) + lift_offset)
		var prev := result[result.size() - 1]
		var speed := _step_energy(energy, prev, p)
		energy = speed * speed / 2.0
		lift_slope = clampf(lift_slope - _lift(speed) * prev.distance_to(p), -max_lift_slope, max_lift_slope)
		lift_offset += lift_slope * STEP
		result.append(p)
	return result

## Upward bend per px from lift: positive above lift_speed, negative (sinking) below it
func _lift(speed: float) -> float:
	return lift_strength * (speed * speed - lift_speed * lift_speed) / (lift_speed * lift_speed)

## Speed after flying from a to b: height lost becomes speed, height gained costs speed, and drag wears it down
func _step_energy(energy: float, a: Vector2, b: Vector2) -> float:
	energy += plane_gravity * (b.y - a.y)
	energy = maxf(energy, min_speed * min_speed / 2.0)
	energy -= drag * 2.0 * energy * a.distance_to(b)
	return maxf(sqrt(2.0 * maxf(energy, 0.0)), min_speed)

func _clears_ground(local: PackedVector2Array, tx: float, floor_y: float) -> bool:
	for p in local:
		if p.x < tx - 20.0 and p.y > floor_y - PLANE_HALF_HEIGHT:
			return false
	return true

## Past the aim point, eases toward a steady shallow dive while lift from speed keeps bending it
func _add_glide_out(local: PackedVector2Array, launch_v: float) -> void:
	var speed: float = _speeds_for(local, launch_v)[local.size() - 1]
	var last := local[local.size() - 1]
	var angle := (last - local[local.size() - 2]).angle()
	var end_angle := deg_to_rad(_rand(glide_out_angle))
	var step := STEP * 2
	var travelled := 0.0
	# Long enough to fill the lifetime even at a fast speed
	while travelled < lifetime * 1000.0:
		travelled += step
		angle += angle_difference(angle, end_angle) * step / glide_out_distance - _lift(speed) * step
		var next := last + Vector2.from_angle(angle) * step
		speed = _step_energy(speed * speed / 2.0, last, next)
		last = next
		local.append(last)

## Walks the path tracking speed; wherever it's fast enough it may swap a stretch of path for a loop that rejoins it further on
func _add_loops(path: PackedVector2Array, launch_v: float, target_index: int, tx: float, floor_y: float) -> PackedVector2Array:
	var arc := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		arc.append(arc[i - 1] + path[i - 1].distance_to(path[i]))
	var speeds := _speeds_for(path, launch_v)
	var target_arc := arc[target_index]
	var result := PackedVector2Array()
	var since := loop_cooldown_distance
	var i := 0
	while i < path.size():
		result.append(path[i])
		if i > 0:
			since += arc[i] - arc[i - 1]
		if i > 0 and i < path.size() - 2 and arc[i] >= loop_min_distance and speeds[i] >= loop_min_speed and since >= loop_cooldown_distance:
			since = 0.0
			if randf() < loop_chance:
				var loop := _make_loop(path, arc, i, speeds[i], target_arc, tx, floor_y)
				if not loop.is_empty():
					result.append_array(loop)
					# Skip the stretch of path the loop drifted over
					var end_arc := arc[i] + loop_drift_used
					while i < path.size() - 1 and arc[i] < end_arc:
						i += 1
					continue
		i += 1
	return result

## One loop starting at path index i; empty if it would cover the aim point or hit the ground before it
func _make_loop(path: PackedVector2Array, arc: PackedFloat32Array, i: int, speed: float, target_arc: float, tx: float, floor_y: float) -> PackedVector2Array:
	var k := minf(_rand(loop_size) * speed * speed / (2.0 * plane_gravity), loop_max_half_height)
	var rx := k * _rand(loop_width)
	var drift := rx * _rand(loop_drift)
	var skew := _rand(loop_skew)
	if arc[i] < target_arc and arc[i] + drift > target_arc:
		return PackedVector2Array()
	loop_drift_used = drift
	var loop := PackedVector2Array()
	var count := int(TAU * maxf(k, rx) / STEP)
	for j in range(1, count + 1):
		var s := float(j) / count
		var angle := TAU * s + skew * sin(TAU * s)
		var along := _path_at(path, arc, arc[i] + drift * s)
		var tangent := (_path_at(path, arc, arc[i] + drift * s + STEP) - along).normalized()
		# Up side of the direction of travel, so the loop always pulls up
		var up := Vector2(tangent.y, -tangent.x)
		var p := along + tangent * rx * sin(angle) + up * k * (1.0 - cos(angle))
		if p.x < tx and p.y > floor_y - PLANE_HALF_HEIGHT:
			return PackedVector2Array()
		loop.append(p)
	return loop

func _path_at(path: PackedVector2Array, arc: PackedFloat32Array, at: float) -> Vector2:
	var i := clampi(arc.bsearch(at) - 1, 0, arc.size() - 2)
	return path[i].lerp(path[i + 1], clampf(inverse_lerp(arc[i], arc[i + 1], at), 0.0, 1.0))

## Speed at every point of a path, from energy
func _speeds_for(path: PackedVector2Array, launch_v: float) -> PackedFloat32Array:
	var result := PackedFloat32Array([launch_v])
	var speed := launch_v
	for i in range(1, path.size()):
		speed = _step_energy(speed * speed / 2.0, path[i - 1], path[i])
		result.append(speed)
	return result

func _times_for(path: PackedVector2Array, launch_v: float) -> PackedFloat32Array:
	var speeds := _speeds_for(path, launch_v)
	var result := PackedFloat32Array([0.0])
	var time := 0.0
	for i in range(1, path.size()):
		time += maxf(path[i - 1].distance_to(path[i]), 0.01) / speeds[i]
		result.append(time)
	return result

func _draw_debug_path() -> void:
	var line := Line2D.new()
	# Top level so the line stays in world space instead of moving and turning with the plane
	line.top_level = true
	line.width = 2.0
	line.default_color = debug_path_color
	for i in range(0, points.size(), 2):
		if times[i] > lifetime:
			break
		line.add_point(points[i])
	add_child(line)

func _rand(range_value: Vector2) -> float:
	return randf_range(range_value.x, range_value.y)

func _on_body_entered(body: Node2D) -> void:
	if body == thrower or body is enemy:
		return
	queue_free()
