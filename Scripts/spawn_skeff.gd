extends Node2D

@export var RoomControl: Node2D


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
