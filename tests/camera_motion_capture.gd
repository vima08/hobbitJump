extends "res://tests/prototype_smoke.gd"
## Setup chooses platform phase; all recorded carrying/jumping uses game physics.
var directory := "res://artifacts/camera-obstacles/motion"
var _outside_frames := 0
var _motion_rows: Array = []
var _landing_rows: Array = []
var _landing_outside_frames := 0

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			directory = "res://artifacts/camera-obstacles/" + argument.trim_prefix("--label=").get_file()
	DirAccess.make_dir_recursive_absolute(directory)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	await _ticks(15)
	var tree_x := CoursePath.center_x(-1.0) + 12.0
	await _place_on_raft(1, tree_x - 0.8)
	for frame in 150:
		if frame == 12:
			_key(KEY_Z, true)
		elif frame == 13:
			_key(KEY_Z, false)
		await _ticks(1)
		_measure("tree-jump", frame)
		if frame in [5, 12, 20, 30, 45, 60, 90, 120, 149]:
			await _picture("tree-ride-jump-%03d" % frame)
	_check(_player.is_on_floor(), "Actual ride and Z jump near tree ends on platform")
	await _place_on_raft(0, -21.7)
	_key(KEY_LEFT, true)
	for frame in 90:
		if frame == 12:
			_key(KEY_LEFT, false)
		await _ticks(1)
		_measure("left-approach", frame)
		if frame in [5, 12, 20, 35, 60, 89]:
			await _picture("left-approach-%03d" % frame)
	_key(KEY_LEFT, false)
	# Jump away from the physical inlet wall onto the same moving deck. Setup
	# chooses phase only; takeoff, carrying, air control and landing are real.
	var jump_raft := await _place_on_raft(0, -21.7)
	_key(KEY_LEFT, true)
	await _ticks(12)
	_key(KEY_LEFT, false)
	await _ticks(2)
	_check(_player.is_on_floor() and _player.support_body == jump_raft, "Left-wall jump starts on the actual carrier after real approach")
	var airborne := false
	var landed_same_raft := false
	var peak_y := _player.global_position.y
	var peak_saved := false
	await _picture("left-jump-before")
	_key(KEY_RIGHT, true)
	_key(KEY_Z, true)
	for frame in 90:
		if frame == 1:
			_key(KEY_Z, false)
		if frame == 16:
			_key(KEY_RIGHT, false)
		await _ticks(1)
		_measure("left-jump-right", frame)
		var camera: Camera3D = _level.get_node("Camera")
		# A reachable patch stays on the carrier, slightly right of its centre.
		var landing_point: Vector3 = jump_raft.to_global(Vector3(0.4, 0.31, 0))
		var projection := camera.unproject_position(landing_point)
		var landing_visible := not camera.is_position_behind(landing_point) and root.get_visible_rect().has_point(projection)
		if not landing_visible and not landed_same_raft:
			_landing_outside_frames += 1
		_landing_rows.append({"frame": frame, "visible": landing_visible,
			"landing_world": [landing_point.x, landing_point.y, landing_point.z],
			"landing_screen": [projection.x, projection.y], "on_floor": _player.is_on_floor(),
			"on_same_raft": _player.support_body == jump_raft,
			"player_world": [_player.global_position.x, _player.global_position.y, _player.global_position.z]})
		peak_y = maxf(peak_y, _player.global_position.y)
		if not _player.is_on_floor():
			airborne = true
		if airborne and not peak_saved and _player.velocity.y <= 0:
			peak_saved = true
			await _picture("left-jump-peak")
		if airborne and _player.is_on_floor() and not landed_same_raft:
			landed_same_raft = _player.support_body == jump_raft
			await _picture("left-jump-landing")
	_key(KEY_RIGHT, false)
	_key(KEY_Z, false)
	_check(airborne and peak_y > 0.9, "Actual left-wall jump becomes airborne")
	_check(landed_same_raft, "Actual left-wall jump lands on the same moving platform")
	_check(_landing_outside_frames == 0, "Reachable landing patch remains visible through left-wall jump")
	_check(_outside_frames == 0, "Hero head, body and feet remain framed through actual jump/ride")
	var report := FileAccess.open(directory.path_join("motion.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"outside_frames": _outside_frames, "frames": _motion_rows,
		"left_jump_landed_same_raft": landed_same_raft, "left_jump_peak_y": peak_y,
		"landing_patch_outside_frames": _landing_outside_frames, "landing_frames": _landing_rows,
		"failures": _failures}, "  "))
	print("CAMERA_MOTION failures=", _failures.size())
	await _finish()

func _measure(episode: String, frame: int) -> void:
	var camera: Camera3D = _level.get_node("Camera")
	var outside := false
	var landmarks: Array = []
	for height in [0.05, 0.7, 1.4]:
		var point: Vector3 = _player.global_position + Vector3.UP * height
		var projection := camera.unproject_position(point)
		var point_outside := camera.is_position_behind(point) or not root.get_visible_rect().has_point(projection)
		outside = outside or point_outside
		landmarks.append({"height": height, "screen": [projection.x, projection.y], "outside": point_outside,
			"behind": camera.is_position_behind(point)})
	if outside:
		_outside_frames += 1
	_motion_rows.append({"episode": episode, "frame": frame, "outside": outside,
		"landmarks": landmarks,
		"camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
		"pitch_deg": rad_to_deg(camera.global_rotation.x), "player_y": _player.global_position.y})

func _place_on_raft(lane: int, x: float) -> Node3D:
	_release_movement()
	_player.respawn()
	var raft := _nearest_float(lane, x)
	raft.position.x = x
	_player.global_position = raft.global_position + Vector3(0, 0.45, 0)
	_player.velocity = Vector3.ZERO
	_player.support_body = null
	_level.get_node("Camera").snap_to_target()
	await _ticks(8)
	_check(_player.is_on_floor(), "Motion fixture settles on raft")
	return raft

func _picture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
