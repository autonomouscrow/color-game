class_name ChromaDart
extends Area2D

## A dart shot by Lord Chroma. Flies straight, or turns toward target at up to turn_rate while steering away from walls
## ahead of it. Hurts the player once and disappears; also disappears on hitting a wall, unless it passes through them.

## Emitted when the dart takes health off a player; a hit that the player's i-frames ignore doesn't count
signal hurt_player(body: Node2D)

var direction := Vector2.RIGHT
var speed := 150.0
## Length along the flight direction, then width
var size := Vector2(20, 10)
var damage := 10
var knockback := Vector2(300, -300)
var color := Color(1, 0.3, 0.3)
## Seconds before the dart disappears on its own
var lifetime := 10.0
## Homes in on this node while it's set and turn_rate is above 0
var target: Node2D
## Degrees per second the dart can turn
var turn_rate := 0.0
## How far ahead the dart looks for walls to steer around; 0 turns wall avoidance off
var avoid_distance := 0.0
var pass_through_walls := false
## The dart disappears on leaving this area; an empty one never applies
var bounds := Rect2()

var age := 0.0

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	monitorable = false
	z_index = 5
	direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime or (bounds.has_area() and not bounds.has_point(global_position)):
		queue_free()
		return
	if is_instance_valid(target) and turn_rate > 0:
		var desired := global_position.direction_to(_target_center())
		if avoid_distance > 0:
			desired = _avoid_walls(desired)
		var turn := clampf(direction.angle_to(desired), -deg_to_rad(turn_rate) * delta, deg_to_rad(turn_rate) * delta)
		direction = direction.rotated(turn)
	global_position += direction * speed * delta
	rotation = direction.angle()

func _draw() -> void:
	draw_rect(Rect2(-size / 2, size), color)

func _target_center() -> Vector2:
	var center := target.global_position
	var hitbox = target.get("hitbox")
	if hitbox:
		center += hitbox.position
	return center

## When a wall is ahead and closer than the target, turns away toward whichever side has more open space
func _avoid_walls(desired: Vector2) -> Vector2:
	var ahead := _clear_distance(direction)
	if ahead >= avoid_distance or ahead >= global_position.distance_to(_target_center()):
		return desired
	var left := direction.rotated(-PI / 3)
	var right := direction.rotated(PI / 3)
	return left if _clear_distance(left) > _clear_distance(right) else right

## Distance along dir to the nearest wall, up to avoid_distance
func _clear_distance(dir: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * avoid_distance)
	query.collide_with_areas = false
	var exclude: Array[RID] = []
	for node in get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("enemy"):
		if node is CollisionObject2D:
			exclude.append(node.get_rid())
	query.exclude = exclude
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return avoid_distance if hit.is_empty() else global_position.distance_to(hit["position"])

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		var push_dir := signf(direction.x) if direction.x != 0 else 1.0
		if body.has_method("SetKnockback"):
			body.SetKnockback(Vector2(push_dir * knockback.x, knockback.y))
		if body.has_method("GetDamaged"):
			var health_before = body.get("health")
			body.GetDamaged(damage)
			if health_before != null and body.get("health") < health_before:
				hurt_player.emit(body)
		queue_free()
	elif body is StaticBody2D and not pass_through_walls:
		queue_free()
