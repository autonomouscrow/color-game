extends Marker2D

var playerInArea: bool = false

@onready var color: ColorRect = $ColorRect
@onready var skeff = get_tree().get_first_node_in_group("spawnSkeff")

@export var hide: bool = false

func _ready() -> void:
	color.color = Color8(255, 255, 255,255)
	if skeff.checkCanvas(name):
		color.color = Color8(0, 0, 0,255)
	if hide:
		color.color = Color8(0, 0, 0,0)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		playerInArea = true

func _unhandled_input(event: InputEvent) -> void:
	if not hide:
		if playerInArea and event.is_action_pressed("interact"):
			print("drawn")
			draw()

func draw() -> void:
	var room = get_tree().get_first_node_in_group("Room")
	skeff.SetSpawn(room.name,name)
	color.color = Color8(0, 0, 0,255)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		playerInArea = false
