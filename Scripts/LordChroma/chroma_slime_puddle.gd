class_name ChromaSlimePuddle
extends Area2D

## A puddle of slime left by a ChromaSlimeShot. Sits on top of whatever it landed on and rides along as that moves,
## like the green arena's bobbing pillars. While the player stands in it they're slowed to slow_factor of their speed
## and take dot_damage every dot_interval seconds, starting the moment they step in. Disappears after lifetime seconds,
## or once what it sits on is hidden, like when the arena stops being green. A green arena column slamming shut on it
## removes it too.

## Emitted when the puddle takes health off a player
signal hurt_player(body: Node2D)

## What the puddle sits on and follows
var ground: Node2D
## Width, then height, of the puddle
var size := Vector2(110, 14)
var lifetime := 15.0
var slow_factor := 0.5
var dot_damage := 3
var dot_interval := 0.5
var color := Color(0.3, 0.85, 0.3, 0.7)
## Drawn in place of the green rectangle when set, stretched to fit size, its bottom edge on the ground; the hitbox is unchanged
var texture: Texture2D
## Multiplies the fitted size of texture
var sprite_scale := Vector2.ONE
## Moves texture from where it's fitted
var sprite_offset := Vector2.ZERO
## Pixels the hitbox reaches down into the ground, so a player standing on it is surely touching it
const SINK := 4.0

## Where the puddle sits, from ground's position
var offset := Vector2.ZERO
var age := 0.0
## Seconds until the next damage tick while the player stays in
var dot_left := 0.0

func _ready() -> void:
	z_index = 4
	add_to_group("chroma_slime_puddle")
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size + Vector2(0, SINK)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, (SINK - size.y) / 2)
	add_child(collision)
	_add_sprite()

## Puts the puddle on the ground at point, the middle of its bottom edge
func stick_at(point: Vector2) -> void:
	global_position = point
	if is_instance_valid(ground):
		offset = point - ground.global_position

func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime or not is_instance_valid(ground) or not ground.is_visible_in_tree():
		queue_free()
		return
	global_position = ground.global_position + offset
	var touching := false
	for body in get_overlapping_bodies():
		if body.is_in_group("Player"):
			touching = true
			if body.has_method("apply_slow"):
				body.apply_slow(slow_factor, delta * 2)
			if dot_left <= 0 and body.has_method("GetDamaged"):
				var health_before = body.get("health")
				body.GetDamaged(dot_damage)
				if health_before != null and body.get("health") < health_before:
					hurt_player.emit(body)
	if touching:
		if dot_left <= 0:
			dot_left = dot_interval
		dot_left -= delta
	else:
		dot_left = 0.0

func _draw() -> void:
	if texture == null:
		draw_rect(Rect2(-size.x / 2, -size.y, size.x, size.y), color)

## Adds texture as a sprite fitted to size, if there is one; _draw only draws the plain shape without one
func _add_sprite() -> void:
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = size / texture.get_size() * sprite_scale
	sprite.position = Vector2(0, -size.y / 2) + sprite_offset
	add_child(sprite)
