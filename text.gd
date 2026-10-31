extends Node2D

@export var fade_duration: float = 0.3

@onready var label: Label = $Label
@onready var area_2d: Area2D = $Area2D

@export var write: String = ""

var tween: Tween

func _ready() -> void:
	label.text = write
	label.modulate.a = 0.0

func _on_area_2d_body_entered(body: Node2D) -> void:
	# Replace with your player detection check (e.g. body.is_in_group("Player"))
	if body.is_in_group("Player"):
		fade(1.0)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		fade(0.0)

func fade(target_alpha: float) -> void:
	# Kill existing tween so fades don't overlap if walking in/out quickly
	if tween and tween.is_valid():
		tween.kill()
		
	tween = create_tween()
	tween.tween_property(label, "modulate:a", target_alpha, fade_duration)
