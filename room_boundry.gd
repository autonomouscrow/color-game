extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var CameraManager: Node2D

func _ready() -> void:
	# Listen for player entering
	CameraManager = get_tree().get_first_node_in_group("Camera")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		update_camera_limits()

func update_camera_limits() -> void:
	var rect_shape = collision_shape.shape as RectangleShape2D
	if not rect_shape:
		return
	
	# Calculate global pixel coordinates of the bounding box
	var true_size = rect_shape.size * collision_shape.global_scale
	var half_size = true_size * 0.5
	var center = collision_shape.global_position

	var left = int(center.x - half_size.x)
	var right = int(center.x + half_size.x)
	var top = int(center.y - half_size.y)
	var bottom = int(center.y + half_size.y)
	
	# Send limits to your CameraManager
	CameraManager.set_room_limits(left, top, right, bottom)
