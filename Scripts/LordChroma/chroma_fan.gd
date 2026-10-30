class_name ChromaFan
extends Area2D

## A fan-shaped area with its point at its own position, used by Lord Chroma's attacks. While a warning it only draws;
## while active it hurts each player inside once.

## Emitted when the fan takes health off a player; a hit that the player's i-frames ignore doesn't count
signal hurt_player(body: Node2D)

var radius := 400.0
## Full width of the fan in degrees
var spread := 90.0
## Which way the middle of the fan points
var direction := Vector2.RIGHT
var damage := 15
var knockback := Vector2(500, -500)
var warning_color := Color(1, 0, 0, 0.25)
var active_color := Color(1, 0, 0, 0.6)
var active := false:
	set(value):
		active = value
		queue_redraw()

var points := PackedVector2Array()
var hit_bodies: Array[Node] = []

func _ready() -> void:
	var segments := maxi(int(spread / 5.0), 2)
	points.append(Vector2.ZERO)
	for i in segments + 1:
		var angle := direction.angle() + deg_to_rad(-spread / 2 + spread * i / segments)
		points.append(Vector2.from_angle(angle) * radius)
	var polygon := CollisionPolygon2D.new()
	polygon.polygon = points
	add_child(polygon)
	monitorable = false
	z_index = 5

func _physics_process(_delta: float) -> void:
	if not active:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("Player") and body not in hit_bodies:
			hit_bodies.append(body)
			var push_dir := signf(body.global_position.x - global_position.x)
			if push_dir == 0:
				push_dir = 1.0
			if body.has_method("SetKnockback"):
				body.SetKnockback(Vector2(push_dir * knockback.x, knockback.y))
			if body.has_method("GetDamaged"):
				var health_before = body.get("health")
				body.GetDamaged(damage)
				if health_before != null and body.get("health") < health_before:
					hurt_player.emit(body)

func _draw() -> void:
	draw_colored_polygon(points, active_color if active else warning_color)
