extends Area2D

@onready var hitbox: CollisionShape2D = $Hitbox
@onready var color_rect: ColorRect = $Color

var hitbox_shape: RectangleShape2D

func _ready() -> void:
	# Own copy of the shape so resizing it doesn't affect other hitboxes
	hitbox_shape = hitbox.shape.duplicate()
	hitbox.shape = hitbox_shape

## Hue calls this every frame so the hitbox follows its squished shape (also used by the slam and dive hitboxes)
func set_rect(rect: Rect2) -> void:
	hitbox_shape.size = rect.size
	hitbox.position = rect.get_center()
	color_rect.size = rect.size
	color_rect.position = rect.position
