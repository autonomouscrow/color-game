extends ChromaMove

## Blue ult. The platforms inside the arena fade out and disappear while Chroma leaps up off the top of the screen.
## Then, charges times: a warning column fades in and out over the player's x, locked when it appears, and Chroma dives
## straight down it, speeding up, onto the floor. Each landing sends a ChromaShockwave both ways along the floor, whose
## gap underneath grows the farther it runs, so near the landing it has to be jumped and far enough out it can be slid
## under. After a short pause on the floor he leaps back up for the next one. After the last landing he waits on the
## floor until every shockwave has left the arena, then the platforms come back, once the player isn't inside one.

@export var charges := 4
## Seconds the platforms take to fade out at the start, and to fade back in at the end
@export var platform_fade_time := 0.6
## Speed Chroma leaps up off the top of the screen at
@export var rise_speed := 2500.0
## How far above the arena's top Chroma waits between dives, out of sight
@export var hide_height := 300.0
## Seconds each warning column takes to fade in, and again to fade back out, before the dive
@export var warning_fade_time := 0.5
## Pixels the warning column reaches past Chroma's body on each side
@export var warning_margin := 20.0
@export var warning_color := Color(1, 0, 0, 0.35)
## Speed the dive starts at
@export var dive_speed := 1200.0
## How fast the dive speeds up, in px/s per second, like gravity
@export var dive_acceleration := 3000.0
## Seconds Chroma stays on the floor after each landing before leaping back up
@export var impact_pause := 0.3
## Seconds Chroma stands still after the platforms come back, before his next move
@export var recover_time := 0.6
## Damage from Chroma himself during a dive
@export var damage := 30
@export var knockback := Vector2(700, -400)
## Pixels the dive's contact hitbox reaches past Chroma's body on every side
@export var hitbox_margin := 4.0
## Area centered on the arena's middle; platforms fully inside it disappear, and shockwaves disappear on leaving it
@export var arena_size := Vector2(1920, 900)

@export_group("Shockwave")
## Width, then height, of each shockwave's block; Hue jumps about 178 px high, so near the landing it can be cleared
@export var wave_size := Vector2(40, 100)
@export var wave_speed := 600.0
## Most the gap under a shockwave grows to. Hue is 64 tall standing and 32 sliding, so 48 lets a slide through but not
## a walk
@export var max_gap := 48.0
## Distance from the landing where the gap reaches max_gap; it grows in a straight line until then
@export var full_gap_distance := 600.0
@export var wave_damage := 20
@export var wave_knockback := Vector2(600, -400)
@export var wave_color := Color(0.2, 0.4, 1.0, 0.8)

enum Phase { FADE_OUT, WARNING, DIVE, IMPACT, RISE, WAIT_WAVES, RETURN, RECOVER }
var phase := Phase.FADE_OUT
var timer := 0.0
var charge_index := 0
var target_x := 0.0
var land_y := 0.0
var speed := 0.0
var start_position := Vector2.ZERO
var contact: ChromaContact
var warning: Node2D
var waves: Array[ChromaShockwave] = []
## The platforms hidden for the ult, with what they had before so finish can put them back
var platforms: Array[StaticBody2D] = []
var platform_rects: Array[Rect2] = []
var platform_alphas: Array[float] = []
var platform_modes: Array[int] = []
var platforms_hidden := false

func start(_player: Node2D) -> void:
	start_position = boss.global_position
	boss.frozen = true
	boss.hide_airbrush()
	charge_index = 0
	waves.clear()
	_find_platforms()
	_make_contact()
	warning = Node2D.new()
	warning.top_level = true
	warning.z_index = 5
	warning.draw.connect(_draw_warning)
	boss.get_parent().add_child(warning)
	warning.global_position = Vector2.ZERO
	phase = Phase.FADE_OUT
	timer = 0.0

func tick(player: Node2D, delta: float) -> bool:
	timer += delta
	match phase:
		Phase.FADE_OUT:
			_set_platform_alpha(1.0 - timer / platform_fade_time if platform_fade_time > 0 else 0.0)
			var risen := _rise(delta)
			if timer >= platform_fade_time:
				_hide_platforms()
				if risen:
					_start_warning(player)
		Phase.WARNING:
			warning.queue_redraw()
			if timer >= 2 * warning_fade_time:
				boss.global_position = Vector2(target_x, _hide_y())
				speed = dive_speed
				contact.active = true
				phase = Phase.DIVE
				timer = 0.0
		Phase.DIVE:
			speed += dive_acceleration * delta
			var y := boss.global_position.y + speed * delta
			if y >= land_y:
				boss.global_position.y = land_y
				contact.active = false
				_spawn_waves()
				phase = Phase.IMPACT
				timer = 0.0
			else:
				boss.global_position.y = y
		Phase.IMPACT:
			if timer >= impact_pause:
				charge_index += 1
				phase = Phase.RISE if charge_index < charges else Phase.WAIT_WAVES
				timer = 0.0
		Phase.RISE:
			if _rise(delta):
				_start_warning(player)
		Phase.WAIT_WAVES:
			waves.assign(waves.filter(func(w): return is_instance_valid(w)))
			if waves.is_empty():
				phase = Phase.RETURN
				timer = 0.0
		Phase.RETURN:
			# Platforms only come back once they can't land on top of the player
			if platforms_hidden:
				timer = 0.0
				if not _player_in_platform(player):
					_show_platforms()
					_set_platform_alpha(0.0)
			else:
				_set_platform_alpha(timer / platform_fade_time if platform_fade_time > 0 else 1.0)
				if timer >= platform_fade_time:
					phase = Phase.RECOVER
					timer = 0.0
		Phase.RECOVER:
			return timer >= recover_time
	return false

func finish() -> void:
	if is_instance_valid(contact):
		contact.queue_free()
	contact = null
	if is_instance_valid(warning):
		warning.queue_free()
	warning = null
	for wave in waves:
		if is_instance_valid(wave):
			wave.queue_free()
	waves.clear()
	_show_platforms()
	for i in platforms.size():
		if is_instance_valid(platforms[i]):
			platforms[i].modulate.a = platform_alphas[i]
	platforms.clear()
	# Cut short while he's up out of sight, he comes back where the ult started
	if boss.global_position.y < _arena_rect().position.y:
		boss.global_position = start_position
	boss.frozen = false

func _arena_rect() -> Rect2:
	return Rect2(boss.arena_middle() - arena_size / 2, arena_size)

func _hide_y() -> float:
	return _arena_rect().position.y - hide_height

## Moves Chroma straight up toward _hide_y; true once he's there
func _rise(delta: float) -> bool:
	var y := maxf(boss.global_position.y - rise_speed * delta, _hide_y())
	boss.global_position.y = y
	return y <= _hide_y()

## Locks the column over the player's x, kept far enough from the walls that Chroma fits, and finds the floor under it
func _start_warning(player: Node2D) -> void:
	var area := _arena_rect()
	var x := boss.player_center(player).x if player else boss.arena_middle().x
	target_x = clampf(x, area.position.x + boss.half_size.x, area.end.x - boss.half_size.x)
	boss.global_position = Vector2(target_x, _hide_y())
	land_y = area.end.y - boss.half_size.y
	var surface := boss.surface_under(Vector2(target_x, area.position.y + 1))
	if surface:
		land_y = surface.top - boss.half_size.y
	phase = Phase.WARNING
	timer = 0.0

func _draw_warning() -> void:
	if phase != Phase.WARNING:
		return
	var fade := minf(timer, 2 * warning_fade_time - timer) / warning_fade_time if warning_fade_time > 0 else 1.0
	fade = clampf(fade, 0.0, 1.0)
	if fade <= 0:
		return
	var top := _arena_rect().position.y
	var half_width := boss.half_size.x + warning_margin
	var rect := Rect2(target_x - half_width, top, half_width * 2, land_y + boss.half_size.y - top)
	warning.draw_rect(rect, Color(warning_color, warning_color.a * fade))

func _spawn_waves() -> void:
	var area := _arena_rect()
	for dir in [-1.0, 1.0]:
		var wave := ChromaShockwave.new()
		wave.direction = dir
		wave.ground_y = land_y + boss.half_size.y
		wave.origin_x = target_x + dir * (boss.half_size.x + wave_size.x / 2)
		wave.speed = wave_speed
		wave.size = wave_size
		wave.max_gap = max_gap
		wave.full_gap_distance = full_gap_distance
		wave.damage = wave_damage
		wave.knockback = wave_knockback
		wave.color = wave_color
		wave.min_x = area.position.x
		wave.max_x = area.end.x
		wave.hurt_player.connect(boss.on_player_hurt)
		boss.get_parent().add_child(wave)
		waves.append(wave)

## Every visible, solid body whose rectangles all sit inside the arena area; the floor, walls and ceiling reach past it
func _find_platforms() -> void:
	platforms.clear()
	platform_rects.clear()
	platform_alphas.clear()
	platform_modes.clear()
	platforms_hidden = false
	var root := boss.get_tree().current_scene
	if root == null:
		return
	var area := _arena_rect()
	for body in root.find_children("*", "StaticBody2D", true, false):
		if not (body.is_visible_in_tree() and body.can_process()):
			continue
		var rects: Array[Rect2] = []
		var inside := true
		for child in body.get_children():
			var shape_node := child as CollisionShape2D
			if shape_node == null or shape_node.disabled or not (shape_node.shape is RectangleShape2D):
				continue
			var xform := shape_node.global_transform
			var size: Vector2 = (shape_node.shape as RectangleShape2D).size * xform.get_scale().abs()
			var rect := Rect2(xform.origin - size / 2, size)
			if not area.encloses(rect):
				inside = false
				break
			rects.append(rect)
		if not inside or rects.is_empty():
			continue
		for rect in rects:
			platform_rects.append(rect)
		platforms.append(body)
		platform_alphas.append(body.modulate.a)
		platform_modes.append(body.process_mode)

func _set_platform_alpha(alpha: float) -> void:
	alpha = clampf(alpha, 0.0, 1.0)
	for i in platforms.size():
		if is_instance_valid(platforms[i]):
			platforms[i].modulate.a = platform_alphas[i] * alpha

## Disabled bodies drop out of physics, so the hidden platforms aren't solid
func _hide_platforms() -> void:
	if platforms_hidden:
		return
	platforms_hidden = true
	for body in platforms:
		if is_instance_valid(body):
			body.visible = false
			body.process_mode = Node.PROCESS_MODE_DISABLED

func _show_platforms() -> void:
	if not platforms_hidden:
		return
	platforms_hidden = false
	for i in platforms.size():
		if is_instance_valid(platforms[i]):
			platforms[i].visible = true
			platforms[i].process_mode = platform_modes[i] as Node.ProcessMode

func _player_in_platform(player: Node2D) -> bool:
	var found: Node2D = player if player else boss.get_tree().get_first_node_in_group("Player") as Node2D
	if found == null:
		return false
	var hitbox = found.get("hitbox")
	var size := Vector2(32, 64)
	if hitbox is CollisionShape2D and hitbox.shape is RectangleShape2D:
		size = hitbox.shape.size * hitbox.global_scale.abs()
	var player_rect := Rect2(boss.player_center(found) - size / 2, size)
	for rect in platform_rects:
		if rect.intersects(player_rect):
			return true
	return false

func _make_contact() -> void:
	if is_instance_valid(contact):
		contact.queue_free()
	contact = ChromaContact.new()
	contact.size = boss.half_size * 2 + Vector2.ONE * hitbox_margin * 2
	contact.damage = damage
	contact.knockback = knockback
	contact.hurt_player.connect(boss.on_player_hurt)
	boss.add_child(contact)
