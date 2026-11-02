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

## Animated art shown in place of the drawn fan while it's active; warnings keep the drawn shape
var frames: SpriteFrames
var frames_animation := &"default"
## Point of the art that sits on the fan's point, as a fraction of the frame: (0, 0.5) is the middle of the left side,
## (0, 1) the lower left corner
var sprite_pivot := Vector2(0, 0.5)
## Angle the art points at when unrotated: 0 for art pointing right, -PI / 4 for art spreading up and to the right
var sprite_art_angle := 0.0
## Stretches the art so its frame is radius wide and tall; off keeps the art's own size
var stretch_to_radius := false
## Multiplies the art's size after any stretching
var sprite_scale := Vector2.ONE
## Pixels the art is moved, in its own unrotated frame, so it turns with the fan
var sprite_offset := Vector2.ZERO
## Flips the art top to bottom when the fan points left, so art pointing right isn't upside down
var flip_when_left := false
var sprite: AnimatedSprite2D
## Set by retire(): the hitbox is gone and nothing is drawn, but the art plays out
var retired := false

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
	_add_sprite()

func _add_sprite() -> void:
	if frames == null or frames.get_animation_names().is_empty():
		return
	var anim: StringName = frames_animation if frames.has_animation(frames_animation) else StringName(frames.get_animation_names()[0])
	var first := frames.get_frame_texture(anim, 0)
	var frame_size: Vector2 = first.get_size() if first else Vector2.ONE
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = -frame_size * sprite_pivot
	var size_scale: Vector2 = Vector2(radius / frame_size.x, radius / frame_size.y) if stretch_to_radius else Vector2.ONE
	sprite.scale = size_scale * sprite_scale
	if flip_when_left and direction.x < -0.01:
		sprite.scale.y = -sprite.scale.y
	sprite.rotation = direction.angle() - sprite_art_angle
	sprite.position = sprite_offset.rotated(sprite.rotation)
	sprite.visible = active
	add_child(sprite)
	sprite.play(anim)

## Ends the hitbox but lets the art finish its animation first, if it has one that ends; then the fan is freed
func retire() -> void:
	active = false
	retired = true
	set_deferred("monitoring", false)
	if sprite and sprite.is_playing() and not sprite.sprite_frames.get_animation_loop(sprite.animation):
		sprite.animation_finished.connect(queue_free)
	else:
		queue_free()

func _physics_process(_delta: float) -> void:
	if sprite and not retired:
		sprite.visible = active
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
	if retired or (active and sprite):
		return
	draw_colored_polygon(points, active_color if active else warning_color)
