extends SceneTree
## Real main-scene motion evidence. Setup teleports only between labelled episodes.
var _level: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _label: Label
var _directory := "res://artifacts/river-movement/round-1"
var _episode := "setup"
var _inspection := false
var _offset := Vector3(-0.7, 1.1, 2.8)
var _samples: Array = []
var _metrics := {}
var _previous := [{}, {}]
var _frame := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--round="):
			_directory = "res://artifacts/river-movement/round-" + argument.trim_prefix("--round=")
	DirAccess.make_dir_recursive_absolute(_directory)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	_camera = _level.get_node("Camera")
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	_label = Label.new()
	_label.position = Vector2(24, 82)
	_label.add_theme_font_size_override("font_size", 20)
	overlay.add_child(_label)
	await _ticks(12)
	await _dock("Обычная камера — ходьба", false)
	await _motion(Vector3.RIGHT, 0.45, 75)
	await _motion(Vector3.ZERO, 0, 15)
	await _dock("Крупно сбоку — медленный аналоговый ввод", true)
	await _motion(Vector3.RIGHT, 0.35, 90)
	await _motion(Vector3.ZERO, 0, 15)
	await _dock("Крупно сбоку — полный ход, торможение", true)
	await _motion(Vector3.RIGHT, 1, 42)
	await _motion(Vector3.ZERO, 0, 24)
	await _dock("Смена направления — боком и назад", true)
	await _motion(Vector3.RIGHT, 0.5, 27)
	await _motion(Vector3.FORWARD, 0.35, 18)
	await _motion(Vector3.LEFT, 0.5, 27)
	await _motion(Vector3.BACK, 0.35, 18)
	await _motion(Vector3.ZERO, 0, 15)
	# Existing visible rock wall at the garden end; no artificial test wall.
	await _dock("Старт, стоп и упор в стену берега", true)
	_player.position = Vector3(-20.5, 0.2, 8.0)
	_player.velocity = Vector3.ZERO
	await _motion(Vector3.LEFT, 1, 35)
	await _motion(Vector3.ZERO, 0, 15)
	for kind in 2:
		var raft := _nearest_platform(kind)
		_release()
		_episode = "Стоя на брёвнах" if kind == 0 else "Стоя на бочках"
		_label.text = _episode + " · диагностическая камера"
		_inspection = true
		_camera.set_process(false)
		_player.position = raft.global_position + Vector3(0, 0.5, 0)
		_player.velocity = Vector3.ZERO
		_player.get_node("Visual")._initialized = false
		_previous = [{}, {}]
		await _ticks(18)
		await _motion(Vector3.ZERO, 0, 75)
		_episode = "Ходьба по брёвнам" if kind == 0 else "Ходьба по бочкам"
		_label.text = _episode + " · диагностическая камера"
		await _motion(Vector3.RIGHT, 0.25, 35)
		await _motion(Vector3.LEFT, 0.25, 35)
		await _motion(Vector3.ZERO, 0, 15)
	_release()
	var file := FileAccess.open(_directory + "/gait-telemetry.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"physics_hz": Engine.physics_ticks_per_second,
		"input": "Input Map action strengths; synthetic, not physical controller validation",
		"camera": "normal gameplay and labelled side inspection cameras",
		"metrics": _metrics, "samples": _samples}, "  "))
	print("GAIT_CAPTURE ", JSON.stringify(_metrics))
	paused = true
	await _level.get_node("Feedback").prepare_shutdown()
	quit()

func _dock(label: String, inspection: bool) -> void:
	_release()
	_episode = label
	_inspection = inspection
	_label.text = label + (" · диагностическая камера" if inspection else "")
	_camera.set_process(not inspection)
	_player.position = Vector3(-3, 0.03, 4.0)
	_player.velocity = Vector3.ZERO
	_player.get_node("Visual").rotation.y = PI / 2
	_player.get_node("Visual")._initialized = false
	_previous = [{}, {}]
	_camera.snap_to_target()
	await _ticks(12)

func _nearest_platform(kind: int) -> Node3D:
	var selected: Node3D
	var distance := INF
	for raft in get_nodes_in_group("floating_platforms"):
		if raft.kind == kind and absf(raft.global_position.x) < distance:
			distance = absf(raft.global_position.x)
			selected = raft
	return selected

func _release() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)

func _motion(direction: Vector3, strength: float, ticks: int) -> void:
	for tick in ticks:
		_release()
		if _inspection:
			_camera.global_position = _player.global_position + _offset
			_camera.look_at(_player.global_position + Vector3(0, 0.48, 0))
			_camera.fov = 35
		else:
			_camera.fov = 56
		var right := _camera.global_basis.x
		right.y = 0
		right = right.normalized()
		var back := _camera.global_basis.z
		back.y = 0
		back = back.normalized()
		var x := direction.dot(right) * strength
		var y := direction.dot(back) * strength
		Input.action_press("move_right" if x >= 0 else "move_left", absf(x))
		Input.action_press("move_back" if y >= 0 else "move_forward", absf(y))
		await _ticks(1)

func _ticks(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
		_sample()
		if _frame % 12 == 0 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(_directory + "/gait-%04d.png" % _frame)

func _sample() -> void:
	_frame += 1
	if not _metrics.has(_episode):
		_metrics[_episode] = {"stance_error_max": 0.0, "stance_drift_max": 0.0,
			"stance_height_abs_max": 0.0, "samples": 0, "airborne_frames": 0}
	var metric: Dictionary = _metrics[_episode]
	metric.samples += 1
	if not _player.is_on_floor():
		metric.airborne_frames += 1
	var debug: Dictionary = _player.get_node("Visual").gait_debug()
	var support := _player.get("support_body") as Node3D
	var frame_data := {"frame": _frame, "episode": _episode, "player": _vector(_player.position),
		"relative_velocity": _vector(_player.get("locomotion_velocity")),
		"support": support.name if is_instance_valid(support) else "world", "feet": []}
	for index in 2:
		var foot: Dictionary = debug.feet[index]
		var sole: Vector3 = foot.sole
		var local := support.to_local(sole) if is_instance_valid(support) else sole
		var same: bool = not _previous[index].is_empty() and _previous[index].support == support
		if foot.stance:
			metric.stance_error_max = maxf(metric.stance_error_max, foot.contact_error)
			var plane_y := 0.0
			if is_instance_valid(support):
				for child in support.get_children():
					if child is CollisionShape3D and child.shape is BoxShape3D:
						plane_y = child.position.y + child.shape.size.y * 0.5
						break
			metric.stance_height_abs_max = maxf(metric.stance_height_abs_max, absf(local.y - plane_y))
			if same and _previous[index].stance and _previous[index].plant_id == foot.plant_id:
				metric.stance_drift_max = maxf(metric.stance_drift_max, local.distance_to(_previous[index].sole))
		_previous[index] = {"sole": local, "support": support, "stance": foot.stance, "plant_id": foot.plant_id}
		frame_data.feet.append({"sole_world": _vector(sole), "sole_support": _vector(local),
			"target": _vector(foot.target), "stance": foot.stance, "error": foot.contact_error})
	_samples.append(frame_data)

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
