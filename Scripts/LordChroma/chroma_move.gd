class_name ChromaMove
extends Node

## One of Lord Chroma's moves. Add it as a child of Chroma's Moves node, with a script that extends this one.
## Chroma picks at random, by weight, among the standard moves allowed in its current color that are off cooldown, or
## an ult when the ult timer is up. He moves until in_position() is true, then calls start() and tick() every physics
## frame until tick() returns true.

## Chroma's colors this move can be picked in
@export_flags("White", "Red", "Blue", "Yellow", "Green") var colors := 31
## Chance of being picked, relative to the other moves allowed right now
@export var weight := 1.0
## In these colors, this move is picked with exactly fixed_chance whenever another standard move could be picked too;
## the other moves split the rest by their weights
@export_flags("White", "Red", "Blue", "Yellow", "Green") var fixed_chance_colors := 0
@export_range(0, 1) var fixed_chance := 0.25
## Seconds after this move ends before Chroma can pick it again
@export var cooldown := 0.0
## Ults are only picked when Chroma's shared ult timer is up, and don't count toward color swaps. An ult whose only
## color is Chroma's current one is picked first if it hasn't been used yet
@export var ult := false
## Ults only: MP the player gains for getting through the whole ult without being hit; Chroma is stunned too
@export var dodge_mp := 0
## In a flying color, Chroma keeps wandering around while this move runs instead of holding still
@export var wander_during := false

## Set by Chroma before the first call
var boss: LordChroma
var cooldown_left := 0.0
## Times this move has started
var times_used := 0

func allowed_in(color: int) -> bool:
	return colors & (1 << color) != 0

func has_fixed_chance(color: int) -> bool:
	return fixed_chance_colors & (1 << color) != 0

## Extra conditions for picking this move, on top of color and cooldown
func can_start(_player: Node2D) -> bool:
	return true

## Where Chroma's center should end up to get in position; he runs, jumps and drops through the level to get there
func reposition_point(_player: Node2D) -> Vector2:
	return boss.global_position

## True once the move would hit the player from where Chroma stands
func in_position(_player: Node2D) -> bool:
	return true

func start(_player: Node2D) -> void:
	pass

## Called every physics frame while the move runs; true ends it
func tick(_player: Node2D, _delta: float) -> bool:
	return true

## Called when the move ends or is cut short; removes anything the move left behind
func finish() -> void:
	pass
