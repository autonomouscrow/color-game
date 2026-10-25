class_name enemy
extends CharacterBody2D

@export var max_health: int = 25:
	set(value):
		max_health = value
		# Runs when the Inspector value loads too, so every enemy starts at its own full health
		health = value
var health: int = max_health
## The Area2D that Hue's attacks hit; if left empty, attacks hit the enemy's own body instead
@export var hurtbox: Area2D

func take_damage(amount: float) -> void:
	if health <= 0:
		return
	health = maxi(health - roundi(amount), 0)
	print(name, " took ", roundi(amount), " damage, health now ", health)
	if health == 0:
		die()

func die() -> void:
	queue_free()
