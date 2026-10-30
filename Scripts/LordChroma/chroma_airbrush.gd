extends ChromaMove

## Pulls out the airbrush, then sprays a fan left, right or up, whichever way the player was when the pull-out started.
## Chroma heads for the floor or platform the player is over, to stand beside them, until they're within reach.

## Seconds to pull the airbrush out; Chroma stands still meanwhile
@export var pull_out_time := 0.75
## Seconds the spray's hitbox stays out
@export var spray_time := 0.15
## Seconds Chroma stands still after spraying before its next move
@export var recover_time := 0.3
## Distance from Chroma's center to the round edge of the fan; Hue's punch reaches about 100
@export var reach := 200.0
## Full width of the fan in degrees; a player within half of this of straight up gets sprayed upward
@export_range(1, 180) var spread := 90.0
@export var damage := 15
@export var knockback := Vector2(500, -400)
## Chroma starts once the player is within this fraction of reach, so a small step back doesn't dodge it for free
@export_range(0.1, 1.0) var reach_margin := 0.8
## Opacity of the spray, which is drawn in Chroma's current color
@export_range(0, 1) var spray_alpha := 0.6

var timer := 0.0
var sprayed := false
var spray_dir := Vector2.RIGHT
var fan: ChromaFan

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

func tick(_player: Node2D, delta: float) -> bool:
	timer += delta
	if not sprayed:
		boss.show_airbrush(spray_dir, timer / pull_out_time if pull_out_time > 0 else 1.0)
		if timer >= pull_out_time:
			_spray()
		return false
	if is_instance_valid(fan) and timer >= spray_time:
		fan.queue_free()
	return timer >= spray_time + recover_time

func finish() -> void:
	if is_instance_valid(fan):
		fan.queue_free()

func _spray() -> void:
	sprayed = true
	timer = 0.0
	fan = ChromaFan.new()
	fan.radius = reach
	fan.spread = spread
	fan.direction = spray_dir
	fan.damage = damage
	fan.knockback = knockback
	fan.active_color = Color(boss.color_rect.color, spray_alpha)
	fan.active = true
	boss.add_child(fan)

## Up for a player within half the spread of straight up, otherwise left or right
func _spray_dir(player: Node2D) -> Vector2:
	var to := boss.player_center(player) - boss.global_position
	if to != Vector2.ZERO and absf(to.angle_to(Vector2.UP)) <= deg_to_rad(spread / 2):
		return Vector2.UP
	return Vector2(signf(to.x) if to.x != 0 else boss.facing, 0)
