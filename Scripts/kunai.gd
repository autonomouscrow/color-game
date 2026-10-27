extends enemy

@export var speed: float = 500.0

func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _process(delta: float) -> void:
	velocity = transform.x * speed
	move_and_slide()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body.has_method("GetDamaged"):
			body.GetDamaged(15)
		die()
