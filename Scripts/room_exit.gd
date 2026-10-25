class_name RoomExit
extends Area2D

# ID matching a key in your RoomController room dictionary (e.g., "cavern_01")
@export var target_room_id: String = ""

# The ID of the spawn point or door in the target room (e.g., "LeftDoor")
@export var target_door_id: String = ""

@export var RoomSkeff: Node2D

func _ready() -> void:
	RoomSkeff = get_tree().get_first_node_in_group("RoomControl")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		# Prevent re-triggering while transitioning
		set_deferred("monitoring", false)
		RoomSkeff.change_room.call_deferred(target_room_id, target_door_id)
