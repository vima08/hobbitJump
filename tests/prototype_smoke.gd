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
	if "--close-window" in OS.get_cmdline_user_args():
		_level.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		return
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		var error := root.get_texture().get_image().save_png("res://artifacts/prototype.png")
		_check(error == OK, "Rendered screenshot saved")
		var portrait_camera: Camera3D = _level.get_node("Camera")
		portrait_camera.set_process(false)
		portrait_camera.position = _player.position + Vector3(1.4, 1.7, 2.8)
		portrait_camera.look_at(_player.position + Vector3(0, 0.7, 0))
		portrait_camera.fov = 35.0
		await process_frame
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png("res://artifacts/character.png")
		_check(error == OK, "Character portrait saved (inspection camera)")
		portrait_camera.fov = 50.0
		portrait_camera.set_process(true)
		portrait_camera.snap_to_target()
		_level.get_node("HUD")._set_paused(true)
		await process_frame
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png("res://artifacts/pause.png")
		_check(error == OK, "Pause screenshot saved")
		_level.get_node("HUD")._set_paused(false)
		for lane in [0, 1]:
			var ride := _nearest_float(lane, 0.0)
			_player.position = ride.position + Vector3(0, 0.5, 0)
			_player.velocity = Vector3.ZERO
			_level.get_node("Camera").snap_to_target()
			await _ticks(30)
			await RenderingServer.frame_post_draw
			error = root.get_texture().get_image().save_png("res://artifacts/riding-%d.png" % lane)
			_check(error == OK, "Riding screenshot saved for kind %d" % lane)
		_player.position = Vector3(0, -1.2, 1.8)
		_player.velocity = Vector3.ZERO
		_level.get_node("Camera").snap_to_target()
		await _ticks(12)
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png("res://artifacts/splash.png")
		_check(error == OK, "Water splash screenshot saved")
		await _ticks(40)
		for location in [Vector3(0, 0.05, -24), Vector3(6, 0.05, -55.5)]:
			_player.position = location
			_player.velocity = Vector3.ZERO
			_level.get_node("Camera").snap_to_target()
			await _ticks(20)
			await RenderingServer.frame_post_draw
			var filename := "checkpoint" if location.z > -30 else "shore-joint"
			error = root.get_texture().get_image().save_png("res://artifacts/%s.png" % filename)
			_check(error == OK, "Location screenshot saved: " + filename)
		_player.position = Vector3(0, 0.05, -53)
		_player.velocity = Vector3.ZERO
		_level.get_node("Camera").snap_to_target()
		await _ticks(5)
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png("res://artifacts/victory.png")
		_check(error == OK, "Victory screenshot saved")
		await _finish()
		return

	_check(_player.is_on_floor(), "Player settles on starting dock")
	var feedback := _level.get_node("Feedback")
	_check(_player.get_node("Visual")._left_leg != null and _player.get_node("Visual")._right_arm != null, "Blender model exposes animated limb pivots")
	_check(feedback._river.stream.get_length() > 4.9 and feedback._river.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "River audio is a looping sample")
	var end_shape: BoxShape3D = _level.get_node("EndDock").get_child(0).shape
	var bank_shape: BoxShape3D = _level.get_node("EndBank").get_child(0).shape
	_check(is_equal_approx(_level.get_node("EndDock").position.z - end_shape.size.z * 0.5, _level.get_node("EndBank").position.z + bank_shape.size.z * 0.5), "Final dock and bank meet without coplanar overlap")
	_check(_level.LANE_SPEEDS.min() < _level.LANE_SPEEDS.max(), "River lanes have distinct speeds")
	var initial := _player.position
	_key(KEY_W, true)
	await _ticks(12)
	_check(absf(_player.get_node("Visual")._left_leg.rotation.x) > 0.05, "Walking animates the model's legs")
	_key(KEY_W, false)
	await _ticks(10)
	_check(_player.position.z < initial.z - 0.5, "W moves toward top of camera")
	_check(absf(_player.position.x - initial.x) < 0.05, "W does not drift sideways")
	_player.respawn()
	await _ticks(12)
	_key(KEY_UP, true)
	await _ticks(12)
	_key(KEY_UP, false)
	await _ticks(10)
	_check(_player.position.z < initial.z - 0.5, "Up arrow moves toward top of camera")
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
	_joy_button(JOY_BUTTON_DPAD_UP, true)
	await _ticks(2)
	_joy_button(JOY_BUTTON_DPAD_UP, false)
	_check(root.gui_get_focus_owner() == _level.get_node("HUD")._sound_toggle, "Sound toggle is reachable with the controller")
	_joy_button(JOY_BUTTON_A, true)
	await _ticks(2)
	_joy_button(JOY_BUTTON_A, false)
	await _ticks(2)
	_check(AudioServer.is_bus_mute(0), "Sound can be muted in pause")
	_joy_button(JOY_BUTTON_A, true)
	await _ticks(2)
	_joy_button(JOY_BUTTON_A, false)
	await _ticks(2)
	_check(not AudioServer.is_bus_mute(0), "Sound can be restored in pause")
	_joy_button(JOY_BUTTON_DPAD_DOWN, true)
	await _ticks(2)
	_joy_button(JOY_BUTTON_DPAD_DOWN, false)
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
	await _ticks(2)
	_check(not _player.visual.visible and not feedback._effects.is_empty(), "Water fall starts a splash before returning")
	await _ticks(40)
	_check(_player.position.distance_to(_player.spawn_position) < 0.2, "Water fall returns to dock")
	_check(_player.visual.visible, "Hero is visible again after the water return")
	await _ticks(40)
	_check(feedback._effects.is_empty(), "Transient splash and landing effects are cleaned up")

	for lane in [0, 1]:
		var ride := _nearest_float(lane, 0.0)
		_player.position = ride.position + Vector3(0, 0.5, 0)
		_player.velocity = Vector3.ZERO
		await _ticks(30)
		_check(_player.is_on_floor(), "Player lands on float kind %d" % lane)
		var relative_start := _player.position - ride.position
		var world_start := ride.position
		var max_error := 0.0
		for frame in range(600):
			await _ticks(1)
			max_error = maxf(max_error, (_player.position - ride.position - relative_start).length())
		_check(max_error < 0.05 and _player.is_on_floor(), "Float kind %d carries idle player for 10 simulated seconds (error %.4f)" % [lane, max_error])
		_check(absf(_player.get_node("Visual")._left_leg.rotation.x) < 0.01, "Idle rider does not run on the moving platform")
		_check(absf(ride.position.x - world_start.x - ride.drift_speed * 10.0) < 0.05, "Float really travels at its configured speed")

	# Pausing must freeze the current as well as the character.
	var paused_float := _nearest_float(0, 0)
	var float_at := paused_float.position
	var water_time: float = _level._river_time
	_level.get_node("HUD")._set_paused(true)
	await _ticks(10)
	_check(paused_float.position.is_equal_approx(float_at), "Pause freezes moving platforms")
	_check(_level._river_time == water_time, "Pause freezes shader ripple time")
	_level.get_node("HUD")._set_paused(false)
	_player.respawn()
	await _ticks(12)

	# A rider returns before reaching the recycle boundary.
	var boundary_ride := _nearest_float(0, 20)
	boundary_ride.position.x = 19.5
	_player.position = boundary_ride.position + Vector3(0, 0.5, 0)
	_player.velocity = Vector3.ZERO
	await _ticks(30)
	_check(_player.is_on_floor() and _player.position.x > 19, "Player rides near the downstream boundary")
	for frame in range(240):
		await _ticks(1)
		if _player.position.distance_to(_player.spawn_position) < 0.2:
			break
	_check(_player.position.distance_to(_player.spawn_position) < 0.2, "Rider returns safely before platform recycling")

	# Force the now empty platform across the recycle boundary outside play.
	var recycling := _nearest_float(0, 20)
	recycling.position.x = recycling.river_half_length - 0.001
	await _ticks(4)
	_check(recycling.position.x < -24.0 and recycling.collision_layer == 1, "Platform outside play recycles and restores collision")
	_check(_player.position.distance_to(_player.spawn_position) < 0.2, "Recycling does not teleport or launch the player")

	for attempt in range(3):
		await _reload_run()
		await _ticks(attempt * 437 + 15)
		var route_start: float = _level.get_node("HUD")._elapsed_seconds
		var completed := await _cross_route(attempt == 0)
		_check(completed, "Full variable-speed route completed, phase %d" % attempt)
		print("ROUTE DURATION: ", _level.get_node("HUD")._elapsed_seconds - route_start)
		if not completed:
			continue
		var hud := _level.get_node("HUD")
		_check(hud._goal_reached and paused and hud._victory_panel.visible, "Finish opens victory and freezes the world")
		_check(not hud._controls.visible, "Victory hides obsolete gameplay hints")
		_check(_level.get_node("Feedback")._sounds["victory"].process_mode == Node.PROCESS_MODE_ALWAYS, "Victory sound remains active while the world is paused")
		var camera: Camera3D = _level.get_node("Camera")
		_check(root.get_visible_rect().has_point(camera.unproject_position(_player.position)), "Player remains visible at finish")
		var finished_time: float = hud._elapsed_seconds
		var finished_at := _player.position
		_joy_button(JOY_BUTTON_START, true)
		await _ticks(5)
		_joy_button(JOY_BUTTON_START, false)
		hud._set_paused(false)
		await _ticks(5)
		_check(paused and hud._elapsed_seconds == finished_time and _player.position.is_equal_approx(finished_at), "Victory cannot be dismissed as an ordinary pause")
		if DisplayServer.get_name() != "headless" and attempt == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/route-finish.png")
		# Activate the actual focused victory button through the gamepad binding.
		_joy_button(JOY_BUTTON_A, true)
		await _ticks(1)
		_joy_button(JOY_BUTTON_A, false)
		await _ticks(5)
		_level = current_scene
		_player = _level.get_node("Player")
		hud = _level.get_node("HUD")
		_check(not paused and not hud._goal_reached and not hud._checkpoint_reached and hud._returns == 0 and hud._elapsed_seconds < 0.3 and _player.spawn_position.is_equal_approx(_level.START_POSITION), "Victory restart resets checkpoint, timer, counters and pause")
	print("PROTOTYPE TEST RESULT: %d failures" % _failures.size())
	await _finish()


func _finish() -> void:
	paused = true
	await current_scene.get_node("Feedback").prepare_shutdown()
	quit(0 if _failures.is_empty() else 1)


func _walk_to(target: Variant, jump: bool) -> void:
	if jump:
		Input.action_press("jump")
	await _ticks(1)
	Input.action_release("jump")
	for frame in range(70):
		if paused:
			break
		var at := _target_position(target)
		var offset := Vector2(at.x - _player.position.x, at.z - _player.position.z)
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


func _target_position(target: Variant) -> Vector3:
	if target is Dictionary:
		return Vector3(target.platform.position.x + target.offset, 0, target.platform.position.z)
	if target is Node3D:
		return Vector3(target.position.x, 0, target.position.z)
	return target


func _reload_run() -> void:
	paused = false
	reload_current_scene()
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")


func _cross_route(check_respawn: bool) -> bool:
	for section in range(2):
		var first := _nearest_float(section * 8, _player.position.x)
		await _walk_to(Vector3(clampf(first.position.x, -4.8 if section == 0 else -15.0, 4.8 if section == 0 else 15.0), 0, 3.0 if section == 0 else -25.5), false)
		for lane in range(section * 8, section * 8 + 8):
			if not await _jump_to_lane(lane):
				print("ROUTE FAILED at lane ", lane, " player ", _player.position)
				return false
		var dock_z := -22.8 if section == 0 else -50.5
		var dock_x := clampf(_player.position.x, -15.0, 15.0)
		await _walk_to(Vector3(dock_x, 0, dock_z), true)
		if not _player.is_on_floor() or absf(_player.position.z - dock_z) > 0.5:
			return false
		await _walk_to(Vector3(dock_x, 0, -24 if section == 0 else -53), false)
		if section == 0:
			_check(_player.spawn_position.is_equal_approx(_level.CHECKPOINT_POSITION), "Checkpoint is activated by actual traversal")
			if check_respawn:
				_player.position.y = -1.2
				await _ticks(40)
				_check(_player.position.distance_to(_level.CHECKPOINT_POSITION) < 0.2, "Fall after checkpoint returns to the intermediate dock")
	return _level.get_node("HUD")._goal_reached


func _jump_to_lane(lane: int) -> bool:
	for frame in range(1200):
		var platform := _nearest_float(lane, _player.position.x)
		var future_x: float = platform.position.x + platform.drift_speed * 0.7
		var offset := clampf(_player.position.x - future_x, -0.65, 0.65)
		if absf(future_x + offset - _player.position.x) < 1.6:
			await _walk_to({"platform": platform, "offset": offset}, true)
			return _player.is_on_floor() and absf(_player.position.z - platform.position.z) < 0.6 and absf(_player.position.x - platform.position.x) < 1.4
		await _ticks(1)
		if not _player.is_on_floor() or absf(_player.position.x) > 19:
			return false
	return false


func _nearest_float(lane: int, x: float) -> AnimatableBody3D:
	var nearest: AnimatableBody3D
	var distance := INF
	for platform in get_nodes_in_group("floating_platforms"):
		if absf(platform.position.z - _level.PLATFORM_POSITIONS[lane].z) > 0.1:
			continue
		if absf(platform.position.x - x) < distance:
			distance = absf(platform.position.x - x)
			nearest = platform
	return nearest


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
