extends enemy

enum State { IDLE, MOVE, THROW }
var current_state: State = State.IDLE

@export var plane_scene: PackedScene = preload("res://Scenes/Prefabs/PaperAirplane.tscn")

@export_group("Idle")
## Total width of the side to side patrol while the player is out of DetectionArea
@export var idle_patrol_width := 30.0
@export var idle_speed := 10.0

@export_group("Move")
@export var move_speed := 150.0

@export_group("Throw")
## Seconds between throws
@export var throw_cooldown := 1
## Where the plane spawns relative to the thrower's center, for a throw to the right; x flips to face the player.
## The default x puts the plane just past the thrower's front edge (half its 32 px width plus half the plane's length).
@export var throw_offset := Vector2(26, -25)
## Each plane aims at a random point in a circle around Hue's center; the radius is Hue's current height times this
@export var aim_spread := 1.0

@export_group("Physics")
@export var gravity := 1800.0
@export var max_fall_speed := 1000.0

## The player in DetectionArea that the thrower can see; null while they're hidden in a color zone
var player: Node2D = null
## The player in DetectionArea, seen or not
var detected_player: Node2D = null
var idle_center := Vector2.ZERO
var idle_dir := 1.0
# Throwing range is inside ThrowArea but outside TooCloseArea
var in_throw_area := false
var in_too_close_area := false

@onready var throw_timer: Timer = $ThrowTimer

func _ready() -> void:
	idle_center = global_position
	throw_timer.wait_time = throw_cooldown

func _physics_process(delta: float) -> void:
	if detected_player != null:
		if detected_player.global_position.x > global_position.x:
			$AnimatedSprite2D.flip_h = true
		else:
			$AnimatedSprite2D.flip_h = false
	var seen_player: Node2D = detected_player if can_see(detected_player) else null
	if seen_player != player:
		player = seen_player
		if player:
			current_state = State.MOVE
		else:
			idle_center = global_position
			current_state = State.IDLE
	match current_state:
		State.IDLE:
			velocity.x = idle_dir * idle_speed
			var offset := global_position.x - idle_center.x
			if (offset >= idle_patrol_width / 2 and idle_dir > 0) or (offset <= -idle_patrol_width / 2 and idle_dir < 0) or is_on_wall():
				idle_dir = -idle_dir

		State.MOVE:
			# Stay on the side the thrower is already on, so it never walks through the player
			var side := signf(global_position.x - player.global_position.x)
			if side == 0:
				side = 1.0
			if in_too_close_area:
				velocity.x = side * move_speed
				$AnimatedSprite2D.flip_h = not $AnimatedSprite2D.flip_h
			elif not in_throw_area:
				velocity.x = -side * move_speed
			else:
				velocity.x = 0.0
				if throw_timer.is_stopped():
					current_state = State.THROW

		State.THROW:
			velocity.x = 0.0
			throw_plane()
			throw_timer.start(throw_cooldown)
			current_state = State.MOVE

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()

func throw_plane() -> void:
	var plane = plane_scene.instantiate()
	plane.thrower = self
	# Added to the level rather than the thrower, so the plane doesn't move along with it
	get_parent().add_child(plane)
	var target := _aim_point()
	var facing := 1.0 if player.global_position.x >= global_position.x else -1.0
	plane.global_position = global_position + Vector2(throw_offset.x * facing, throw_offset.y)
	plane.launch(target)

## Evenly spread random point in a circle around Hue's center, sized to Hue's current (possibly squished) height
func _aim_point() -> Vector2:
	var center := player.global_position
	var height := 64.0
	var hitbox = player.get("hitbox")
	var shape = player.get("hitbox_shape")
	if hitbox and shape:
		center += hitbox.position
		height = shape.size.y
	# sqrt keeps points from bunching up at the middle
	return center + Vector2.from_angle(randf() * TAU) * height * aim_spread * sqrt(randf())

func _on_detection_body_entered(body: Node2D) -> void:
	# Switching to MOVE happens in _physics_process once the player can be seen
	if body.is_in_group("Player"):
		detected_player = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body == detected_player:
		detected_player = null

func _on_throw_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		in_throw_area = true

func _on_throw_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		in_throw_area = false

func _on_too_close_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		in_too_close_area = true

func _on_too_close_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		in_too_close_area = false


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		var push_dir = sign(body.global_position.x - global_position.x)
		var knockback = Vector2(push_dir * 500.0, -500.0)
		
		if body.has_method("SetKnockback"):
			body.SetKnockback(knockback)
		else:
			push_error("no knockback")
			
		if body.has_method("GetDamaged"):
			body.GetDamaged(10)
				
