extends "res://tests/gait_behavior.gd"
## Actual Input Map movement, stable side views in both travel directions.
var _lean_rows: Array = []

func _run() -> void:
	_directory = "res://artifacts/lean-bank/final"
	DirAccess.make_dir_recursive_absolute(_directory)
	_level = load("res://scenes/main.tscn").instantiate()
	root.add_child(_level)
	current_scene = _level
	_player = _level.get_node("Player")
	_visual = _player.get_node("Visual")
	_camera = _level.get_node("Camera")
	await _ticks(12)
	_camera.set_process(false)
	for direction in [Vector3.RIGHT, Vector3.LEFT]:
		for strength in [0.35, 1.0]:
			await _place(_level.get_node("CheckpointDock").position + Vector3(-7 * direction.x, 0.33, 0))
			_begin(("right" if direction.x > 0 else "left") + "_%.2f" % strength)
			for frame in 120:
				_side_camera()
				await _motion(direction, strength, 1)
				if frame in [45, 55, 65, 75]:
					var up: Vector3 = _visual._torso.global_basis.y
					var lean := rad_to_deg(atan2(up.dot(direction), up.y))
					_lean_rows.append({"episode": _episode, "frame": frame, "forward_degrees": lean,
						"speed": _player.locomotion_velocity.length()})
					if lean < 1.0:
						_failures.append("Upper body must lean forward in " + _episode)
					await _picture(_episode + "-%03d" % frame)
			await _motion(Vector3.ZERO, 0, 48)
			_side_camera()
			if absf(_visual._torso.rotation.x) > 0.015:
				_failures.append("Idle torso did not return to neutral")
			await _picture(_episode + "-idle")
	# Normal camera on the newly physical grass on both sides of the start dock.
	_camera.fov = 56
	_camera.set_process(true)
	for x in [-7.0, 7.0]:
		await _place(Vector3(x, 0.4, 5.1), 40)
		_begin("grass-" + ("left" if x < 0 else "right"))
		await _motion(Vector3.RIGHT if x < 0 else Vector3.LEFT, 0.35, 8)
		if not _player.is_on_floor() or _player.position.y < -0.15:
			_failures.append("Player fell through visible grass in " + _episode)
		await _picture(_episode)
	_release()
	var file := FileAccess.open(_directory + "/lean.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"lean": _lean_rows, "failures": _failures}, "  "))
	print("LEAN_CAPTURE failures=", _failures)
	paused = true
	await _level.get_node("Feedback").prepare_shutdown()
	quit(0 if _failures.is_empty() else 1)

func _side_camera() -> void:
	_camera.position = _player.position + Vector3(0, 1.0, 3.4)
	_camera.look_at(_player.position + Vector3(0, 0.48, 0))
	_camera.fov = 36

func _picture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_directory.path_join(label + ".png"))
