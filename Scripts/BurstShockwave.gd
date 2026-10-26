extends Node2D

## Spawned by Hue's burst: a ring that grows outward with the projectile front, and hits and pushes away each enemy it reaches, once

var speed := 1500.0  ## Pixels per second the ring grows, matching the burst projectiles; set by Hue before it's added
var max_radius := 200.0  ## The ring stops growing here
var damage := 10.0
var push_speed := 300.0  ## Speed added to each enemy hit, directly away from the ring's center
var push_drain_time := 0.2  ## Seconds for that push to drain away to nothing
var ring_color := Color(1, 1, 1)
## Hue, which gets on_attack_kill
var shooter: Node2D

var radius := 0.0
var hit_enemies: Array[Node] = []
## Enemies still being pushed, each with what's left of its push
var pushes: Array[Dictionary] = []

func _physics_process(delta: float) -> void:
	if radius < max_radius:
		radius = minf(radius + speed * delta, max_radius)
		_hit_enemies_in_range()
	_push_enemies(delta)
	queue_redraw()
	if radius >= max_radius and pushes.is_empty():
		queue_free()

func _hit_enemies_in_range() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is enemy) or node in hit_enemies:
			continue
		var offset: Vector2 = node.global_position - global_position
		if offset.length() > radius:
			continue
		hit_enemies.append(node)
		var health_before: int = node.health
		node.take_damage(damage)
		if health_before > 0 and node.health <= 0 and is_instance_valid(shooter) and shooter.has_method("on_attack_kill"):
			shooter.on_attack_kill()
		# An enemy right on the center gets pushed up
		var away := offset.normalized() if offset != Vector2.ZERO else Vector2.UP
		pushes.append({"enemy": node, "velocity": away * push_speed})

## Moves each pushed enemy on top of its own movement, with the push easing to zero over push_drain_time
func _push_enemies(delta: float) -> void:
	var still_pushing: Array[Dictionary] = []
	for push in pushes:
		var target = push["enemy"]
		var push_velocity: Vector2 = push["velocity"]
		if not is_instance_valid(target) or push_velocity == Vector2.ZERO:
			continue
		target.move_and_collide(push_velocity * delta)
		push["velocity"] = push_velocity.move_toward(Vector2.ZERO, push_speed / push_drain_time * delta)
		still_pushing.append(push)
	pushes = still_pushing

func _draw() -> void:
	# Fades out as it reaches its full size
	var fade := 1.0 - radius / max_radius if max_radius > 0 else 0.0
	if fade > 0:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(ring_color, fade), 3.0)
