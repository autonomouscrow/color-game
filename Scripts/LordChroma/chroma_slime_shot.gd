class_name ChromaSlimeShot
extends Node2D

## A blob of slime Lord Chroma lobs in green. Flies in an arc under its own gravity until it lands on top of something,
## where it leaves a ChromaSlimePuddle that rides along on whatever it landed on. Hitting the side or underside of
## something stops it going that way and it drops on down. Passes through the player.

## Never emitted by the shot itself; anything connected to it is connected to the puddle the shot leaves, which emits
## it when it takes health off a player
signal hurt_player(body: Node2D)

var velocity := Vector2.ZERO
var gravity := 1500.0
var radius := 12.0
var color := Color(0.3, 0.85, 0.3)
## Drawn in place of the green circle when set, stretched to fit the circle's width (radius * 2); the hitbox is unchanged
var texture: Texture2D
## Multiplies the fitted size of texture
var sprite_scale := Vector2.ONE
## Moves texture from where it's fitted
var sprite_offset := Vector2.ZERO
## Seconds before the shot disappears if it never lands
var lifetime := 5.0
## Settings handed to the puddle it leaves
var puddle_size := Vector2(110, 14)
var puddle_time := 15.0
var slow_factor := 0.5
var dot_damage := 3
var dot_interval := 0.5
var puddle_color := Color(0.3, 0.85, 0.3, 0.7)
var puddle_texture: Texture2D
var puddle_sprite_scale := Vector2.ONE
var puddle_sprite_offset := Vector2.ZERO

var age := 0.0

func _ready() -> void:
	z_index = 5
	_add_sprite()

func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	velocity.y += gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(from, to + velocity.normalized() * radius)
	var exclude: Array[RID] = []
	for node in get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("enemy"):
		if node is CollisionObject2D:
			exclude.append(node.get_rid())
	query.exclude = exclude
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		queue_redraw()
		return
	var normal: Vector2 = hit["normal"]
	if normal.y < -0.5:
		_land(hit["collider"], hit["position"])
		return
	# A side stops it going sideways, an underside stops it going up; either way it drops on down
	global_position = hit["position"] + normal * (radius + 1)
	if absf(normal.x) > 0.5:
		velocity.x = 0.0
	else:
		velocity.y = maxf(velocity.y, 0.0)

func _land(body: Object, point: Vector2) -> void:
	var puddle := ChromaSlimePuddle.new()
	puddle.ground = body as Node2D
	puddle.size = puddle_size
	puddle.lifetime = puddle_time
	puddle.slow_factor = slow_factor
	puddle.dot_damage = dot_damage
	puddle.dot_interval = dot_interval
	puddle.color = puddle_color
	puddle.texture = puddle_texture
	puddle.sprite_scale = puddle_sprite_scale
	puddle.sprite_offset = puddle_sprite_offset
	# The puddle outlives the shot, so whoever listens to the shot listens to the puddle instead
	for connection in hurt_player.get_connections():
		puddle.hurt_player.connect(connection["callable"])
	get_parent().add_child(puddle)
	puddle.stick_at(point)
	queue_free()

func _draw() -> void:
	if texture == null:
		draw_circle(Vector2.ZERO, radius, color)

## Adds texture as a sprite fitted to Vector2.ONE * radius * 2, if there is one; _draw only draws the plain shape without one
func _add_sprite() -> void:
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * radius * 2 / texture.get_size() * sprite_scale
	sprite.position = sprite_offset
	add_child(sprite)
