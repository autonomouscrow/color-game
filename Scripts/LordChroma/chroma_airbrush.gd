extends ChromaMove

## Pulls out the airbrush, then sprays a fan left, right or up, whichever way the player was when the pull-out started.
## Chroma heads for the floor or platform the player is over, to stand beside them, until they're within reach.

## Seconds to pull the airbrush out; Chroma stands still meanwhile
@export var pull_out_time := 0.75
## Seconds the spray's hitbox stays out
@export var spray_time := 0.15
## Seconds Chroma stands still after spraying before its next move
@export var recover_time := 0.3
## Distance from the fan's point to its round edge; Hue's punch reaches about 100
@export var reach := 200.0
## Full width of the fan in degrees; a player within half of this of straight up gets sprayed upward
@export_range(1, 180) var spread := 90.0
@export var damage := 15
@export var knockback := Vector2(500, -400)
## Chroma starts once the player is within this fraction of reach, so a small step back doesn't dodge it for free
@export_range(0.1, 1.0) var reach_margin := 0.8
## Pixels past the edge of Chroma's hitbox, in the spray's direction, where the fan's point sits
@export var spray_edge_gap := 10.0
## Opacity of the spray, which is drawn in Chroma's current color
@export_range(0, 1) var spray_alpha := 0.6
@export_group("Warning")
## Shows where the spray will hit during the pull-out, before the hitbox comes out
@export var show_warning := true
## Color of the warning fan; leave alpha low so it reads as a warning, not the spray
@export var warning_color := Color(1, 0, 0, 0.25)
## Seconds into the pull-out before the warning appears; at or past pull_out_time there's no warning
@export var warning_delay := 0.0
## Seconds the warning takes to fade in from invisible once it appears
@export var warning_fade_time := 0.2
## Flashes the warning on and off this many times a second during the last stretch of the pull-out; 0 never flashes
@export var warning_flash_rate := 10.0
## Seconds before the spray when the flashing starts
@export var warning_flash_time := 0.25
@export_group("Spray Sprite")
## Animated spray art shown instead of the drawn fan. Drawn pointing right, its point at the middle of its left side,
## at its own size; the spray's hitbox stays the same. It plays to its end even after the hitbox is gone
@export var spray_frames: SpriteFrames
## Which animation in spray_frames plays; falls back to the first one
@export var spray_animation := &"default"
@export var spray_sprite_scale := Vector2.ONE
## Pixels the art is moved, in its own frame (x along the spray)
@export var spray_sprite_offset := Vector2.ZERO
@export_group("")

var timer := 0.0
var sprayed := false
var spray_dir := Vector2.RIGHT
var fan: ChromaFan
var warning: ChromaFan

## Beside the player, on whatever they're standing on or above; the near side, unless only the far side fits on it
func reposition_point(player: Node2D) -> Vector2:
	var center := boss.player_center(player)
	var side := signf(center.x - boss.global_position.x) if center.x != boss.global_position.x else boss.facing
	var offset := target_distance()
	if boss.is_flying():
		return Vector2(center.x - side * offset, center.y)
	var surface := boss.surface_under(player.global_position)
	if surface == null:
		return Vector2(center.x - side * offset, boss.global_position.y)
	var x := center.x - side * offset
	if x < surface.rect_left or x > surface.rect_right:
		var other := center.x + side * offset
		x = other if other >= surface.rect_left and other <= surface.rect_right else clampf(x, surface.rect_left, surface.rect_right)
	return Vector2(x, surface.top - boss.half_size.y)

## How far to the side of the player Chroma aims to stand
func target_distance() -> float:
	return reach * reach_margin * 0.5

func in_position(player: Node2D) -> bool:
	var to := boss.player_center(player) - boss.global_position
	return to.length() <= reach * reach_margin and absf(to.angle_to(_spray_dir(player))) <= deg_to_rad(spread / 2)

## The direction locks here, as the pull-out starts, and doesn't follow the player after
func start(player: Node2D) -> void:
	timer = 0.0
	sprayed = false
	spray_dir = _spray_dir(player)
	boss.face_toward(player.global_position.x)
	_clear_warning()

func tick(_player: Node2D, delta: float) -> bool:
	timer += delta
	if not sprayed:
		boss.show_airbrush(spray_dir, timer / pull_out_time if pull_out_time > 0 else 1.0)
		_update_warning()
		if timer >= pull_out_time:
			_clear_warning()
			_spray()
		return false
	if is_instance_valid(fan) and not fan.retired and timer >= spray_time:
		fan.retire()
	return timer >= spray_time + recover_time

func finish() -> void:
	_clear_warning()
	if is_instance_valid(fan) and not fan.retired:
		fan.retire()

## Shows, fades in and flashes the warning fan while the airbrush comes out
func _update_warning() -> void:
	if not show_warning or timer < warning_delay or timer >= pull_out_time:
		return
	if not is_instance_valid(warning):
		warning = _make_fan()
		warning.warning_color = warning_color
		warning.active = false
		warning.monitoring = false
		boss.add_child(warning)
	var shown := timer - warning_delay
	var alpha := clampf(shown / warning_fade_time, 0.0, 1.0) if warning_fade_time > 0 else 1.0
	if warning_flash_rate > 0 and pull_out_time - timer <= warning_flash_time:
		alpha *= 1.0 if fmod(timer * warning_flash_rate, 1.0) < 0.5 else 0.3
	warning.modulate.a = alpha

func _clear_warning() -> void:
	if is_instance_valid(warning):
		warning.queue_free()
	warning = null

func _spray() -> void:
	sprayed = true
	timer = 0.0
	fan = _make_fan()
	fan.damage = damage
	fan.knockback = knockback
	fan.active_color = Color(boss.color_rect.color, spray_alpha)
	fan.frames = spray_frames
	fan.frames_animation = spray_animation
	fan.sprite_pivot = Vector2(0, 0.5)
	fan.sprite_scale = spray_sprite_scale
	fan.sprite_offset = spray_sprite_offset
	fan.flip_when_left = true
	fan.active = true
	boss.add_child(fan)

## A fan in the spray's shape and spot; the warning and the spray both use it
func _make_fan() -> ChromaFan:
	var f := ChromaFan.new()
	f.radius = reach
	# Starts spray_edge_gap past his hitbox's side (or top) rather than at his center
	var edge := absf(spray_dir.x) * boss.half_size.x + absf(spray_dir.y) * boss.half_size.y
	f.position = spray_dir * (edge + spray_edge_gap)
	f.spread = spread
	f.direction = spray_dir
	return f

## Up for a player within half the spread of straight up, otherwise left or right
func _spray_dir(player: Node2D) -> Vector2:
	var to := boss.player_center(player) - boss.global_position
	if to != Vector2.ZERO and absf(to.angle_to(Vector2.UP)) <= deg_to_rad(spread / 2):
		return Vector2.UP
	return Vector2(signf(to.x) if to.x != 0 else boss.facing, 0)

func anim_state() -> StringName:
	return &"airbrush"
