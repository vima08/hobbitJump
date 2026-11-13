extends "res://tests/prototype_smoke.gd"
## Rendered review evidence; location changes are fixtures, motion uses real input.
var _directory := "res://artifacts/gauntlet/round-1"

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--round="):
			_directory = "res://artifacts/gauntlet/round-" + argument.trim_prefix("--round=")
	DirAccess.make_dir_recursive_absolute(_directory)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	await _ticks(20)
	_check(is_instance_valid(_player.get_node("Visual").get("_model")), "Character model is instantiated for visual evidence")
	if not _failures.is_empty():
		await _finish()
		return
	await _save("start")
	print("RENDER PROFILE: draw calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_key(KEY_UP, true)
	for index in range(3):
		await _ticks(6)
		await _save("walk-%02d" % index)
	_key(KEY_UP, false)
	# Walk along the real dock to line up with the first moving raft.
	var first := _nearest_float(0, CoursePath.center_x(_level.PLATFORM_POSITIONS[0].z))
	await _walk_to(Vector3(first.position.x, 0, 3.0), false)
	_key(KEY_UP, true)
	_key(KEY_SPACE, true)
	await _ticks(1)
	_key(KEY_SPACE, false)
	for index in range(9):
		await _ticks(5)
		if index == 6:
			_key(KEY_UP, false)
		await _save("jump-%02d" % index)
	_key(KEY_UP, false)
	await _ticks(12)
	_check(_player.is_on_floor() and absf(_player.position.z - _level.PLATFORM_POSITIONS[0].z) < 1.0, "Rendered jump lands on the first raft")
	await _save("landing")
	_player.respawn()
	await _ticks(15)
	var camera: Camera3D = _level.get_node("Camera")
	var original_fov := camera.fov
	camera.set_process(false)
	for side in [1, -1]:
		camera.position = _player.position + Vector3(1.4, 1.5, side * 2.8)
		camera.look_at(_player.position + Vector3(0, 0.72, 0))
		camera.fov = 35
		await _save("character-front" if side == 1 else "character-rear")
	camera.fov = original_fov
	camera.set_process(true)
	for location in [_level.CHECKPOINT_POSITION, _level.END_POSITION + Vector3(0, 0, 1.2)]:
		_player.position = location
		_player.velocity = Vector3.ZERO
		camera.snap_to_target()
		await _ticks(20)
		await _save("middle" if location.z > -30 else "end")
	await _reload_run()
	await _ticks(20)
	_check(await _cross_route(false), "Rendered full course traversal")
	await _save("route-finish")
	await _finish()

func _after_route_landing(lane: int) -> void:
	if lane in [2, 5, 9, 13, 15]:
		await _save("route-%02d" % lane)

func _save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(_directory + "/" + label + ".png") == OK, "Graphics evidence " + label)
