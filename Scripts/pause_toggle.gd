extends Node
## Autoload "Pause": P toggles SceneTree.paused for testing. This is the only node that keeps running while paused.
## Also offers game_msec(), a clock that stops while paused, for code that would otherwise use Time.get_ticks_msec().
## hitstop() freezes the game briefly (no label, music unaffected); presses and releases during it are buffered for take_buffered_inputs().

@export var show_label := true

var _paused_total_msec := 0
var _pause_started_msec := -1
var _label: Label
var _menu_paused := false  # Paused with P
var _hitstop_left := 0.0
var _buffered_presses: Array[StringName] = []
var _buffered_releases: Array[StringName] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_label = Label.new()
	_label.text = "PAUSED (P)"
	_label.add_theme_font_size_override("font_size", 32)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.position.y += 16
	_label.visible = false
	layer.add_child(_label)

func _process(delta: float) -> void:
	if _hitstop_left > 0:
		_hitstop_left -= delta
		if _hitstop_left <= 0:
			_update_paused()

func _input(event: InputEvent) -> void:
	# Remember every action pressed or released during a hitstop, so nothing typed in it is lost
	if not in_hitstop() or event.is_echo():
		return
	for action in InputMap.get_actions():
		if event.is_action_pressed(action) and action not in _buffered_presses:
			_buffered_presses.append(action)
		elif event.is_action_released(action) and action not in _buffered_releases:
			_buffered_releases.append(action)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	set_paused(not _menu_paused)

func set_paused(on: bool) -> void:
	_menu_paused = on
	_update_paused()

## Freezes the whole game for duration seconds, like a pause without the label
func hitstop(duration: float) -> void:
	if duration <= 0:
		return
	_hitstop_left = maxf(_hitstop_left, duration)
	_update_paused()

## True during a hitstop, and not paused with P
func in_hitstop() -> bool:
	return _hitstop_left > 0 and not _menu_paused

## True while paused with P (not during a hitstop)
func is_menu_paused() -> bool:
	return _menu_paused

## Returns {"pressed": [...], "released": [...]} for actions pressed or released during the last hitstop, then forgets them
func take_buffered_inputs() -> Dictionary:
	if in_hitstop():
		return {"pressed": [], "released": []}
	var inputs := {"pressed": _buffered_presses, "released": _buffered_releases}
	_buffered_presses = []
	_buffered_releases = []
	return inputs

## Milliseconds since startup, minus time spent paused
func game_msec() -> int:
	var now := Time.get_ticks_msec()
	if _pause_started_msec >= 0:
		now = _pause_started_msec
	return now - _paused_total_msec

func _update_paused() -> void:
	var tree := get_tree()
	var on := _menu_paused or _hitstop_left > 0
	_label.visible = _menu_paused and show_label
	if tree.paused == on:
		return
	tree.paused = on
	if on:
		_pause_started_msec = Time.get_ticks_msec()
	else:
		_paused_total_msec += Time.get_ticks_msec() - _pause_started_msec
		_pause_started_msec = -1
