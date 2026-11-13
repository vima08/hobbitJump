extends "res://tests/prototype_smoke.gd"
## Синтетические события проверяют Input Map и физику, но не ghosting клавиатуры.
var _jumps := 0
var _rows: Array[Dictionary] = []
var _floats: Array[Node] = []
var _label := "baseline"
const KEYS = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_Z]


func _release_keys() -> void:
	for code in KEYS:
		_key(code, false)
	Input.flush_buffered_events()


func _fixture(kind: int) -> void:
	_release_keys()
	await _ticks(2)
	_player.set_physics_process(false)
	var carrier: Node3D
	for platform in _floats:
		platform.set_physics_process(false)
		platform.collision_layer = 0
		if kind >= 0 and platform.kind == kind and carrier == null:
			carrier = platform
	if carrier != null:
		carrier.position = Vector3(0, -0.3, -11.5)
		carrier.rotation = Vector3.ZERO
		carrier._restore_collision = false
		carrier.collision_layer = 1
		carrier.set_physics_process(true)
		carrier.reset_physics_interpolation()
	await _ticks(3)
	_player.respawn()
	_player.position = carrier.position + Vector3(0, 0.36, 0) if carrier != null else Vector3(0, 0.05, 4.5)
	_player.reset_physics_interpolation()
	_player.set_physics_process(true)
	await _ticks(12)
	_check(_player.is_on_floor(), "fixture grounded kind=%d" % kind)


func _attempt(kind: int, codes: Array, trial: int, short_tap := false, jump_key: Key = KEY_Z) -> void:
	await _fixture(kind)
	for code in codes:
		_key(code, true)
	await _ticks(2)
	var grounded := _player.is_on_floor()
	var before := _jumps
	var y := _player.position.y
	_key(jump_key, true)
	if short_tap:
		_key(jump_key, false)
	Input.flush_buffered_events()
	await _ticks(5)
	var count := _jumps - before
	var row := {"kind": kind, "keys": str(codes), "jump_key": jump_key, "trial": trial, "short_tap": short_tap, "grounded_before": grounded, "jumps": count, "dy": _player.position.y - y, "vy": _player.velocity.y}
	_rows.append(row)
	_check(grounded and count == 1 and float(row.dy) > 0.05 and float(row.vy) > 0, "diagonal trial " + str(row))
	_release_keys()


func _single_press() -> void:
	await _fixture(-1)
	var before := _jumps
	_key(KEY_Z, true)
	await _ticks(100)
	_check(_jumps - before == 1 and _player.is_on_floor(), "held Z: one jump, landing, no autojump")
	_release_keys()
	await _ticks(2)
	_key(KEY_Z, true)
	await _ticks(4)
	_key(KEY_Z, false)
	await _ticks(2)
	var speed := _player.velocity.y
	_key(KEY_Z, true)
	await _ticks(3)
	_check(_jumps - before == 2 and _player.velocity.y < speed, "new airborne press cannot double jump")
	_release_keys()
	await _ticks(80)
	_check(_jumps - before == 2, "expired airborne request cannot jump at landing")
	await _fixture(-1)
	before = _jumps
	_level.get_node("HUD")._set_paused(true)
	_key(KEY_Z, true)
	Input.flush_buffered_events()
	await _ticks(2)
	_level.get_node("HUD")._set_paused(false)
	await _ticks(8)
	_check(_jumps == before and _player.is_on_floor(), "menu confirmation and held Z cannot jump on resume")
	_release_keys()
	await _ticks(2)
	_key(KEY_Z, true)
	await _ticks(4)
	_check(_jumps == before + 1, "fresh Z after menu release jumps")
	_release_keys()
	await _fixture(-1)
	before = _jumps
	_key(KEY_Z, true)
	Input.flush_buffered_events()
	_player.suppress_menu_jump()
	_key(KEY_Z, false)
	_key(KEY_Z, true)
	Input.flush_buffered_events()
	await _ticks(2)
	var count := _jumps - before
	_rows.append({"scenario": "menu_release_repress_before_physics", "jumps": count, "vy": _player.velocity.y, "y": _player.position.y})
	_check(count == 1, "fresh release/repress between physics clears menu jump suppression")
	_release_keys()


func _extra_inputs() -> void:
	await _fixture(-1)
	var before := _jumps
	_key(KEY_Z, true)
	for index in 6:
		await _ticks(20)
		var event := InputEventKey.new()
		event.physical_keycode = KEY_Z
		event.pressed = true
		event.echo = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _ticks(2)
	_rows.append({"scenario": "z_echo_no_autojump", "jumps": _jumps - before})
	_check(_jumps - before == 1 and _player.is_on_floor(), "keyboard repeat cannot autojump")
	await _fixture(-1)
	before = _jumps
	_key(KEY_Z, true)
	Input.flush_buffered_events()
	_player.suppress_menu_jump()
	_key(KEY_Z, false)
	Input.flush_buffered_events()
	await _ticks(2)
	_rows.append({"scenario": "menu_release_without_repress", "jumps": _jumps - before})
	_check(_jumps == before and _player.is_on_floor(), "released menu confirmation cannot replay stale just_pressed")
	await _fixture(-1)
	before = _jumps
	_joy_button(JOY_BUTTON_A, true)
	Input.flush_buffered_events()
	_player.suppress_menu_jump()
	_joy_button(JOY_BUTTON_A, false)
	_joy_button(JOY_BUTTON_A, true)
	Input.flush_buffered_events()
	await _ticks(2)
	_rows.append({"scenario": "gamepad_menu_release_repress", "jumps": _jumps - before})
	_check(_jumps == before + 1, "synthetic gamepad fresh release/repress after menu jumps")
	_joy_button(JOY_BUTTON_A, false)
	Input.flush_buffered_events()
	for height in [0.35, 1.2]:
		await _fixture(-1)
		_player.respawn()
		_player.position.y = 2.0
		_player.velocity.y = 0.0
		# Wait out stale floor state and coyote grace before the measured press.
		await _ticks(10)
		while _player.position.y > height:
			await _ticks(1)
		_check(not _player.is_on_floor(), "landing buffer fixture airborne height=%s" % height)
		before = _jumps
		_key(KEY_Z, true)
		_key(KEY_Z, false)
		Input.flush_buffered_events()
		var first_landed_tick := -1
		var first_jump_tick := -1
		for tick in 35:
			await _ticks(1)
			if first_landed_tick < 0 and _player.is_on_floor():
				first_landed_tick = tick + 1
			if first_jump_tick < 0 and _jumps > before:
				first_jump_tick = tick + 1
		var expected := 1 if height < 0.5 else 0
		_rows.append({"scenario": "landing_buffer", "drop_height": height, "jumps": _jumps - before, "landed_tick": first_landed_tick, "jump_tick": first_jump_tick})
		_check(_jumps - before == expected and first_landed_tick > 0 and (first_landed_tick < 7 if expected == 1 else first_landed_tick > 8), "landing buffer height=%s expected=%d landing_tick=%d jump_tick=%d" % [height, expected, first_landed_tick, first_jump_tick])


func _unassigned_keys() -> void:
	await _fixture(-1)
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]:
		var start := _player.position
		var before := _jumps
		_key(code, true)
		await _ticks(8)
		_check(_jumps == before and _player.position.distance_to(start) < 0.01, "unassigned key cannot move or jump: %s" % code)
		_check(Input.get_vector("move_left", "move_right", "move_forward", "move_back").is_zero_approx() and not Input.is_action_pressed("jump"), "unassigned key has no gameplay action: %s" % code)
		_key(code, false)
		await _ticks(2)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	_check(not space.is_action("ui_accept"), "Space cannot confirm menus")


func _menu_confirmation() -> void:
	for gamepad in [false, true]:
		await _fixture(-1)
		var before := _jumps
		_level.get_node("HUD")._set_paused(true)
		await _ticks(2)
		if gamepad:
			_joy_button(JOY_BUTTON_A, true)
		else:
			_key(KEY_Z, true)
		await _ticks(4)
		if gamepad:
			_joy_button(JOY_BUTTON_A, false)
		else:
			_key(KEY_Z, false)
		await _ticks(8)
		_check(not paused and _jumps == before and _player.is_on_floor(), "menu confirmation resumes without buffered jump gamepad=%s" % gamepad)
		if paused:
			_level.get_node("HUD")._set_paused(false)
		if gamepad:
			_joy_button(JOY_BUTTON_A, true)
		else:
			_key(KEY_Z, true)
		await _ticks(4)
		_check(_jumps == before + 1, "fresh press after menu confirmation jumps gamepad=%s" % gamepad)
		if gamepad:
			_joy_button(JOY_BUTTON_A, false)
		else:
			_key(KEY_Z, false)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			_label = arg.trim_prefix("--label=").validate_filename()
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	_floats = get_nodes_in_group("floating_platforms")
	_player.jumped.connect(func(): _jumps += 1)
	await _ticks(15)
	if "--capture" in OS.get_cmdline_user_args():
		await _fixture(-1)
		_key(KEY_UP, true)
		_key(KEY_RIGHT, true)
		_key(KEY_Z, true)
		await _ticks(4)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/diagonal-jump/" + _label)
		_check(root.get_texture().get_image().save_png("res://artifacts/diagonal-jump/" + _label + "/debug-input.png") == OK, "debug input GUI capture saved")
		_release_keys()
		await _finish()
		return
	for kind in [-1, 0, 1]:
		for trial in 30:
			await _attempt(kind, [KEY_UP, KEY_RIGHT], trial)
		for codes in [[KEY_UP, KEY_LEFT], [KEY_DOWN, KEY_RIGHT], [KEY_DOWN, KEY_LEFT]]:
			for trial in 3:
				await _attempt(kind, codes, trial)
	for kind in [-1, 0, 1]:
		await _attempt(kind, [KEY_UP, KEY_RIGHT], 0, true)
	await _unassigned_keys()
	await _menu_confirmation()
	await _single_press()
	await _extra_inputs()
	var directory := "res://artifacts/diagonal-jump/" + _label
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory + "/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"label": _label, "engine": Engine.get_version_info(), "synthetic_only": true, "rows": _rows, "failures": _failures}, "\t"))
	print("DIAGONAL_SUMMARY rows=", _rows.size(), " failures=", _failures.size(), " jumps=", _jumps)
	await _finish()
