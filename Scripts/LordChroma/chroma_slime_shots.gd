extends ChromaMove

## Green. Chroma walks along the ceiling until the player is within max_distance to the side, points the airbrush at
## them for wind_up_time, then lobs shots arcing slime blobs one after another. They're aimed to come down at the
## player's x, spread spacing apart around it, flight_time after they're fired. Each leaves a ChromaSlimePuddle where it
## lands that rides along with the ground as it moves, slowing the player and hurting them over time while they're in it.

@export var shots := 3
## Pixels between where neighboring shots are aimed to land
@export var spacing := 160.0
## Seconds between shots
@export var shot_interval := 0.15
## Seconds from a shot leaving the airbrush to landing where it was aimed
@export var flight_time := 1.0
@export var shot_gravity := 1500.0
@export var shot_radius := 12.0
@export var shot_color := Color(0.3, 0.85, 0.3)
## Seconds Chroma points the airbrush at the player before the first shot
@export var wind_up_time := 0.4
## Seconds Chroma stands still after the last shot before his next move
@export var recover_time := 0.4
## Chroma fires once the player is at most this far to his side
@export var max_distance := 600.0

@export_group("Puddle")
## Width, then height, of each puddle
@export var puddle_size := Vector2(110, 14)
## Seconds each puddle lasts
@export var puddle_time := 15.0
## Fraction of their usual speed the player moves at while in a puddle
@export_range(0, 1) var slow_factor := 0.5
## Damage every dot_interval seconds while the player stays in a puddle, starting the moment they step in
@export var dot_damage := 3
@export var dot_interval := 0.5
@export var puddle_color := Color(0.3, 0.85, 0.3, 0.7)
@export_group("Orb Sprite")
## Shown instead of the plain shape when set; the hitbox stays the same size
@export var orb_texture: Texture2D
## Multiplies the sprite's size after it's fitted to the hitbox
@export var orb_sprite_scale := Vector2.ONE
## Pixels the sprite is moved from the hitbox's center
@export var orb_sprite_offset := Vector2.ZERO
@export_group("Puddle Sprite")
## Shown instead of the plain shape when set; the hitbox stays the same size
@export var puddle_texture: Texture2D
## Multiplies the sprite's size after it's fitted to the hitbox
@export var puddle_sprite_scale := Vector2.ONE
## Pixels the sprite is moved from the hitbox's center
@export var puddle_sprite_offset := Vector2.ZERO
@export_group("")

var timer := 0.0
var fired := 0
## Where the shots are aimed to land, locked when the wind-up starts
var aim := Vector2.ZERO

func can_start(player: Node2D) -> bool:
	return player != null

func reposition_point(player: Node2D) -> Vector2:
	return Vector2(player.global_position.x, boss.global_position.y)

func in_position(player: Node2D) -> bool:
	return absf(player.global_position.x - boss.global_position.x) <= max_distance

func start(player: Node2D) -> void:
	timer = 0.0
	fired = 0
	aim = _feet(player)
	boss.face_toward(player.global_position.x)

func tick(player: Node2D, delta: float) -> bool:
	timer += delta
	if player:
		boss.show_airbrush(boss.player_center(player) - boss.global_position, timer / wind_up_time if wind_up_time > 0 else 1.0)
	if fired < shots:
		if timer >= wind_up_time + fired * shot_interval:
			_fire(fired)
			fired += 1
		return false
	return timer >= wind_up_time + (shots - 1) * shot_interval + recover_time

func finish() -> void:
	boss.hide_airbrush()

## Shot i of shots lands spacing apart from its neighbors, the middle of them all at aim
func _fire(i: int) -> void:
	boss.request_anim(&"slime")
	var target := aim + Vector2((i - (shots - 1) / 2.0) * spacing, 0)
	var from := boss.airbrush.global_position
	var t := maxf(flight_time, 0.05)
	var shot := ChromaSlimeShot.new()
	# Lands on target after t seconds: target = from + v t + g t² / 2
	shot.velocity = (target - from - Vector2(0, shot_gravity) * t * t / 2) / t
	shot.gravity = shot_gravity
	shot.radius = shot_radius
	shot.color = shot_color
	shot.puddle_size = puddle_size
	shot.puddle_time = puddle_time
	shot.slow_factor = slow_factor
	shot.dot_damage = dot_damage
	shot.dot_interval = dot_interval
	shot.puddle_color = puddle_color
	shot.texture = orb_texture
	shot.sprite_scale = orb_sprite_scale
	shot.sprite_offset = orb_sprite_offset
	shot.puddle_texture = puddle_texture
	shot.puddle_sprite_scale = puddle_sprite_scale
	shot.puddle_sprite_offset = puddle_sprite_offset
	shot.hurt_player.connect(boss.on_player_hurt)
	boss.get_parent().add_child(shot)
	shot.global_position = from

## Bottom middle of the player's hitbox
func _feet(player: Node2D) -> Vector2:
	var feet := boss.player_center(player)
	var hitbox = player.get("hitbox")
	if hitbox is CollisionShape2D and hitbox.shape is RectangleShape2D:
		feet.y += hitbox.shape.size.y * absf(hitbox.global_scale.y) / 2
	return feet

## slime_windup until the first blob, then slime, restarting on each blob
func anim_state() -> StringName:
	return &"slime" if fired > 0 else &"slime_windup"
