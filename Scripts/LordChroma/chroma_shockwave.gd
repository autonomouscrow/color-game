class_name ChromaShockwave
extends Node2D

## A shockwave from one of the depth charge's landings. Runs along the ground away from where Chroma landed, as a block
## that lifts off the ground the farther it goes: the gap under it climbs in a straight line from nothing at the
## landing to max_gap at full_gap_distance, so the gap it leaves along the ground is a triangle. Near the landing it has
## to be jumped; far enough out, a slide fits under it. Hurts the player once, and disappears on leaving min_x to max_x.

## Emitted when the shockwave takes health off a player; a hit that the player's i-frames ignore doesn't count
signal hurt_player(body: Node2D)

## 1 runs right, -1 runs left
var direction := 1.0
## Height of the ground it runs along
var ground_y := 900.0
## x where the gap under it starts from nothing
var origin_x := 0.0
var speed := 600.0
## Width, then height, of the block that hurts
var size := Vector2(40, 100)
var max_gap := 48.0
var full_gap_distance := 600.0
var damage := 20
var knockback := Vector2(600, -400)
var color := Color(0.2, 0.4, 1.0, 0.8)
var min_x := 0.0
var max_x := 1920.0

var traveled := 0.0
var contact: ChromaContact

func _ready() -> void:
	z_index = 5
	contact = ChromaContact.new()
	contact.size = size
	contact.damage = damage
	contact.knockback = knockback
	contact.hurt_player.connect(hurt_player.emit)
	add_child(contact)
	contact.active = true
	_place()

func _physics_process(delta: float) -> void:
	traveled += speed * delta
	_place()
	var x := global_position.x
	if x + size.x / 2 < min_x or x - size.x / 2 > max_x:
		queue_free()

## Gap between the ground and the bottom of the shockwave, distance from origin_x
func gap_at(distance: float) -> float:
	if full_gap_distance <= 0:
		return max_gap
	return minf(distance / full_gap_distance, 1.0) * max_gap

func _place() -> void:
	var x := origin_x + direction * traveled
	global_position = Vector2(x, ground_y - gap_at(traveled) - size.y / 2)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-size / 2, size), color)
