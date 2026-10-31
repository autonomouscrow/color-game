extends Node2D

var playerInArea: bool = false

@export var color: int

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		playerInArea = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		playerInArea = false

func _unhandled_input(event: InputEvent) -> void:
	if playerInArea and event.is_action_pressed("interact"):
		var player = get_tree().get_first_node_in_group("Player")
		player.unlockColor(color)
