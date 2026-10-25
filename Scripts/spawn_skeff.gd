extends Node2D

@export var RoomControl: Node2D


@export var roomEnemies: Dictionary = {
	
}

func addRoom(id:String, enemies:Array[CharacterBody2D]) -> void:
	roomEnemies[id] = enemies

func checkDictionary(id:String) -> bool:
	if roomEnemies.has(id):
		return true
	return false
