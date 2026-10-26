extends Marker2D

var playerInArea: bool = false

@onready var color: ColorRect = $ColorRect
@onready var skeff = get_tree().get_first_node_in_group("spawnSkeff")

func _ready() -> void:
	color.color = Color8(255, 255, 255,255)
	if skeff.checkCanvas(name):
		color.color = Color8(0, 0, 0,255)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		playerInArea = true

func _unhandled_input(event: InputEvent) -> void:
	if playerInArea and event.is_action_pressed("interact"):
		_draw()

func _draw() -> void:
	var room = get_tree().get_first_node_in_group("Room")
	skeff.SetSpawn(room,name)
	color.color = Color8(0, 0, 0,255)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		playerInArea = false
