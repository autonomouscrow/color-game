extends Node2D

# Register your rooms here or fill this in the Inspector
@export var room_scenes: Dictionary = {
	"test": "res://Scenes/Rooms/TestRoom.tscn",
	"test2": "res://Scenes/Rooms/TestRoom2.tscn"
	
}
@export var Hue: CharacterBody2D

@export var spawnControl: Node2D

var current_room: Node2D = null
var player: CharacterBody2D = null

func _ready() -> void:
	current_room = get_tree().get_first_node_in_group("Room")
	return

func change_room(target_room_id: String, target_door_id: String) -> void:
	# Check if room exists in dictionary
	if not room_scenes.has(target_room_id):
		push_error("Room ID '" + target_room_id + "' not found in room_scenes")
		return

	# Cache player if not already found
	if not player:
		player = get_tree().get_first_node_in_group("Player")
	
	# Find RoomContainer safely
	var container = get_tree().current_scene.find_child("RoomContainer", true, false)

	#cach all enemy information
	spawnControl.addRoom(current_room.name,current_room.Enemies)

	# Remove old room
	if current_room:
		current_room.queue_free()
		# Wait for it to be removed so collision shapes clean up
		await get_tree().process_frame

	# Load and instantiate new room
	var room_res = load(room_scenes[target_room_id]) as PackedScene
	if not room_res:
		push_error("Failed to load scene file at: " + room_scenes[target_room_id])
		return

	current_room = room_res.instantiate()
	container.add_child(current_room)
	
	#check enemies in room
	if spawnControl.checkDictionary(current_room.name):
		pass
	else:
		pass

	await get_tree().process_frame

	# Position Player
	_position_player_at_door(target_door_id)

func _position_player_at_door(door_id: String) -> void:
	if not player or not current_room:
		return

	# Search for the spawn point/marker (case-insensitive fallback)
	var spawn_node: Node2D = null

	# Exact match check
	var exact_match = current_room.find_child(door_id, true, false)
	if exact_match and exact_match is Node2D:
		spawn_node = exact_match
	else:
		# Case-insensitive fallback search in case of typos (e.g. "leftdoor" vs "LeftDoor")
		for child in current_room.find_children("*", "Node2D", true, false):
			if child.name.to_lower() == door_id.to_lower():
				spawn_node = child
				break

	if spawn_node:
		player.global_position = spawn_node.global_position
	else:
		push_error("Door/Spawn ID '" + door_id + "' not found")
