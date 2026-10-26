class_name Bullet
extends Attack

## Fired by Hue's gun along direction (set by Hue, normalized); flies straight until it hits an enemy or a wall, or lifetime runs out

@export var speed := 2000.0  ## Pixels per second, set by Hue before it's added
@export var lifetime := 5.0  ## Seconds before the bullet disappears if it hasn't hit anything
@export var bullet_size := Vector2(20, 10)  ## Length along the flight direction, then width

## Hue, which gets on_attack_kill and is never hit by its own bullet
var shooter: Node2D

func _ready() -> void:
	timed = false
	super._ready()
	set_rect(Rect2(-bullet_size / 2, bullet_size))
	rotation = direction.angle()
	body_entered.connect(_on_wall_entered)

func _physics_process(delta: float) -> void:
	time += delta
	if time >= lifetime:
		queue_free()
		return
	var motion := direction * speed * delta
	# At this speed the bullet moves several times its own length each frame, so a ray checks the path for anything it would skip over
	if _check_path(motion):
		return
	global_position += motion

## Returns true when something on the path stopped the bullet
func _check_path(motion: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion + direction * bullet_size.x / 2, collision_mask)
	query.collide_with_areas = true
	var exclude: Array[RID] = [get_rid()]
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		exclude.append(shooter.get_rid())
	var space := get_world_2d().direct_space_state
	for i in 8:
		query.exclude = exclude
		var result := space.intersect_ray(query)
		if result.is_empty():
			return false
		var collider: Object = result.collider
		if _stops_bullet(collider):
			global_position = result.position
			return true
		exclude.append(result.rid)
	return false

## Hits an enemy or stops on a wall; other areas (color zones, room bounds, enemy detection ranges) and enemy bodies with a hurtbox are passed through
func _stops_bullet(collider: Object) -> bool:
	if collider is Area2D:
		var target := (collider as Area2D).get_parent()
		if target is enemy and target.hurtbox == collider:
			_hit(target)
			return true
		return false
	if collider is enemy:
		if collider.hurtbox == null:
			_hit(collider)
			return true
		return false
	if collider == shooter:
		return false
	queue_free()
	return true

func _on_wall_entered(body: Node2D) -> void:
	if body is enemy or body == shooter:
		return
	queue_free()

func _hit(target: enemy) -> void:
	super._hit(target)
	queue_free()

func _kill_receiver() -> Node:
	return shooter
