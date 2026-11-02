extends ChromaMove

## Green. Slams the green arena's columns shut one after another, each after a red warning fades in and out, leaving
## some open.
## Picks one of three versions by weight:
## - From the right: closes from the rightmost column leftward, leaving from_right_open_column open.
## - From the left: closes from the leftmost column rightward, leaving from_left_open_column open.
## - Both sides: closes the outermost columns first and works inward from both ends at once, leaving the middle
##   center_open_columns open.
## Chroma first walks along the ceiling to an open column, so he's never caught in one. A player caught in a closing
## column is hurt and put in the nearest open one. Once the last column has closed, they all hold shut for hold_time,
## then reopen and carry on bobbing. Needs a ChromaPillars in the arena; without one it's never picked.

@export_group("Versions")
@export var from_right_weight := 1.0
@export var from_left_weight := 1.0
@export var both_sides_weight := 1.0
## Column left open by the version closing from the right, counting from 0 at the left
@export var from_right_open_column := 0
## Column left open by the version closing from the left, counting from 0 at the left. The last column (7 with 8
## columns) leaves the far right open, so the player outruns the wave; 0 leaves the far left open instead
@export var from_left_open_column := 7
## Columns left open in the middle by the version closing from both sides
@export var center_open_columns := 2

@export_group("Timing")
## Seconds between one column starting its warning and the next one starting
@export var step_delay := 0.6
## Seconds each column's red warning takes to fade in and back out before it slams
@export var warning_time := 1.0
## Speed each pillar moves at as the column slams shut
@export var slam_speed := 2500.0
## Seconds every column stays shut after the last one closes
@export var hold_time := 1.0
## Seconds Chroma stands still after the columns reopen before his next move
@export var recover_time := 0.5
@export var damage := 30

enum Phase { CLOSING, HOLD, REOPEN, RECOVER }
var phase := Phase.CLOSING
var timer := 0.0
var pillars: ChromaPillars
## For each column, how many steps into the wave it closes, or -1 to stay open; empty until the version is picked
var steps: Array[int] = []
var open_columns: Array[int] = []

func can_start(_player: Node2D) -> bool:
	pillars = get_tree().get_first_node_in_group("chroma_pillars") as ChromaPillars
	return pillars != null and pillars.is_visible_in_tree() and not pillars.is_busy()

## The nearest open column's middle, along the ceiling
func reposition_point(_player: Node2D) -> Vector2:
	_plan()
	return Vector2(pillars.column_center_x(_nearest_open()), boss.global_position.y)

## Standing on the ceiling with his whole body inside an open column
func in_position(_player: Node2D) -> bool:
	_plan()
	if not boss.is_on_floor():
		return false
	var i := pillars.column_at(boss.global_position.x)
	var left := pillars.column_left(i)
	var x := boss.global_position.x
	return i in open_columns and x - boss.half_size.x >= left and x + boss.half_size.x <= left + pillars.column_width()

func start(_player: Node2D) -> void:
	_plan()
	pillars.safe_columns = open_columns.duplicate()
	pillars.hold_all()
	for i in steps.size():
		if steps[i] >= 0:
			pillars.close_column(i, steps[i] * step_delay, warning_time, slam_speed, damage)
	if not pillars.hurt_player.is_connected(boss.on_player_hurt):
		pillars.hurt_player.connect(boss.on_player_hurt)
	phase = Phase.CLOSING
	timer = 0.0

func tick(_player: Node2D, delta: float) -> bool:
	timer += delta
	match phase:
		Phase.CLOSING:
			if not pillars.is_closing():
				phase = Phase.HOLD
				timer = 0.0
		Phase.HOLD:
			if timer >= hold_time:
				pillars.release_all()
				phase = Phase.REOPEN
		Phase.REOPEN:
			if not pillars.is_busy():
				phase = Phase.RECOVER
				timer = 0.0
		Phase.RECOVER:
			return timer >= recover_time
	return false

func finish() -> void:
	# Cut short, or never started: let the columns go so nothing stays shut
	if is_instance_valid(pillars) and not steps.is_empty() and pillars.is_busy():
		pillars.release_all()
	steps.clear()
	open_columns.clear()

## Picks the version and works out which step each column closes on, once per use
func _plan() -> void:
	if not steps.is_empty():
		return
	var n := pillars.columns
	var total := from_right_weight + from_left_weight + both_sides_weight
	var roll := randf() * total
	steps.resize(n)
	if roll < from_right_weight:
		var open := clampi(from_right_open_column, 0, n - 1)
		var step := 0
		for i in range(n - 1, -1, -1):
			steps[i] = -1 if i == open else step
			if i != open:
				step += 1
	elif roll < from_right_weight + from_left_weight:
		var open := clampi(from_left_open_column, 0, n - 1)
		var step := 0
		for i in n:
			steps[i] = -1 if i == open else step
			if i != open:
				step += 1
	else:
		var middle := (n - 1) / 2.0
		for i in n:
			var from_middle := absf(i - middle)
			steps[i] = -1 if from_middle < center_open_columns / 2.0 else mini(i, n - 1 - i)
	open_columns.clear()
	for i in n:
		if steps[i] < 0:
			open_columns.append(i)
	if open_columns.is_empty():
		open_columns.append(0)
		steps[0] = -1

func _nearest_open() -> int:
	var here := pillars.column_at(boss.global_position.x)
	var best := open_columns[0]
	for i in open_columns:
		if absi(i - here) < absi(best - here):
			best = i
	return best

## Summons the pillars for the whole move
func anim_state() -> StringName:
	return &"summon_pillars"
