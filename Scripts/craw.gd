extends enemy

enum State { HOVER, SWOOP, RETURN }
var current_state: State = State.HOVER

@export var total_health = 25
@export var damage = 15

## The player in DetectionArea that the craw can see; null while they're hidden in a color zone
var player: Node2D = null
## The player in DetectionArea, seen or not
var detected_player: Node2D = null
var home_position: Vector2 = Vector2.ZERO
var last_home_position: Vector2 = Vector2.ZERO
var hover_timer: float = 0.0
var return_dir: float = 1.0

var curve_progress: float = 0.0
var curve_length: float = 1.0
var p_start: Vector2
var p_control: Vector2
var p_end: Vector2

var float_rand: float = randf_range(2.0, 2.3)

@onready var swoop_timer: Timer = $Timer

func _ready() -> void:
	home_position = global_position
	last_home_position = global_position
	swoop_timer.timeout.connect(_on_swoop_timer_timeout)

func _physics_process(delta: float) -> void:
	var seen_player: Node2D = detected_player if can_see(detected_player) else null
	if seen_player != player:
		player = seen_player
		if not player:
			swoop_timer.stop()
	match current_state:
		State.HOVER:
			hover_timer += delta * 4.0
			var target = home_position + Vector2(sin(hover_timer * float_rand), sin(hover_timer)) * 25.0
			velocity = (target - global_position) * 5.0
			if player and swoop_timer.is_stopped():
				start_timer()

		State.SWOOP:
			if follow_curve(550.0, delta):
				start_return()

		State.RETURN:
			if follow_curve(320.0, delta):
				global_position = home_position
				velocity = Vector2.ZERO
				current_state = State.HOVER
				if player: 
					start_timer()
					float_rand = randf_range(2.0, 2.3)

	move_and_slide()

func follow_curve(speed: float, delta: float) -> bool:
	curve_progress += (speed / curve_length) * delta
	if curve_progress >= 1.0:
		return true
	var next = p_start.lerp(p_control, curve_progress).lerp(p_control.lerp(p_end, curve_progress), curve_progress)
	velocity = ((next - global_position) / delta).limit_length(speed * 1.5)
	return false

func set_curve(start: Vector2, ctrl: Vector2, target: Vector2, state: State) -> void:
	p_start = start
	p_control = ctrl
	p_end = target
	curve_length = max((start.distance_to(target) + start.distance_to(ctrl) + ctrl.distance_to(target)) * 0.5, 1.0)
	curve_progress = 0.0
	current_state = state

func start_swoop() -> void:
	last_home_position = home_position
	return_dir = sign(player.global_position.x - global_position.x)
	if return_dir == 0: return_dir = 1.0 if randf() > 0.5 else -1.0

	var target = player.global_position + Vector2(return_dir * randf_range(80, 160), -randf_range(20, 60))
	var ctrl = Vector2(lerp(global_position.x, target.x, randf_range(0.45, 0.55)), max(global_position.y, player.global_position.y) + randf_range(55, 105))
	set_curve(global_position, ctrl, target, State.SWOOP)

func start_return() -> void:
	var dist = randf_range(110, 190)
	home_position = global_position + Vector2(return_dir * dist, -randf_range(150, 250))
	var ctrl = Vector2(global_position.x + return_dir * (dist * 1.25 + randf_range(75, 125)), lerp(global_position.y, home_position.y, randf_range(0.3, 0.45)))
	set_curve(global_position, ctrl, home_position, State.RETURN)

func bounce_to_last_home() -> void:
	home_position = last_home_position
	# Control point pops upward and backward away from the impact to create a bounce recoil
	var ctrl = global_position + Vector2(-return_dir * randf_range(70, 110), -randf_range(180, 240))
	set_curve(global_position, ctrl, home_position, State.RETURN)

func start_timer() -> void:
	swoop_timer.start(randf_range(1.2, 2.8))

func _on_swoop_timer_timeout() -> void:
	if player and current_state == State.HOVER:
		start_swoop()

func _on_body_entered(body: Node2D) -> void:
	# The swoop timer starts from _physics_process once the player can be seen
	if body.is_in_group("Player"):
		detected_player = body

func _on_body_exited(body: Node2D) -> void:
	if body == detected_player:
		detected_player = null

func _on_hitbox_2_body_entered(body: Node2D) -> void:
	if current_state == State.SWOOP:
		if body.is_in_group("Player"):
			bounce_to_last_home()
			
			# Knock the player away horizontally and slightly upward
			var push_dir = sign(body.global_position.x - global_position.x)
			if push_dir == 0: 
				push_dir = return_dir * 50
			var knockback = Vector2(push_dir * 500.0, -500.0)
			
			if body.has_method("SetKnockback"):
				body.SetKnockback(knockback)
			else:
				push_error("no knockback")
				
			if body.has_method("GetDamaged"):
				body.GetDamaged(damage)
				
		elif not body.is_in_group("enemy"):
			bounce_to_last_home()
			
