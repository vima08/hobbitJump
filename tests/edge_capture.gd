extends "res://tests/river_behavior.gd"
## Edge evidence over actual main-scene physics. Setup placement precedes each episode.
var _directory := "res://artifacts/river-movement/round-1"
var _camera: Camera3D
var _caption: Label
var _episode := "setup"
var _record := false
var _frame := 0
var _rows: Array = []
var _summaries: Array = []
var _sole_vertices: Array = [PackedVector3Array(), PackedVector3Array()]
var _camera_offset := Vector3(0, 1.0, 3.0)

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--round="):
			_directory = "res://artifacts/river-movement/round-" + argument.trim_prefix("--round=")
	DirAccess.make_dir_recursive_absolute(_directory)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	_player.camera = null
	_camera = _level.get_node("Camera")
	_camera.set_process(false)
	_camera.fov = 38
	_floats = get_nodes_in_group("floating_platforms")
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	_caption = Label.new()
	_caption.position = Vector2(20, 82)
	_caption.add_theme_font_size_override("font_size", 19)
	overlay.add_child(_caption)
	await _ticks(10)
	var visual := _player.get_node("Visual")
	for index in 2:
		var leg: Node3D = visual._feet[index].leg
		var mesh: MeshInstance3D = leg.get_child(0)
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				# Original plantar vertices have full foot-bone weight. Transform these
				# actual mesh vertices, rather than treating the ankle target as contact.
				if vertex.y <= -0.42:
					_sole_vertices[index].append(vertex + Vector3(0, 0.32, 0))
	for kind in 2:
		var half := Vector2(1.5 if kind == 0 else 1.3, 0.9)
		for direction in [Vector2.RIGHT, Vector2.UP, Vector2(half.x, half.y).normalized()]:
			_record = false
			await _setup(kind)
			var start := Vector3(signf(direction.x) * maxf(0, half.x - 0.30), 0.36,
				signf(direction.y) * maxf(0, half.y - 0.30))
			_place_player(_float.position + start)
			_player.get_node("Visual")._initialized = false
			_player.get_node("Visual").rotation.y = atan2(direction.x, direction.y)
			_camera_offset = Vector3(0, 1.0, 3.0) if direction.x != 0 else Vector3(3, 1.0, 0)
			_episode = "%s %s" % ["LOG" if kind == 0 else "BARREL", str(direction)]
			_caption.text = "Край / стоп / возможный подхват · " + _episode + " · диагностическая камера"
			_record = true
			await _ticks(10)
			await _save("before")
			var departure := await _depart(direction, 0.4)
			_release()
			await _save("departure")
			await _ticks(14)
			await _save("stopped-side")
			var recaught := _player.is_on_floor()
			_camera_offset = Vector3(0.01, 3.4, 0.4)
			await _ticks(2)
			await _save("stopped-top")
			await _ticks(8)
			_summaries.append({"episode": _episode, "departed": departure.left,
				"recaught_after_14_ticks": recaught, "player_support_local": _v(_float.to_local(_player.global_position))})
	_record = false
	_release()
	var file := FileAccess.open(_directory + "/edge-telemetry.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"episodes": _summaries, "frames": _rows,
		"measurement": "Actual plantar mesh vertices transformed by Foot bone; visual deck rectangle and y=.3; 2cm vertical contact tolerance",
		"input": "real Input Map physics with synthetic actions; setup teleports between episodes",
		"camera": "labelled side and overhead inspection"}, "  "))
	print("EDGE_CAPTURE ", JSON.stringify(_summaries))
	paused = true
	await _level.get_node("Feedback").prepare_shutdown()
	quit()

func _ticks(count: int) -> void:
	for tick in count:
		if is_instance_valid(_camera) and is_instance_valid(_player):
			_camera.global_position = _player.global_position + _camera_offset
			_camera.look_at(_player.global_position + Vector3(0, 0.37, 0))
		await physics_frame
		await process_frame
		if _record:
			_frame += 1
			_measure()
			if _frame % 6 == 0:
				await _save("frame")

func _measure() -> void:
	var visual := _player.get_node("Visual")
	var debug: Dictionary = visual.gait_debug()
	var half_x := 1.5 if _float.kind == 0 else 1.3
	var feet: Array = []
	var supported_feet := 0
	for index in 2:
		var rig: Skeleton3D = visual._feet[index].rig
		var pose := rig.global_transform * rig.get_bone_global_pose(2)
		var support_points: Array = []
		var lowest := INF
		var plantar_inside := 0
		for vertex in _sole_vertices[index]:
			var local := _float.to_local(pose * vertex)
			lowest = minf(lowest, local.y)
			if absf(local.x) <= half_x and absf(local.z) <= 0.9:
				plantar_inside += 1
				if absf(local.y - 0.3) <= 0.02:
					support_points.append(_v(local))
		if not support_points.is_empty():
			supported_feet += 1
		feet.append({"sole_marker": _v(debug.feet[index].sole), "stance": debug.feet[index].stance,
			"contact_error": debug.feet[index].contact_error, "lowest_plantar_support_y": lowest,
			"plantar_vertices_inside_deck": plantar_inside, "plantar_contact_points": support_points})
	_rows.append({"frame": _frame, "episode": _episode, "on_floor": _player.is_on_floor(),
		"support_name": str(_player.support_body.name) if is_instance_valid(_player.support_body) else "none",
		"player_support_local": _v(_float.to_local(_player.global_position)),
		"supported_feet": supported_feet, "feet": feet})

func _save(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_directory + "/edge-%04d-%s.png" % [_frame, label])

func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
