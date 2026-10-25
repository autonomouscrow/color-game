extends Node2D

@export var safeZone: Marker2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body.has_method("GetDamaged"):
				body.GetDamaged(30)
		body.global_position = safeZone.global_position
