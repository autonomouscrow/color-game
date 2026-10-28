extends enemy

## Crawls around the outline of whatever it's stuck to and ignores gravity. Touching blocks count as one surface, so it
## climbs up into inside corners and wraps around outside corners. The node's rotation in the editor, rounded to a quarter
## turn, picks which side is its underside at the start (rotate it 180 to start on a ceiling); if nothing is there, it
## sticks to the closest surface within attach_distance. Surfaces are expected to be flat walls, floors and ceilings.
enum Spin { CLOCKWISE, COUNTERCLOCKWISE }

@export_group("Crawl")
## CLOCKWISE goes right along the top of a block and down its right side; COUNTERCLOCKWISE goes left along the top
@export var spin := Spin.CLOCKWISE
@export var crawl_speed := 50.0
## How far away a surface can be and still be grabbed at the start, or after the surface it was on disappears
@export var attach_distance := 64.0
## How far the Slime reaches toward its surface after each step to stay pressed against it
@export var surface_snap := 4.0
## Gaps in a surface up to this wide are crawled over instead of being treated as an outside corner
@export var seam_tolerance := 2.0
## Longest move between surface checks; smaller is more exact at corners
@export var max_step := 4.0
## How fast the drawn slime catches up after snapping around a corner; 0 snaps instantly
@export var turn_smoothing := 25.0

@export_group("Contact")
## Damage from touching the Slime
@export var contact_damage := 15
@export var contact_knockback := Vector2(500, -500)

## Toward the surface the Slime is stuck to; always one of the four straight directions
var down := Vector2.DOWN
## False while there's no surface in reach; the Slime holds still and keeps looking for one
var attached := false
## Half the body's size, x along the surface and y away from it
var half := Vector2(25, 15)
## Players and enemies the Slime crawls through; kept here instead of asking for get_collision_exceptions(), which
## errors on bodies that have been freed
var passed_through: Array[PhysicsBody2D] = []

@onready var body_shape: CollisionShape2D = $Body
@onready var visual: Node2D = $Visual

func _ready() -> void:
	half = (body_shape.shape as RectangleShape2D).size / 2
	down = Vector2.DOWN.rotated(snappedf(global_rotation, PI / 2)).round()
	global_rotation = down.angle() - PI / 2
	# The player and other enemies may be added to the tree after the Slime
	_pass_through_bodies.call_deferred()

func _physics_process(delta: float) -> void:
	if not attached:
		attached = _attach()
	var left := crawl_speed * delta if attached else 0.0
	while left > 0.0 and attached:
		var step := minf(left, max_step)
		left -= step
		_crawl(step)
	_settle_visual(delta)

func _crawl(step: float) -> void:
	var ahead := _ahead()
	var col := move_and_collide(ahead * step)
	if col:
		# A player or enemy that spawned after the Slime is passed through instead of climbed
		if not _pass_through(col.get_collider()):
			_turn_inside(ahead)
		return
	if not _surface_below():
		_turn_outside(ahead, step)
		return
	var snap := move_and_collide(down * surface_snap, true)
	if snap:
		global_position += snap.get_travel()

## Direction of travel along the current surface
func _ahead() -> Vector2:
	return down.rotated(-PI / 2 if spin == Spin.CLOCKWISE else PI / 2).round()

## Wall straight ahead: climb onto it, so the old surface ends up behind the Slime
func _turn_inside(ahead: Vector2) -> void:
	# The body is longer than it is tall, so turning in place would sink it into the old surface and leave a gap to the new one
	_turn(ahead, global_position + (ahead - down) * (half.x - half.y))

## The middle of the Slime just went past the end of its surface: pivot around the corner onto the side below it
func _turn_outside(ahead: Vector2, step: float) -> void:
	# Find the side face exactly with a ray just below the old surface, pointing back the way the Slime came. After an
	# inside turn onto a short ledge, the middle can already be up to half the body's length past the end of it
	var below := global_position + down * (half.y + 2.0)
	var hit := _ray(below, below - ahead * (half.x + step + seam_tolerance))
	var past := step / 2.0
	if hit:
		past = (below - hit.position).dot(ahead)
	var corner := global_position + down * half.y - ahead * past
	var new_down := -ahead
	# The distance already crawled past the corner carries on down the new side, so the next check finds the side face
	_turn(new_down, corner - new_down * half.y + down * maxf(past, 1.0))
	if not _surface_below():
		attached = false

func _turn(new_down: Vector2, new_position: Vector2) -> void:
	var before := global_transform
	down = new_down
	global_position = new_position
	global_rotation = down.angle() - PI / 2
	# Leave the drawing where it was; _settle_visual slides it onto the body
	visual.transform = global_transform.affine_inverse() * before * visual.transform

func _settle_visual(delta: float) -> void:
	if turn_smoothing <= 0:
		visual.transform = Transform2D.IDENTITY
	else:
		visual.transform = visual.transform.interpolate_with(Transform2D.IDENTITY, 1.0 - exp(-turn_smoothing * delta))

## True if there's a surface under the middle of the Slime, or under a point seam_tolerance behind it
func _surface_below() -> bool:
	var reach := down * (half.y + surface_snap + 1.0)
	for from in [global_position, global_position - _ahead() * seam_tolerance]:
		if _ray(from, from + reach):
			return true
	return false

## Sticks to the closest surface within attach_distance, trying the current underside first; false if there's none
func _attach() -> bool:
	var best_down := Vector2.ZERO
	var best_travel := Vector2.ZERO
	for i in 4:
		var dir := down.rotated(i * PI / 2).round()
		# The body is longer than it is tall, so test with it already turned
		global_rotation = dir.angle() - PI / 2
		var col := move_and_collide(dir * attach_distance, true)
		if col and (best_down == Vector2.ZERO or col.get_travel().length() < best_travel.length() - 0.5):
			best_down = dir
			best_travel = col.get_travel()
	if best_down != Vector2.ZERO:
		down = best_down
		global_position += best_travel
	global_rotation = down.angle() - PI / 2
	return best_down != Vector2.ZERO

func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	var exclude: Array[RID] = [get_rid()]
	for body in passed_through:
		# Players and enemies that died since are skipped; asking a freed body for its RID crashes
		if is_instance_valid(body):
			exclude.append(body.get_rid())
	query.exclude = exclude
	return get_world_2d().direct_space_state.intersect_ray(query)

## The Slime crawls through the player and other enemies, so only level geometry is a surface
func _pass_through_bodies() -> void:
	for group in ["Player", "enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			_pass_through(node)

## Adds a two way collision exception with a player or enemy; false for anything else
func _pass_through(node: Object) -> bool:
	if node == self or not node is PhysicsBody2D or not (node.is_in_group("Player") or node.is_in_group("enemy")):
		return false
	add_collision_exception_with(node)
	node.add_collision_exception_with(self)
	if node not in passed_through:
		passed_through.append(node)
	return true

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_hurt(body, contact_damage, contact_knockback)

func _hurt(body: Node2D, damage: int, knockback: Vector2) -> void:
	var push_dir := signf(body.global_position.x - global_position.x)
	if push_dir == 0:
		push_dir = 1.0
	if body.has_method("SetKnockback"):
		body.SetKnockback(Vector2(push_dir * knockback.x, knockback.y))
	if body.has_method("GetDamaged"):
		body.GetDamaged(damage)
