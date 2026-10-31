extends ChromaMove

## Yellow ult. Chroma vanishes and clone_count copies of him appear, clones_per_quadrant in each quarter of the fly area
## at random spots. The clone whose distance to the player is closest to aim_distance points straight at them; every
## other clone points a random one of that direction's turns and flips. Clones are Chroma's size and stand upright
## whichever way they go. Each shows a warning strip from its center that fades in and back out, then they all charge
## down their strips at once, hurting with a circle around their center. A clone hurts the player at most once, but
## different clones can each hit them. The layout is rerolled until the player has at least min_gaps separate spots,
## each the size of their hitbox, that no charge's hit circle sweeps over. Repeats rounds times; Chroma reappears where he vanished.

@export var rounds := 3
@export var clone_count := 16
@export var clones_per_quadrant := 4
## The clone whose distance to the player is closest to this aims straight at them
@export var aim_distance := 500.0
## Each clone's center charges this far down its warning strip, which is drawn this long
@export var warning_length := 1000.0
@export var warning_width := 100.0
## Diameter of the circle around each clone's center that hurts during the charge
@export var hit_diameter := 100.0
## Seconds each warning takes to fade in, and again to fade back out, before the charge
@export var warning_fade_time := 0.75
@export var warning_color := Color(1, 0, 0, 0.35)
@export var charge_speed := 2000.0
## Seconds with no clones out between one round's charge and the next round's clones
@export var round_gap := 0.4
## Seconds Chroma stays frozen after the last round before his next move
@export var recover_time := 0.6
@export var damage := 30
@export var knockback := Vector2(700, -400)

@export_group("Gaps")
## Fewest separate player-sized spots, inside the arena, that no warning strip covers
@export var min_gaps := 3
## Size of a gap when the player's hitbox can't be read
@export var default_player_size := Vector2(32, 64)
## Area centered on the arena's middle that gaps are looked for in
@export var arena_size := Vector2(1920, 900)
## Spacing of the spots tested for gaps; smaller is more exact but slower
@export var gap_check_step := 24.0
## Layouts tried per round before settling for the one with the most gaps
@export var layout_tries := 30

enum Phase { WARNING, CHARGE, GAP, RECOVER }
var phase := Phase.WARNING
var timer := 0.0
var round_index := 0
var clones: Array[ChromaClone] = []
var contacts: Array[ChromaContact] = []
var starts: Array[Vector2] = []
var directions: Array[Vector2] = []

func start(player: Node2D) -> void:
	boss.frozen = true
	boss.color_rect.visible = false
	boss.hide_airbrush()
	round_index = 0
	_start_round(player)

func tick(player: Node2D, delta: float) -> bool:
	timer += delta
	match phase:
		Phase.WARNING:
			var fade := minf(timer, 2 * warning_fade_time - timer) / warning_fade_time if warning_fade_time > 0 else 0.0
			for clone in clones:
				clone.warning_alpha = clampf(fade, 0.0, 1.0)
			if timer >= 2 * warning_fade_time:
				for contact in contacts:
					contact.active = true
				phase = Phase.CHARGE
				timer = 0.0
		Phase.CHARGE:
			var travel := warning_length
			var moved := minf(charge_speed * timer, travel)
			for i in clones.size():
				clones[i].global_position = starts[i] + directions[i] * moved
			if moved >= travel:
				_clear_clones()
				round_index += 1
				phase = Phase.GAP if round_index < rounds else Phase.RECOVER
				timer = 0.0
		Phase.GAP:
			if timer >= round_gap:
				_start_round(player)
		Phase.RECOVER:
			return timer >= recover_time
	return false

func finish() -> void:
	_clear_clones()
	boss.color_rect.visible = true
	boss.frozen = false

func _start_round(player: Node2D) -> void:
	_clear_clones()
	var target := boss.player_center(player) if player else boss.arena_middle()
	var hue_size := _player_size(player)
	var best_positions: Array[Vector2] = []
	var best_dirs: Array[Vector2] = []
	var best_gaps := -1
	for attempt in maxi(layout_tries, 1):
		var positions := _pick_positions()
		var dirs := _pick_directions(positions, target)
		var gaps := _count_gaps(positions, dirs, hue_size)
		if gaps > best_gaps:
			best_gaps = gaps
			best_positions = positions
			best_dirs = dirs
		if gaps >= min_gaps:
			break
	starts = best_positions
	directions = best_dirs
	for i in starts.size():
		var clone := ChromaClone.new()
		clone.size = boss.half_size * 2
		clone.color = boss.color_rect.color
		clone.direction = directions[i]
		clone.warning_length = warning_length
		clone.warning_width = warning_width
		clone.warning_color = warning_color
		var contact := ChromaContact.new()
		contact.radius = hit_diameter / 2
		contact.damage = damage
		contact.knockback = knockback
		contact.hurt_player.connect(boss.on_player_hurt)
		clone.add_child(contact)
		boss.get_parent().add_child(clone)
		clone.global_position = starts[i]
		clones.append(clone)
		contacts.append(contact)
	phase = Phase.WARNING
	timer = 0.0

func _clear_clones() -> void:
	for clone in clones:
		if is_instance_valid(clone):
			clone.queue_free()
	clones.clear()
	contacts.clear()

## clones_per_quadrant random spots in each quarter, going round the quarters until there are clone_count
func _pick_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var q := 0
	while positions.size() < clone_count:
		for i in clones_per_quadrant:
			if positions.size() < clone_count:
				positions.append(boss.random_point_in_quadrant(q))
		q = (q + 1) % 4
	return positions

## The clone closest to aim_distance from target aims straight at it; the rest pick at random from that direction's
## turns and flips
func _pick_directions(positions: Array[Vector2], target: Vector2) -> Array[Vector2]:
	var aimer := 0
	for i in positions.size():
		if absf(positions[i].distance_to(target) - aim_distance) < absf(positions[aimer].distance_to(target) - aim_distance):
			aimer = i
	var to := target - positions[aimer]
	var aim := to.normalized() if to != Vector2.ZERO else Vector2.RIGHT
	var options := direction_options(aim)
	var dirs: Array[Vector2] = []
	for i in positions.size():
		dirs.append(aim if i == aimer else options.pick_random())
	return dirs

## Same, flipped in x, flipped in y, turned 90, 180 and 270, and turned 90 or 270 then flipped in x or y. Those last
## four only make two new directions (turning 90 then flipping x is the same as turning 270 then flipping y), so there
## are 8 in all; any that land on the same direction for this aim, like an aim straight along an axis, are dropped
static func direction_options(d: Vector2) -> Array[Vector2]:
	var r90 := d.rotated(PI / 2)
	var r270 := d.rotated(-PI / 2)
	var all: Array[Vector2] = [
		d, Vector2(-d.x, d.y), Vector2(d.x, -d.y),
		r90, -d, r270,
		Vector2(-r90.x, r90.y), Vector2(r90.x, -r90.y),
		Vector2(-r270.x, r270.y), Vector2(r270.x, -r270.y),
	]
	var unique: Array[Vector2] = []
	for v in all:
		var seen := false
		for u in unique:
			if u.is_equal_approx(v):
				seen = true
				break
		if not seen:
			unique.append(v)
	return unique

## Separate player-sized spots in the arena that no charge's hit circle sweeps over (a strip hit_diameter wide, from
## half a circle behind the clone's center to half a circle past the warning's end): the safe spots tested every gap_check_step, keeping
## only ones that don't overlap a spot already kept. Stops counting at min_gaps
func _count_gaps(positions: Array[Vector2], dirs: Array[Vector2], hue_size: Vector2) -> int:
	var half := hue_size / 2
	var area := Rect2(boss.arena_middle() - arena_size / 2, arena_size).grow_individual(-half.x, -half.y, -half.x, -half.y)
	var strip_half := Vector2((warning_length + hit_diameter) / 2, hit_diameter / 2)
	var centers: Array[Vector2] = []
	for i in positions.size():
		centers.append(positions[i] + dirs[i] * warning_length / 2)
	var kept: Array[Vector2] = []
	var step := maxf(gap_check_step, 1.0)
	var y := area.position.y
	while y <= area.end.y:
		var x := area.position.x
		while x <= area.end.x:
			var spot := Vector2(x, y)
			var free := true
			for k in kept:
				if absf(k.x - spot.x) < hue_size.x and absf(k.y - spot.y) < hue_size.y:
					free = false
					break
			if free:
				for i in centers.size():
					if _overlaps(spot, half, centers[i], dirs[i], strip_half):
						free = false
						break
			if free:
				kept.append(spot)
				if kept.size() >= min_gaps:
					return kept.size()
			x += step
		y += step
	return kept.size()

## True if the box at p with half size half overlaps the strip centered at c, facing u, with half size strip_half
static func _overlaps(p: Vector2, half: Vector2, c: Vector2, u: Vector2, strip_half: Vector2) -> bool:
	var v := Vector2(-u.y, u.x)
	var d := c - p
	if absf(d.x) >= half.x + absf(u.x) * strip_half.x + absf(v.x) * strip_half.y:
		return false
	if absf(d.y) >= half.y + absf(u.y) * strip_half.x + absf(v.y) * strip_half.y:
		return false
	if absf(d.dot(u)) >= strip_half.x + absf(u.x) * half.x + absf(u.y) * half.y:
		return false
	if absf(d.dot(v)) >= strip_half.y + absf(v.x) * half.x + absf(v.y) * half.y:
		return false
	return true

func _player_size(player: Node2D) -> Vector2:
	if player:
		var hitbox = player.get("hitbox")
		if hitbox is CollisionShape2D and hitbox.shape is RectangleShape2D:
			return hitbox.shape.size * hitbox.global_scale.abs()
	return default_player_size
