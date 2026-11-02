extends Node
## AudioSkeff: plays all of the game's audio. Put one in Main; other scripts find it with
## get_tree().get_first_node_in_group("AudioSkeff") and call play_sfx(...).
## Keeps running while the game is paused, so the music keeps going at paused_music_volume.

@export_group("Master")
@export_range(-40.0, 30.0, 0.5) var master_volume_db := 0.0  ## Player-facing volume added to every sound and the music; MenuSkeff's Master slider sets it

@export_group("Music")
## Background music; loops when it ends.
@export_file("*.mp3", "*.ogg", "*.wav") var music_path := "res://Audio/Magical Playlist Vol1.mp3"
@export_range(-40.0, 30.0, 0.5) var music_volume_db := 0.0  ## Player-facing volume, for an audio slider
@export_range(-40.0, 12.0, 0.5) var music_db_offset := -20  ## Default loudness of this track; added to music_volume_db
@export_range(0.0, 1.0, 0.05) var paused_music_volume := 0.5  ## Music loudness while paused, as a fraction of normal (0.5 = half)

@export_group("Boss Music")
## Plays instead of the normal music while the player is in one of boss_rooms; loops when it ends
@export_file("*.mp3", "*.ogg", "*.wav") var boss_music_path := "res://Audio/boss music.mp3"
@export var boss_rooms: Array[String] = ["ChromaArena"]  ## Room names (room scene root node names) that use the boss music
@export_range(-40.0, 12.0, 0.5) var boss_music_db_offset := -20  ## Default loudness of the boss track; added to music_volume_db
@export_range(0.0, 5.0, 0.1) var music_fade_out_time := 1.0  ## Seconds to fade out one track before the other starts
@export_range(0.0, 5.0, 0.1) var music_fade_in_time := 0.5  ## Seconds to fade the new track in

@export_group("Credits Music")
@export_range(0.0, 10.0, 0.1) var credits_music_fade_in_time := 3.0  ## Seconds for the normal music to fade back in when the credits start

@export_group("Sound Effects")
@export var attack_sound: AudioStream  ## Played on every punch and uppercut
@export_range(-40.0, 30.0, 0.5) var attack_sound_volume_db := 0.0  ## Player-facing volume, for an audio slider
@export_range(-40.0, 12.0, 0.5) var attack_sound_db_offset := -15  ## Default loudness of this sound; added to attack_sound_volume_db
@export_range(0.0, 0.5, 0.01) var attack_pitch_variation := 0.1  ## Each attack's pitch is randomly shifted up or down by up to this much (0.1 = ±10%)
@export var hurt_sounds: Array[AudioStream] = []  ## Played when Hue takes damage; one is picked at random each hit
@export_range(0.25, 4.0, 0.05) var hurt_sound_pitch := 1.2  ## Pitch of the hurt sounds (1 = original, 1.2 = 20% higher)
@export_range(0.0, 0.5, 0.01) var hurt_pitch_variation := 0.05  ## Each hit's pitch is randomly shifted up or down by up to this much
@export_range(-40.0, 30.0, 0.5) var hurt_sound_volume_db := 0.0  ## Player-facing volume, for an audio slider
@export_range(-40.0, 12.0, 0.5) var hurt_sound_db_offset := 0.0  ## Default loudness of these sounds; added to hurt_sound_volume_db

@export_group("Ability Sounds")
## Each ability works like the hurt sounds: drag files into its list, and one plays at random each time. Empty lists stay silent.
@export_range(-40.0, 30.0, 0.5) var ability_volume_db := 0.0  ## Player-facing volume for all ability sounds, for an audio slider
@export_subgroup("Dash")
@export var dash_sounds: Array[AudioStream] = []  ## Starting a dash; one is picked at random each time
@export_range(0.25, 4.0, 0.05) var dash_pitch := 1.0  ## 1 = original pitch, 1.2 = 20% higher
@export_range(0.0, 0.5, 0.01) var dash_pitch_variation := 0.05  ## Each play's pitch is randomly shifted up or down by up to this much
@export_range(-40.0, 12.0, 0.5) var dash_db_offset := 0.0  ## Default loudness of these sounds; added to ability_volume_db
@export_subgroup("Gun")
@export var gun_sounds: Array[AudioStream] = []  ## Firing the gun; one is picked at random each time
@export_range(0.25, 4.0, 0.05) var gun_pitch := 1.0  ## 1 = original pitch, 1.2 = 20% higher
@export_range(0.0, 0.5, 0.01) var gun_pitch_variation := 0.05  ## Each play's pitch is randomly shifted up or down by up to this much
@export_range(-40.0, 12.0, 0.5) var gun_db_offset := 0.0  ## Default loudness of these sounds; added to ability_volume_db
@export_subgroup("Burst")
@export var burst_sounds: Array[AudioStream] = []  ## The burst going off; one is picked at random each time
@export_range(0.25, 4.0, 0.05) var burst_pitch := 1.0  ## 1 = original pitch, 1.2 = 20% higher
@export_range(0.0, 0.5, 0.01) var burst_pitch_variation := 0.05  ## Each play's pitch is randomly shifted up or down by up to this much
@export_range(-40.0, 12.0, 0.5) var burst_db_offset := 0.0  ## Default loudness of these sounds; added to ability_volume_db
@export_subgroup("Heal")
@export var heal_sounds: Array[AudioStream] = []  ## Starting a heal; one is picked at random each time
@export_range(0.25, 4.0, 0.05) var heal_pitch := 1.0  ## 1 = original pitch, 1.2 = 20% higher
@export_range(0.0, 0.5, 0.01) var heal_pitch_variation := 0.05  ## Each play's pitch is randomly shifted up or down by up to this much
@export_range(-40.0, 12.0, 0.5) var heal_db_offset := 0.0  ## Default loudness of these sounds; added to ability_volume_db
@export_subgroup("Crisis")
@export var crisis_sounds: Array[AudioStream] = []  ## Starting a Mental Health Crisis; one is picked at random each time
@export_range(0.25, 4.0, 0.05) var crisis_pitch := 1.0  ## 1 = original pitch, 1.2 = 20% higher
@export_range(0.0, 0.5, 0.01) var crisis_pitch_variation := 0.05  ## Each play's pitch is randomly shifted up or down by up to this much
@export_range(-40.0, 12.0, 0.5) var crisis_db_offset := 0.0  ## Default loudness of these sounds; added to ability_volume_db
@export_subgroup("Color Swap")
@export var color_swap_sounds: Array[AudioStream] = []  ## Swapping color; one is picked at random each time
@export_range(0.25, 4.0, 0.05) var color_swap_pitch := 1.0  ## 1 = original pitch, 1.2 = 20% higher
@export_range(0.0, 0.5, 0.01) var color_swap_pitch_variation := 0.05  ## Each play's pitch is randomly shifted up or down by up to this much
@export_range(-40.0, 12.0, 0.5) var color_swap_db_offset := 0.0  ## Default loudness of these sounds; added to ability_volume_db
@export_subgroup("Death")
@export var death_sounds: Array[AudioStream] = []  ## Hue dying; one is picked at random each time
@export_range(0.25, 4.0, 0.05) var death_pitch := 1.0  ## 1 = original pitch, 1.2 = 20% higher
@export_range(0.0, 0.5, 0.01) var death_pitch_variation := 0.05  ## Each play's pitch is randomly shifted up or down by up to this much
@export_range(-40.0, 12.0, 0.5) var death_db_offset := 0.0  ## Default loudness of these sounds; added to ability_volume_db

var music: AudioStreamPlayer
var boss_music: AudioStreamPlayer
var _music_fade := 1.0  # 0..1 multiplier tweened during crossfades
var _boss_fade := 0.0
var _in_boss_room := false
var _fade_tween: Tween
var _credits := false  # True once the credits start: normal music only, at full loudness even though the game is paused

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("AudioSkeff")
	music = _make_music_player(music_path)
	boss_music = _make_music_player(boss_music_path)
	if music.stream:
		music.play()

func _make_music_player(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	if not ResourceLoader.exists(path):
		push_warning("AudioSkeff: no music file at " + path)
		return player
	var stream: AudioStream = load(path)
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.stream = stream
	# Backup loop in case the stream ignores the loop flag
	player.finished.connect(player.play)
	return player

func _process(_delta: float) -> void:
	var in_boss := _is_in_boss_room()
	if in_boss != _in_boss_room:
		_in_boss_room = in_boss
		_switch_music(in_boss)
	_update_music_volume()

func _is_in_boss_room() -> bool:
	if _credits:
		return false
	var room_control := get_tree().get_first_node_in_group("RoomControl")
	if not room_control:
		return false
	var room = room_control.get("current_room")
	return is_instance_valid(room) and String(room.name) in boss_rooms

## Fades out whichever track is playing, then starts the other one
func _switch_music(to_boss: bool) -> void:
	var from := music if to_boss else boss_music
	var to := boss_music if to_boss else music
	var from_fade := "_music_fade" if to_boss else "_boss_fade"
	var to_fade := "_boss_fade" if to_boss else "_music_fade"
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, from_fade, 0.0, music_fade_out_time)
	_fade_tween.tween_callback(func():
		# The normal music only pauses, so it resumes where it left off; the boss music restarts each fight
		if to_boss:
			from.stream_paused = true
		else:
			from.stop()
		if to.stream:
			if to.stream_paused:
				to.stream_paused = false
			elif not to.playing:
				to.play()
	)
	_fade_tween.tween_property(self, to_fade, 1.0, music_fade_in_time)

## Fades the boss music to silence over fade_time seconds, leaving nothing playing; used when Lord Chroma dies
func fade_out_boss_music(fade_time: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "_boss_fade", 0.0, fade_time)
	_fade_tween.tween_callback(boss_music.stop)

## Called when the credits start: the boss music stops and the normal music fades back in from where it left off
func start_credits_music() -> void:
	_credits = true
	_in_boss_room = false
	if _fade_tween:
		_fade_tween.kill()
	_boss_fade = 0.0
	boss_music.stop()
	if music.stream:
		if music.stream_paused:
			music.stream_paused = false
		elif not music.playing:
			music.play()
	_music_fade = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "_music_fade", 1.0, credits_music_fade_in_time)

func _update_music_volume() -> void:
	# Only a real pause quiets the music, not a brief hitstop
	var loudness := paused_music_volume if Pause.is_menu_paused() and not _credits else 1.0
	music.volume_db = master_volume_db + music_volume_db + music_db_offset + linear_to_db(maxf(loudness * _music_fade, 0.0001))
	boss_music.volume_db = master_volume_db + music_volume_db + boss_music_db_offset + linear_to_db(maxf(loudness * _boss_fade, 0.0001))

## Plays a one-shot sound; overlapping plays don't cut each other off. Pauses with the game unless ignore_pause is true.
func play_sfx(stream: AudioStream, volume_db := 0.0, pitch_scale := 1.0, ignore_pause := false) -> void:
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS if ignore_pause else Node.PROCESS_MODE_PAUSABLE
	player.stream = stream
	player.volume_db = master_volume_db + volume_db
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_attack() -> void:
	var pitch := 1.0 + randf_range(-attack_pitch_variation, attack_pitch_variation)
	play_sfx(attack_sound, attack_sound_volume_db + attack_sound_db_offset, pitch)

func play_hurt() -> void:
	if hurt_sounds.is_empty():
		return
	var pitch := hurt_sound_pitch + randf_range(-hurt_pitch_variation, hurt_pitch_variation)
	play_sfx(hurt_sounds.pick_random(), hurt_sound_volume_db + hurt_sound_db_offset, maxf(pitch, 0.01))

## Plays one of the <ability>_sounds with its pitch and volume settings, e.g. play_ability(&"gun") plays from gun_sounds
func play_ability(ability: StringName, ignore_pause := false) -> void:
	var sounds: Array = get(String(ability) + "_sounds")
	if sounds.is_empty():
		return
	var base_pitch: float = get(String(ability) + "_pitch")
	var variation: float = get(String(ability) + "_pitch_variation")
	var db_offset: float = get(String(ability) + "_db_offset")
	var pitch := base_pitch + randf_range(-variation, variation)
	play_sfx(sounds.pick_random(), ability_volume_db + db_offset, maxf(pitch, 0.01), ignore_pause)
