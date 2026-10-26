class_name Room
extends Node

@export var EnemyObjects: Array[CharacterBody2D] = []
var Enemies: Array[String] = []

var EnemiesLiving: Array[String] = []

func _ready() -> void:
	for enemy in EnemyObjects:
		Enemies.append(enemy.name)

func checkDead() -> void:
	EnemiesLiving = []
	for enemy in EnemyObjects:
		if enemy:
			EnemiesLiving.append(enemy.name)

func allLiving() -> void:
	EnemiesLiving = Enemies

func setEnemiesLiving(enemies:Array[String]) -> void:
	EnemiesLiving = enemies

func PurgeEnemies() -> void:

	for enemy in Enemies:
		if not EnemiesLiving.has(enemy):
			var dead = get_node(enemy)
			dead.die()
