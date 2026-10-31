class_name ChromaContact
extends Area2D

## A rectangle (or circle) around Lord Chroma's body that hurts the player on touch while active; the blue dive and slide switch it
## on while Chroma is moving. Turning it on again lets it hit the same player again.

## Emitted when the contact takes health off a player; a hit that the player's i-frames ignore doesn't count
signal hurt_player(body: Node2D)

var size := Vector2(80, 160)
## Above 0, the contact is a circle of this radius instead of a size rectangle
var radius := 0.0
var damage := 20
var knockback := Vector2(600, -400)
var active := false:
	set(value):
		if value and not active:
			hit_bodies.clear()
		active = value

var hit_bodies: Array[Node] = []

func _ready() -> void:
	var shape_node := CollisionShape2D.new()
	if radius > 0:
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape_node.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = size
		shape_node.shape = rect
	add_child(shape_node)
	monitorable = false

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
