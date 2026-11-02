extends Marker2D

var playerInArea: bool = false

@onready var color: ColorRect = $ColorRect
@onready var skeff = get_tree().get_first_node_in_group("spawnSkeff")
@onready var animated_sprite = $AnimatedSprite2D
@export var hide: bool = false

func _ready() -> void:
	animated_sprite.play("Empty") 
	color.color = Color8(255, 255, 255,255)
	# Only the canvas in the spawn room counts, since several rooms have a node named "Canvas"
	if skeff.checkCanvas(name) and owner and skeff.SpawnRoom == owner.name:
		color.color = Color8(0, 0, 0,255)
		# Already the spawn point (e.g. set by the title screen's boss skip): show it painted
		animated_sprite.animation = &"Draw"
		animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count(&"Draw") - 1
	if hide:
		color.color = Color8(0, 0, 0,0)
		animated_sprite.visible = false

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
	animated_sprite.play("Draw") 
	color.color = Color8(0, 0, 0,255)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		playerInArea = false
