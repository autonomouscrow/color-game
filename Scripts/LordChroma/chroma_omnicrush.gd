extends ChromaMove

## Green ult. rounds times: Chroma teleports to the top of a random column, just under its ceiling pillar, and every
## other column shows a red warning for warning_time, then slams shut. A player caught in a closing column takes damage
## and is put in Chroma's column, the only one left open. The columns hold shut for hold_time, reopen, and the next
## round picks a different column. Needs a ChromaPillars in the arena; without one it's never picked.

@export var rounds := 3
## Seconds every other column's warning takes to fade in and back out before they slam
@export var warning_time := 2.0
## Speed each pillar moves at as its column slams shut
@export var slam_speed := 2500.0
@export var damage := 50
## Seconds the columns stay shut after slamming
@export var hold_time := 0.6
## Seconds between the columns finishing reopening and the next round's teleport
@export var round_gap := 0.3
## Seconds Chroma stays put after the last round, before his next move
@export var recover_time := 0.5

enum Phase { CLOSING, HOLD, REOPEN, GAP }
var phase := Phase.CLOSING
var timer := 0.0
var round_index := 0
var safe_column := -1
var pillars: ChromaPillars

func can_start(_player: Node2D) -> bool:
	pillars = get_tree().get_first_node_in_group("chroma_pillars") as ChromaPillars
	return pillars != null and pillars.is_visible_in_tree() and not pillars.is_busy()

func start(_player: Node2D) -> void:
	round_index = 0
	safe_column = -1
	if not pillars.hurt_player.is_connected(boss.on_player_hurt):
		pillars.hurt_player.connect(boss.on_player_hurt)
	_start_round()

func tick(_player: Node2D, delta: float) -> bool:
	timer += delta
	match phase:
		Phase.CLOSING:
			if not pillars.is_closing():
				_next(Phase.HOLD)
		Phase.HOLD:
			if timer >= hold_time:
				pillars.release_all()
				_next(Phase.REOPEN)
		Phase.REOPEN:
			if not pillars.is_busy():
				round_index += 1
				_next(Phase.GAP)
		Phase.GAP:
			if round_index >= rounds:
				return timer >= recover_time
			if timer >= round_gap:
				_start_round()
	return false

func finish() -> void:
	# Cut short: let the columns go so nothing stays shut
	if is_instance_valid(pillars) and pillars.is_busy():
		pillars.release_all()

## Holds the columns still, puts Chroma at the top of a new random column, and starts every other column closing
func _start_round() -> void:
	var options: Array[int] = []
	for i in pillars.columns:
		if i != safe_column:
			options.append(i)
	safe_column = options.pick_random()
	pillars.hold_all()
	pillars.safe_columns = [safe_column]
	var top := pillars.global_position.y + pillars.cols[safe_column].ceiling_height
	boss.teleport_to(Vector2(pillars.column_center_x(safe_column), top + boss.half_size.y))
	for i in pillars.columns:
		if i != safe_column:
			pillars.close_column(i, 0.0, warning_time, slam_speed, damage)
	_next(Phase.CLOSING)

func _next(p: Phase) -> void:
	phase = p
	timer = 0.0
