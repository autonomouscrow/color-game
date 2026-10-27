extends Node2D

@export var RoomControl: Node2D
@export var SpawnPoint: String
@export var SpawnRoom: String

@export var roomEnemies: Dictionary = {
	
}

func addRoom(id:String, enemies:Array[String]) -> void:
	roomEnemies[id] = enemies

func checkDictionary(id:String) -> bool:
	if roomEnemies.has(id):
		return true
	return false

func getEnemyList(id:String) -> Array[String]:
	return roomEnemies[id]
	
func resetRooms() -> void:
	roomEnemies = {}

func Respawn() -> void:
	RoomControl.change_room(SpawnRoom, SpawnPoint)

func SetSpawn(room:String,point:String) -> void:
	print (room, " ", room)
	SpawnPoint = point
	SpawnRoom = room

func checkCanvas(id:String) -> bool:
	if id == SpawnPoint:
		return true
	return false
