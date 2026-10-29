extends Node2D

# Register your rooms here or fill this in the Inspector
@export var room_scenes: Dictionary = {
	"test": "res://Scenes/Rooms/TestRoom.tscn",
	"test2": "res://Scenes/Rooms/TestRoom2.tscn",
	"Start": "res://Scenes/Rooms/start.tscn",
	"Green1": "res://Scenes/Rooms/Green1.tscn",
	"Green2": "res://Scenes/Rooms/Green2.tscn",
	"Green3": "res://Scenes/Rooms/Green3.tscn",
	"GreenHonse": "res://Scenes/Rooms/GreenHonse.tscn",
	"Red1": "res://Scenes/Rooms/red_1.tscn",
	"Red2": "res://Scenes/Rooms/red_2.tscn",
	"Blue1": "res://Scenes/Rooms/Blue1.tscn",
	"Blue2": "res://Scenes/Rooms/Blue2.tscn",
	"yellow1": "res://Scenes/Rooms/yellow_1.tscn"
}
@export var Hue: CharacterBody2D
@export var spawnControl: Node2D

var current_room: Node2D = null
var player: CharacterBody2D = null

func _ready() -> void:
	current_room = get_tree().get_first_node_in_group("Room")

func change_room(target_room_id: String, target_door_id: String) -> void:
	if not room_scenes.has(target_room_id):
		push_error("Room ID '" + target_room_id + "' not found in room_scenes")
		return

	if not player:
		player = get_tree().get_first_node_in_group("Player")
	
	var container = get_tree().current_scene.find_child("RoomContainer", true, false)

	# Cache enemy info
	current_room.checkDead()
	spawnControl.addRoom(current_room.name, current_room.EnemiesLiving)
	
	# Remove old room
	if current_room:
		current_room.queue_free()
		await get_tree().process_frame

	# Load and instantiate new room
	var room_res = load(room_scenes[target_room_id]) as PackedScene
	if not room_res:
		push_error("Failed to load scene file at: " + room_scenes[target_room_id])
		return

	current_room = room_res.instantiate()
	container.add_child(current_room)
	
	# Check enemies in room
	if spawnControl.checkDictionary(current_room.name):
		current_room.setEnemiesLiving(spawnControl.getEnemyList(current_room.name))
	else:
		current_room.allLiving()
	
	current_room.PurgeEnemies()

	# Position player immediately (REMOVED the 'await get_tree().process_frame' here)
	_apply_frame_from_room(current_room)
	_position_player_at_door(target_door_id)

func _position_player_at_door(door_id: String) -> void:
	if not player or not current_room:
		return

	var spawn_node: Node2D = null

	var exact_match = current_room.find_child(door_id, true, false)
	if exact_match and exact_match is Node2D:
		spawn_node = exact_match
	else:
		for child in current_room.find_children("*", "Node2D", true, false):
			if child.name.to_lower() == door_id.to_lower():
				spawn_node = child
				break

	if spawn_node:
		# 1. Teleport the player
		player.global_position = spawn_node.global_position
		
		# 2. Reset Physics Interpolation (for Godot 4.3+)
		if player.has_method("reset_physics_interpolation"):
			player.reset_physics_interpolation()

		# 3. Snap Camera, Drag Margins, and Smoothing
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam:
			cam.align()                # Centers the camera & drag margins on the target
			cam.force_update_scroll()  # Forces Godot to calculate scroll immediately
			cam.reset_smoothing()      # Clears smoothing buffer to prevent panning
			if cam.has_method("reset_physics_interpolation"):
				cam.reset_physics_interpolation()
	else:
		push_error("Door/Spawn ID '" + door_id + "' not found")
		

func _apply_frame_from_room(room: Node2D) -> void:
	var left: int = 0
	var top: int = 0
	var right: int = 0
	var bottom: int = 0
	var found: bool = false

	for node in room.find_children("*", "", true, false):
		if node is Area2D:
			for child in node.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					# Multiply shape size by the node's global scale!
					var scale_factor: Vector2 = child.global_scale.abs()
					var size: Vector2 = child.shape.size * scale_factor
					var pos: Vector2 = child.global_position
					
					left = int(pos.x - (size.x / 2.0))
					top = int(pos.y - (size.y / 2.0))
					right = int(pos.x + (size.x / 2.0))
					bottom = int(pos.y + (size.y / 2.0))
					found = true
					break
		
		elif node is CollisionShape2D and node.shape is RectangleShape2D:
			var scale_factor: Vector2 = node.global_scale.abs()
			var size: Vector2 = node.shape.size * scale_factor
			var pos: Vector2 = node.global_position
			left = int(pos.x - (size.x / 2.0))
			top = int(pos.y - (size.y / 2.0))
			right = int(pos.x + (size.x / 2.0))
			bottom = int(pos.y + (size.y / 2.0))
			found = true
		if found:
			break

	if not found:
		push_error("WARNING: Could not find frame in ", room.name)
		return

	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam and cam.has_method("set_room_limits"):
		cam.set_room_limits(left, top, right, bottom)
