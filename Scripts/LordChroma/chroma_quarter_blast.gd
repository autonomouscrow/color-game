extends ChromaMove

## Chroma teleports to the middle of the arena, frozen in the air, and raises the airbrush, then shows red warning fans one at a time, each
## pointing a random one of N, NE, E, SE, S, SW, W and NW (repeats allowed). Each warning fades in, fades out, then a
## short gap before the next. After the last warning and a pause, the fans blast one at a time in the same order. The first use has blast_counts[0] fans, the next blast_counts[1] and so
## on; after the list runs out, each use has between min_blasts and max_blasts.

## Seconds raising the airbrush before the first warning shows
@export var raise_time := 0.3
## Seconds each warning takes to fade in from invisible, and again to fade back out
@export var warning_fade_time := 0.5
## Seconds with no warning showing after each one fades out
@export var warning_gap := 0.5
## Seconds between the last warning going away and the first blast
@export var pause_time := 2.0
## Fans in each of the first uses of this move, in order
@export var blast_counts: Array[int] = [2, 4, 6]
## Fans in each later use: a random count from min_blasts to max_blasts
@export_range(1, 8) var min_blasts := 6
@export_range(1, 8) var max_blasts := 6
## Seconds each blast's hitbox stays out; the next blast starts when it ends
@export var blast_time := 1.5
## Seconds Chroma stands still after the last blast before its next move
@export var recover_time := 0.6
## Distance from Chroma's center to the round edge of each fan; the screen is 1280 x 720
@export var reach := 1000.0
## Full width of each fan in degrees
@export_range(1, 180) var spread := 90.0
## Damage from each blast; a player is hit at most once per blast
@export var damage := 60
@export var knockback := Vector2(900, -600)
@export var warning_color := Color(1, 0, 0, 0.25)
@export var blast_color := Color(1, 0.1, 0.1, 0.7)

enum Phase { RAISE, WARNING, PAUSE, BLAST, RECOVER }
var phase := Phase.RAISE
var timer := 0.0
## How many times this move has started, for picking the fan count
var uses := 0
## Fan directions in the order they're shown and fired
var directions: Array[Vector2] = []
## Index into directions of the fan showing now
var index := 0
var fan: ChromaFan

func start(_player: Node2D) -> void:
	var count: int
	if uses < blast_counts.size():
		count = blast_counts[uses]
	else:
		count = randi_range(mini(min_blasts, max_blasts), maxi(min_blasts, max_blasts))
	uses += 1
	directions.clear()
	for i in maxi(count, 1):
		directions.append(Vector2.from_angle(randi_range(0, 7) * PI / 4))
	# No walking first: Chroma teleports straight to the middle of the arena and hangs there, out of gravity's reach,
	# until the move ends
	if boss.arena_center:
		boss.global_position = boss.arena_center.global_position
	boss.frozen = true
	index = 0
	phase = Phase.RAISE
	timer = 0.0

func tick(_player: Node2D, delta: float) -> bool:
	timer += delta
	match phase:
		Phase.RAISE:
			boss.show_airbrush(Vector2.UP, timer / raise_time if raise_time > 0 else 1.0)
			if timer >= raise_time:
				phase = Phase.WARNING
				_show_fan(0, false)
		Phase.WARNING:
			if is_instance_valid(fan):
				var fade := minf(timer, 2 * warning_fade_time - timer) / warning_fade_time if warning_fade_time > 0 else 1.0
				fan.modulate.a = clampf(fade, 0.0, 1.0)
				if timer >= 2 * warning_fade_time:
					_clear_fan()
			if timer >= 2 * warning_fade_time + warning_gap:
				if index + 1 < directions.size():
					_show_fan(index + 1, false)
				else:
					_clear_fan()
					boss.show_airbrush(Vector2.UP)
					phase = Phase.PAUSE
					timer = 0.0
		Phase.PAUSE:
			if timer >= pause_time:
				phase = Phase.BLAST
				_show_fan(0, true)
		Phase.BLAST:
			if timer >= blast_time:
				if index + 1 < directions.size():
					_show_fan(index + 1, true)
				else:
					_clear_fan()
					boss.hide_airbrush()
					phase = Phase.RECOVER
					timer = 0.0
		Phase.RECOVER:
			return timer >= recover_time
	return false

func finish() -> void:
	_clear_fan()
	boss.frozen = false

## Replaces the fan showing now with fan i, as a warning or as a blast
func _show_fan(i: int, blast: bool) -> void:
	_clear_fan()
	index = i
	timer = 0.0
	fan = ChromaFan.new()
	fan.radius = reach
	fan.spread = spread
	fan.direction = directions[i]
	fan.damage = damage
	fan.knockback = knockback
	fan.warning_color = warning_color
	fan.active_color = blast_color
	fan.active = blast
	fan.hurt_player.connect(boss.on_player_hurt)
	if not blast:
		fan.modulate.a = 0.0
	boss.add_child(fan)
	boss.show_airbrush(directions[i])

func _clear_fan() -> void:
	if is_instance_valid(fan):
		fan.queue_free()
	fan = null
