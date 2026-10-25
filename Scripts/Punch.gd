extends Area2D

## Full size of the hitbox once it has finished extending
@export var size := Vector2(53, 48)
## Seconds to extend from zero length at Hue's side out to full size
@export var extend_time := 0.1
## Seconds the hitbox stays at full size before it disappears
@export var hold_time := 0.1
## Which way the hitbox extends from its origin: right, left or up; set by Hue before it's added
@export var direction := Vector2.RIGHT

@onready var hitbox: CollisionShape2D = $Hitbox
@onready var color_rect: ColorRect = $Color

var hitbox_shape: RectangleShape2D
var time := 0.0

func _ready() -> void:
	# Own copy of the shape so growing it doesn't affect other hitboxes
	hitbox_shape = hitbox.shape.duplicate()
	hitbox.shape = hitbox_shape
	_apply_length(0.0)

func _physics_process(delta: float) -> void:
	time += delta
	if time >= extend_time + hold_time:
		queue_free()
		return
	var progress := 1.0 if extend_time <= 0 else minf(time / extend_time, 1.0)
	_apply_length(progress)

func _apply_length(progress: float) -> void:
	# The origin is the edge nearest Hue; only the side facing direction grows, away from Hue
	var current_size := size
	if direction.x != 0:
		current_size.x *= progress
	else:
		current_size.y *= progress
	var center := direction * current_size / 2
	hitbox_shape.size = current_size
	hitbox.position = center
	color_rect.size = current_size
	color_rect.position = center - current_size / 2
