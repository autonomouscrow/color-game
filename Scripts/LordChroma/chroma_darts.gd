extends ChromaMove

## Fires count homing darts one after another, each starting straight at the player. They turn slowly toward the
## player, steer away from walls ahead of them, and break on hitting one. Chroma first flies to the player's side,
## distance_multiple times as far from them as he gets for the airbrush.

@export var count := 4
## How far from the player Chroma shoots from, as a multiple of the airbrush's distance
@export var distance_multiple := 2.0
## Close enough to that spot to start shooting
@export var position_tolerance := 24.0
## Seconds between darts
@export var interval := 0.2
## Seconds Chroma waits after the last dart before his next move
@export var recover_time := 0.3
## Length along the flight direction, then width
@export var dart_size := Vector2(20, 10)
@export var speed := 450.0
## Degrees per second each dart can turn toward the player
@export var turn_rate := 45.0
## How far ahead each dart looks for walls to steer around
@export var avoid_distance := 120.0
@export var damage := 10
@export var knockback := Vector2(300, -300)
## Seconds before a dart that hasn't hit anything disappears
@export var lifetime := 10.0
@export var dart_color := Color(1, 0.3, 0.3)

var fired := 0
var timer := 0.0

## Level with the player, on the side Chroma is on, or the other side if that's outside where he can fly
func reposition_point(player: Node2D) -> Vector2:
	var center := boss.player_center(player)
	var side := signf(boss.global_position.x - center.x) if center.x != boss.global_position.x else -boss.facing
	var distance := _airbrush_distance() * distance_multiple
	var point := Vector2(center.x + side * distance, center.y)
	if boss.is_flying():
		var area := boss._fly_area()
		if point.x < area.position.x or point.x > area.end.x:
			point.x = center.x - side * distance
		point = point.clamp(area.position, area.end)
	return point

func in_position(player: Node2D) -> bool:
	return boss.global_position.distance_to(reposition_point(player)) <= position_tolerance

## How far from the player Chroma stands for the airbrush, read from his airbrush move
func _airbrush_distance() -> float:
	for move in boss.moves:
		if move.has_method("target_distance"):
			return move.target_distance()
	return 80.0

func start(_player: Node2D) -> void:
	fired = 0
	timer = interval

func tick(player: Node2D, delta: float) -> bool:
	timer += delta
	if fired < count:
		if timer >= interval:
			timer = 0.0
			_fire(player)
		return false
	return timer >= recover_time

func _fire(player: Node2D) -> void:
	fired += 1
	var dart := ChromaDart.new()
	dart.size = dart_size
	dart.speed = speed
	dart.damage = damage
	dart.knockback = knockback
	dart.color = dart_color
	dart.lifetime = lifetime
	dart.turn_rate = turn_rate
	dart.avoid_distance = avoid_distance
	dart.target = player
	dart.hurt_player.connect(boss.on_player_hurt)
	dart.direction = boss.global_position.direction_to(boss.player_center(player)) if player else Vector2(boss.facing, 0)
	boss.show_airbrush(dart.direction)
	# Added to the room rather than to Chroma, so darts keep flying after the move ends
	boss.get_parent().add_child(dart)
	dart.global_position = boss.global_position
