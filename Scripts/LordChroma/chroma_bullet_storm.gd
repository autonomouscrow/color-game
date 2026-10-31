extends ChromaMove

## Chroma teleports to the middle of the arena, frozen in the air. Each wave shows bullets_per_wave line warnings evenly
## spaced around him, fading in and out, then after release_pause fires a straight dart down each line; darts pass
## through walls and platforms. The next wave's warnings start right as a wave fires, turned to sit exactly between
## the last wave's lines. The move lasts until every dart has left the arena, so they all count toward the dodge.

@export var waves := 4
@export var bullets_per_wave := 32
## Seconds each wave's warnings take to fade in, and again to fade out; matches the quarter blast's warnings
@export var warning_fade_time := 0.5
## Seconds between the warnings fading out and the darts firing
@export var release_pause := 0.3
@export var line_width := 30.0
## How far each warning line reaches from Chroma's center
@export var line_length := 2200.0
@export var warning_color := Color(1, 0, 0, 0.35)
## Length along the flight direction, then width
@export var dart_size := Vector2(20, 10)
@export var speed := 750.0
@export var damage := 10
@export var knockback := Vector2(300, -300)
## Seconds before a dart disappears; long enough to cross the arena
@export var lifetime := 12.0
## Darts disappear on reaching the edge of this area, centered on the arena's middle; the move ends once they're all
## gone
@export var clear_area_size := Vector2(1920, 900)
## Seconds Chroma stays frozen after the last wave fires, before his next move
@export var recover_time := 0.6
@export var dart_color := Color(1, 0.3, 0.3)

var wave := 0
var timer := 0.0
## Angle of the first line in the current wave
var angle_offset := 0.0
var recovering := false
var lines: Node2D
var darts: Array[ChromaDart] = []

func start(_player: Node2D) -> void:
	if boss.arena_center:
		boss.global_position = boss.arena_center.global_position
	boss.frozen = true
	wave = 0
	timer = 0.0
	angle_offset = 0.0
	recovering = false
	darts.clear()
	lines = Node2D.new()
	lines.z_index = 5
	lines.draw.connect(_draw_lines)
	boss.add_child(lines)

func tick(_player: Node2D, delta: float) -> bool:
	timer += delta
	if recovering:
		darts.assign(darts.filter(func(d): return is_instance_valid(d)))
		if not darts.is_empty():
			timer = 0.0
		return timer >= recover_time
	lines.queue_redraw()
	if timer >= 2 * warning_fade_time + release_pause:
		_release()
		wave += 1
		timer = 0.0
		angle_offset += PI / bullets_per_wave
		if wave >= waves:
			recovering = true
			lines.queue_free()
	return false

func finish() -> void:
	if is_instance_valid(lines):
		lines.queue_free()
	boss.frozen = false

func _release() -> void:
	for i in bullets_per_wave:
		var dart := ChromaDart.new()
		dart.direction = Vector2.from_angle(angle_offset + TAU * i / bullets_per_wave)
		dart.size = dart_size
		dart.speed = speed
		dart.damage = damage
		dart.knockback = knockback
		dart.color = dart_color
		dart.lifetime = lifetime
		dart.pass_through_walls = true
		dart.bounds = Rect2(boss.arena_middle() - clear_area_size / 2, clear_area_size)
		dart.hurt_player.connect(boss.on_player_hurt)
		darts.append(dart)
		boss.get_parent().add_child(dart)
		dart.global_position = boss.global_position

## Fades in over warning_fade_time, back out over the same, then nothing during the pause
func _draw_lines() -> void:
	var fade := minf(timer, 2 * warning_fade_time - timer) / warning_fade_time if warning_fade_time > 0 else 1.0
	fade = clampf(fade, 0.0, 1.0)
	if fade <= 0:
		return
	var color := Color(warning_color, warning_color.a * fade)
	for i in bullets_per_wave:
		var dir := Vector2.from_angle(angle_offset + TAU * i / bullets_per_wave)
		lines.draw_line(Vector2.ZERO, dir * line_length, color, line_width)
