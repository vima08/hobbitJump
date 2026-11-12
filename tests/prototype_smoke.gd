extends SceneTree
## Exercises the real scene, physics and Input Map. No physical controller is emulated.

var _failures: Array[String] = []
var _player: CharacterBody3D
var _level: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	await _ticks(15)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		var error := root.get_texture().get_image().save_png("res://artifacts/prototype.png")
		_check(error == OK, "Rendered screenshot saved")
		_level.get_node("HUD")._set_paused(true)
		await process_frame
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png("res://artifacts/pause.png")
		_check(error == OK, "Pause screenshot saved")
		quit(0 if _failures.is_empty() else 1)
		return

	_check(_player.is_on_floor(), "Player settles on starting dock")
	var initial := _player.position
	_key(KEY_W, true)
	await _ticks(12)
	_key(KEY_W, false)
	await _ticks(10)
	_check(_player.position.z < initial.z - 0.5, "W moves toward top of camera")
	_check(absf(_player.position.x - initial.x) < 0.05, "W does not drift sideways")
	_player.respawn()
	await _ticks(12)
	_joy_axis(JOY_AXIS_LEFT_X, 0.1)
	await _ticks(15)
	_check(absf(_player.velocity.x) < 0.01, "Stick deadzone blocks drift")
	_joy_axis(JOY_AXIS_LEFT_X, 0.5)
	await _ticks(12)
	var half_speed := _player.velocity.x
	_joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await _ticks(12)
	_check(half_speed > 0.2 and half_speed < _player.velocity.x * 0.8, "Stick preserves analog speed")
	_joy_axis(JOY_AXIS_LEFT_X, 0.0)
	_player.respawn()
	await _ticks(12)
	_joy_axis(JOY_AXIS_LEFT_X, 1.0, 2)
	await _ticks(12)
	_check(_player.position.x > 0.5, "Controller bindings accept a nonzero device ID")
	_joy_axis(JOY_AXIS_LEFT_X, 0.0, 2)
	_player.respawn()
	await _ticks(12)
	_joy_button(JOY_BUTTON_DPAD_LEFT, true)
	await _ticks(10)
	_joy_button(JOY_BUTTON_DPAD_LEFT, false)
	_check(_player.position.x < -0.3, "D-pad moves player")
	_player.respawn()
	await _ticks(12)
	_joy_button(JOY_BUTTON_A, true)
	await _ticks(4)
	_joy_button(JOY_BUTTON_A, false)
	_check(_player.position.y > 0.2, "Gamepad bottom button jumps")
	var upward_speed := _player.velocity.y
	_key(KEY_SPACE, true)
	await _ticks(3)
	_key(KEY_SPACE, false)
	_check(_player.velocity.y < upward_speed, "Second press cannot double jump")
	await _ticks(55)
	_check(_player.is_on_floor(), "Player lands after jump")
	_key(KEY_SPACE, true)
	await _ticks(4)
	_key(KEY_SPACE, false)
	_check(_player.position.y > 0.2, "Space jumps from dock")
	await _ticks(55)
	_joy_button(JOY_BUTTON_Y, true)
	await _ticks(2)
	_joy_button(JOY_BUTTON_Y, false)
	_check(_player.position.distance_to(_player.spawn_position) < 0.2, "Top gamepad button returns to start")
	await _ticks(12)

	_joy_button(JOY_BUTTON_START, true)
	await _ticks(2)
	_joy_button(JOY_BUTTON_START, false)
	_check(paused, "Start pauses scene")
	var stopped_at := _player.position
	await _ticks(5)
	_check(_player.position.is_equal_approx(stopped_at), "Pause freezes player physics")
	_check(root.gui_get_focus_owner() is Button, "Pause menu receives controller focus")
	var continue_button := root.gui_get_focus_owner()
	_joy_button(JOY_BUTTON_DPAD_DOWN, true)
	await _ticks(2)
	_joy_button(JOY_BUTTON_DPAD_DOWN, false)
	_check(root.gui_get_focus_owner() != continue_button, "D-pad selects second menu item")
	_joy_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _ticks(2)
	_joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(root.gui_get_focus_owner() == continue_button, "Stick navigates back to Continue")
	_joy_button(JOY_BUTTON_A, true)
	await _ticks(2)
	_joy_button(JOY_BUTTON_A, false)
	await _ticks(2)
	_check(not paused, "Bottom button activates Continue")
	_check(_player.is_on_floor() and _player.position.y < 0.1, "Continue does not trigger a gameplay jump")
	if paused:
		_level.get_node("HUD")._set_paused(false)
	await _ticks(50)

	_player.position = Vector3(6, -1.2, 0)
	await _ticks(4)
	_check(_player.position.distance_to(_player.spawn_position) < 0.2, "Water fall returns to dock")

	for attempt in range(3):
		_player.respawn()
		await _ticks(12)
		await _walk_to(Vector3(0, 0, 3.0), false)
		var completed := true
		for target in [Vector3(0, 0, 0.5), Vector3(1, 0, -2.5), Vector3(-0.7, 0, -5.5), Vector3(0.8, 0, -8.5), Vector3(0, 0, -11.5), Vector3(0, 0, -14.0)]:
			await _walk_to(target, true)
			var gap := Vector2(_player.position.x - target.x, _player.position.z - target.z).length()
			if gap > 0.5 or not _player.is_on_floor():
				completed = false
				break
		_check(completed, "Static route completed, attempt %d" % (attempt + 1))
	_check(_level.get_node("HUD")._goal_reached, "Practice finish is detected")
	var camera: Camera3D = _level.get_node("Camera")
	await _ticks(40)
	_check(not camera.is_position_behind(_player.position), "Following camera keeps player in front")
	var screen_point := camera.unproject_position(_player.position)
	_check(root.get_visible_rect().has_point(screen_point), "Player remains in viewport at finish")
	print("PROTOTYPE TEST RESULT: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _walk_to(target: Vector3, jump: bool) -> void:
	if jump:
		Input.action_press("jump")
	await _ticks(1)
	Input.action_release("jump")
	for frame in range(70):
		var offset := Vector2(target.x - _player.position.x, target.z - _player.position.z)
		var movement := offset.normalized() if offset.length() > 0.12 else Vector2.ZERO
		Input.action_press("move_right", maxf(movement.x, 0.0))
		Input.action_press("move_left", maxf(-movement.x, 0.0))
		Input.action_press("move_back", maxf(movement.y, 0.0))
		Input.action_press("move_forward", maxf(-movement.y, 0.0))
		await _ticks(1)
		if frame > 10 and _player.is_on_floor() and offset.length() < 0.2:
			break
	for action in ["move_right", "move_left", "move_back", "move_forward"]:
		Input.action_release(action)
	await _ticks(8)


func _ticks(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _joy_axis(axis: JoyAxis, value: float, device: int = 0) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _joy_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
