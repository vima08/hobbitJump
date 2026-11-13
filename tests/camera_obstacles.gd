extends SceneTree
## Real main-scene camera regression. Fixtures isolate camera from player physics.

const CoursePath = preload("res://scripts/course_path.gd")
const MAX_CAMERA_STEP_AT_60_FPS := 0.6
var _level: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _directory := "res://artifacts/camera-obstacles/baseline"
var _capture := false
var _rows: Array = []
var _cases: Array = []
var _frame := 0
var _episode := "setup"
var _caption: Label
var _failures: Array[String] = []
var _overlap_query := PhysicsShapeQueryParameters3D.new()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			_directory = "res://artifacts/camera-obstacles/" + argument.trim_prefix("--label=").get_file()
		_capture = _capture or argument == "--capture"
	DirAccess.make_dir_recursive_absolute(_directory)
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	_camera = _level.get_node("Camera")
	var overlap_shape := SphereShape3D.new()
	overlap_shape.radius = 0.22
	_overlap_query.shape = overlap_shape
	_overlap_query.collision_mask = 1
	_overlap_query.margin = 0.0
	var soft_exclusions: Array[RID] = []
	for body in get_nodes_in_group("camera_soft_bodies"):
		soft_exclusions.append(body.get_rid())
	_overlap_query.exclude = soft_exclusions
	if "--legacy-camera" in OS.get_cmdline_user_args():
		_camera.set_script(load("res://artifacts/camera-obstacles/legacy_follow_camera.gd"))
		_camera.set("target", _player)
		_camera.snap_to_target()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(20, 90)
	_caption.add_theme_font_size_override("font_size", 20)
	layer.add_child(_caption)
	await _ticks(5, false)
	_player.set_physics_process(false)
	for z in [0.5, -14.5, -39.5]:
		await _sweep("left-%.1f" % z, Vector3(-21.8, 0.05, z), Vector3(-22.7, 0.05, z))
		await _sweep("left-edge-%.1f" % z, Vector3(-22.7, 0.05, z - 1.5), Vector3(-22.7, 0.05, z + 1.5))
	var placements := [Vector2(12, -1), Vector2(12, -13), Vector2(-12, -29), Vector2(-12, -41)]
	for index in 4:
		var placement: Vector2 = placements[index]
		var center := Vector3(CoursePath.center_x(placement.y) + placement.x, 0.05, placement.y)
		# Camera arm passes behind each exact trunk: approach from the upstream row,
		# then cross sideways through the thin obstruction. World geometry is intact.
		await _sweep("tree%d-lateral" % index, center + Vector3(-0.65, 0, -2), center + Vector3(0.65, 0, -2))
		await _sweep("tree%d-forward" % index, center + Vector3(0.50, 0, 1.5), center + Vector3(0.50, 0, -5))
	await _input_episode("solid-input", Vector3(0, 0.1, 5), "move_forward", 0.55)
	var raft: Node3D = _level.get_node("Float0_3")
	await _input_episode("raft-input", raft.global_position + Vector3(0, 0.65, 0), "move_left", 0.45)
	# Wait for a real upstream-row raft, without moving any world geometry.
	var approach_x := CoursePath.center_x(-1) + 12.5
	var approach_raft: Node3D
	var nearest_distance := INF
	for candidate in get_nodes_in_group("floating_platforms"):
		if absf(candidate.global_position.z + 2.5) < 0.01 and candidate.global_position.x <= approach_x:
			var distance: float = approach_x - candidate.global_position.x
			if distance < nearest_distance:
				nearest_distance = distance
				approach_raft = candidate
	if approach_raft != null:
		while approach_raft.global_position.x < approach_x:
			await _ticks(1, false)
		await _input_episode("tree0-actual-raft-approach", approach_raft.global_position + Vector3(0, 0.65, 0), "move_back", 0.45)
	var summary := {"cases": _cases, "frames": _rows,
		"note": "Fixture sweeps isolate actual camera and scene collisions; Input Map episodes use actual player physics. Synthetic actions do not confirm physical devices. Headless telemetry does not confirm visual comfort.",
		"godot": Engine.get_version_info().string, "viewport": [root.size.x, root.size.y],
		"failures": _failures, "unexpected_flip_threshold_deg_per_frame": 45.0,
		"max_allowed_camera_step_m_per_60fps_frame": MAX_CAMERA_STEP_AT_60_FPS,
		"smoothness_note": "Adjacent recorded frames within each episode only; initial setup and settle excluded. 0.6m/frame is a deliberately generous discontinuity ceiling, not proof of comfortable camera motion.",
		"actual_arm_note": "Distance from camera to nominal ground-framing pivot (_focus.x, _focus.y, player.z); camera-to-focus length retained separately."}
	summary.camera_overlap_note = "Independent sphere radius=0.22m, actual camera position, mask=1, margin=0. Only camera_soft_bodies excluded intentionally: local cutout tree occluders. Player is included. Thin trimesh overlap tests surface contact; does not prove containment-free volume inside closed shells."
	var file := FileAccess.open(_directory + "/telemetry.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	print("CAMERA_OBSTACLES ", JSON.stringify(_cases))
	paused = true
	await _level.get_node("Feedback").prepare_shutdown()
	quit(0 if _failures.is_empty() else 1)

func _sweep(label: String, start: Vector3, finish: Vector3) -> void:
	_episode = label
	_caption.text = label + " · camera fixture / actual scene"
	_player.global_position = start
	_player.velocity = Vector3.ZERO
	_camera.snap_to_target()
	await _ticks(30, false)
	var first := _rows.size()
	for frame in 121:
		_player.global_position = start.lerp(finish, float(frame) / 120.0)
		await _ticks(1)
		if frame in [20, 50, 80, 110]:
			await _save("%s-%03d" % [label, frame])
	await _ticks(30)
	_summarize(first)

func _input_episode(label: String, at: Vector3, action: String, strength: float) -> void:
	_episode = label
	_caption.text = label + " · synthetic Input Map / actual physics"
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(true)
	_camera.snap_to_target()
	await _ticks(25, false)
	var first := _rows.size()
	var before := _player.global_position
	Input.action_press(action, strength)
	await _ticks(12)
	Input.action_release(action)
	await _ticks(5)
	_summarize(first)
	var result: Dictionary = _cases.back()
	result.input_action = action
	result.input_strength = strength
	result.actual_displacement = _v(_player.global_position - before)
	var displacement := _player.global_position - before
	result.expected_axis_sign = "z < 0" if action == "move_forward" else ("z > 0" if action == "move_back" else "x < 0")
	result.actual_axis_sign_correct = displacement.z < 0 if action == "move_forward" else (displacement.z > 0 if action == "move_back" else displacement.x < 0)
	if not result.actual_axis_sign_correct:
		_failures.append(label + ": wrong actual input displacement sign")
	_player.set_physics_process(false)

func _ticks(count: int, record: bool = true) -> void:
	for tick in count:
		await physics_frame
		await process_frame
		_frame += 1
		if record:
			_measure()

func _measure() -> void:
	var focus: Vector3 = _camera.get("_focus")
	var back := _camera.global_basis.z
	var right := _camera.global_basis.x
	back.y = 0
	right.y = 0
	back = back.normalized()
	right = right.normalized()
	var hero := _player.global_position + Vector3(0, 0.65, 0)
	var screen := _camera.unproject_position(hero)
	var size := root.get_visible_rect().size
	_overlap_query.transform = Transform3D(Basis.IDENTITY, _camera.global_position)
	var overlaps := _camera.get_world_3d().direct_space_state.intersect_shape(_overlap_query, 16)
	var overlap_names: Array[String] = []
	for overlap in overlaps:
		overlap_names.append(str(overlap.collider.get_path()))
	_rows.append({"frame": _frame, "episode": _episode,
		"player": _v(_player.global_position), "camera": _v(_camera.global_position), "focus": _v(focus),
		"yaw_deg": rad_to_deg(atan2(back.x, back.z)),
		"pitch_deg": rad_to_deg(_camera.global_basis.get_euler().x),
		"arm_length": _camera.global_position.distance_to(focus),
		"actual_arm_length": _camera.global_position.distance_to(Vector3(focus.x, focus.y, _player.global_position.z)),
		"camera_overlap_count": overlaps.size(), "camera_overlap_colliders": overlap_names,
		"camera_minus_focus_x": _camera.global_position.x - focus.x,
		"forward_world_minus_z_dot": (-back).dot(Vector3.FORWARD),
		"right_world_plus_x_dot": right.dot(Vector3.RIGHT),
		"screen_normalized": [screen.x / size.x, screen.y / size.y],
		"head_screen_normalized": _screen(_player.global_position + Vector3(0, 1.25, 0)),
		"feet_screen_normalized": _screen(_player.global_position),
		"hero_behind_camera": _camera.is_position_behind(hero),
		"velocity": _v(_player.velocity), "physics_enabled": _player.is_physics_processing(),
		"on_floor": _player.is_on_floor() if _player.is_physics_processing() else null})

func _summarize(first: int) -> void:
	var result := {"episode": _episode, "max_abs_yaw_deg": 0.0, "min_arm_length": INF,
		"max_abs_camera_minus_focus_x": 0.0, "unexpected_flips": 0, "max_yaw_step_deg": 0.0,
		"max_camera_step": 0.0, "max_camera_step_frame": -1, "max_pitch_step_deg": 0.0,
		"min_actual_arm_length": INF,
		"camera_overlap_frames": 0, "max_camera_overlap_count": 0,
		"hero_outside_screen_frames": 0, "head_outside_screen_frames": 0, "feet_outside_screen_frames": 0,
		"grounded_frames": 0, "min_forward_dot": 1.0, "min_right_dot": 1.0}
	var previous_yaw: float = _rows[first].yaw_deg
	var previous_row: Dictionary = _rows[first]
	for index in range(first, _rows.size()):
		var row: Dictionary = _rows[index]
		if row.on_floor == true:
			result.grounded_frames += 1
		if row.camera_overlap_count > 0:
			result.camera_overlap_frames += 1
		result.max_camera_overlap_count = maxi(result.max_camera_overlap_count, row.camera_overlap_count)
		result.max_abs_yaw_deg = maxf(result.max_abs_yaw_deg, absf(row.yaw_deg))
		result.min_arm_length = minf(result.min_arm_length, row.arm_length)
		result.min_actual_arm_length = minf(result.min_actual_arm_length, row.actual_arm_length)
		var position_now := Vector3(row.camera[0], row.camera[1], row.camera[2])
		var position_before := Vector3(previous_row.camera[0], previous_row.camera[1], previous_row.camera[2])
		var camera_step := position_now.distance_to(position_before)
		if camera_step > result.max_camera_step:
			result.max_camera_step = camera_step
			result.max_camera_step_frame = row.frame
		var pitch_step := absf(rad_to_deg(angle_difference(deg_to_rad(previous_row.pitch_deg), deg_to_rad(row.pitch_deg))))
		result.max_pitch_step_deg = maxf(result.max_pitch_step_deg, pitch_step)
		previous_row = row
		result.max_abs_camera_minus_focus_x = maxf(result.max_abs_camera_minus_focus_x, absf(row.camera_minus_focus_x))
		var yaw_step := absf(rad_to_deg(angle_difference(deg_to_rad(previous_yaw), deg_to_rad(row.yaw_deg))))
		result.max_yaw_step_deg = maxf(result.max_yaw_step_deg, yaw_step)
		if yaw_step > 45.0:
			result.unexpected_flips += 1
		previous_yaw = row.yaw_deg
		result.min_forward_dot = minf(result.min_forward_dot, row.forward_world_minus_z_dot)
		result.min_right_dot = minf(result.min_right_dot, row.right_world_plus_x_dot)
		var screen: Array = row.screen_normalized
		if row.hero_behind_camera or screen[0] < 0 or screen[0] > 1 or screen[1] < 0 or screen[1] > 1:
			result.hero_outside_screen_frames += 1
		for landmark in ["head", "feet"]:
			var point: Array = row[landmark + "_screen_normalized"]
			if point[0] < 0 or point[0] > 1 or point[1] < 0 or point[1] > 1:
				result[landmark + "_outside_screen_frames"] += 1
	if result.max_abs_yaw_deg > 1.0:
		_failures.append(_episode + ": yaw exceeds 1 degree")
	if result.hero_outside_screen_frames > 0:
		_failures.append(_episode + ": hero centre behind camera or outside screen")
	if result.min_forward_dot <= 0 or result.min_right_dot <= 0:
		_failures.append(_episode + ": camera movement axis reversed")
	if result.max_camera_step > MAX_CAMERA_STEP_AT_60_FPS:
		_failures.append(_episode + ": camera movement exceeds fixed 0.6m/frame discontinuity ceiling")
	if result.camera_overlap_frames > 0:
		_failures.append(_episode + ": camera sphere overlaps hard world geometry or player")
	_cases.append(result)

func _screen(point: Vector3) -> Array:
	var position := _camera.unproject_position(point)
	var size := root.get_visible_rect().size
	return [position.x / size.x, position.y / size.y]

func _save(label: String) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_directory + "/" + label + ".png")

func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
