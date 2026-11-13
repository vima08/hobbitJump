extends SceneTree
## Реальная основная сцена и Input Map. Числа не заменяют визуальную приёмку.
var _level: Node3D
var _player: CharacterBody3D
var _visual: Node3D
var _camera: Camera3D
var _directory := "res://artifacts/gait/after"
var _legacy := false
var _episode := "setup"
var _metrics := {}
var _samples: Array = []
var _previous: Array = [{}, {}]
var _swing_start := [-1.0, -1.0]
var _time := 0.0
var _elapsed := 0.0
var _previous_pelvis := 0.0
var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--legacy":
			_legacy = true
			_directory = "res://artifacts/gait/baseline"
		elif argument.begins_with("--output="):
			_directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(_directory)
	_level = load("res://scenes/main.tscn").instantiate()
	if _legacy:
		_level.get_node("Player/Visual").set_script(load("res://artifacts/gait-baseline-hero_visual.gd"))
	root.add_child(_level)
	current_scene = _level
	_player = _level.get_node("Player")
	_visual = _player.get_node("Visual")
	_camera = _level.get_node("Camera")
	await _ticks(12)
	for strength in [0.15, 0.20, 0.35, 0.60, 1.0]:
		await _place(_level.get_node("CheckpointDock").position + Vector3(-7, 0.33, 0))
		_begin("dock_analog_%.2f" % strength)
		await _motion(Vector3.RIGHT, strength, 150)
		_begin("stop_%.2f" % strength)
		await _motion(Vector3.ZERO, 0, 36)
	await _place(_level.get_node("CheckpointDock").position + Vector3(-5, 0.33, 0))
	_begin("turn")
	await _motion(Vector3.RIGHT, 0.35, 40)
	await _motion(Vector3.LEFT, 0.35, 40)
	await _motion(Vector3.RIGHT, 1, 40)
	await _motion(Vector3.ZERO, 0, 36)
	await _place(_level.get_node("CheckpointDock").position + Vector3(-5, 0.33, 0))
	_begin("input_ramp")
	for tick in 60:
		await _motion(Vector3.RIGHT, (tick + 1) / 60.0, 1)
	for tick in 60:
		await _motion(Vector3.RIGHT, 1.0 - (tick + 1) / 60.0, 1)
	await _motion(Vector3.ZERO, 0, 36)
	await _place(_level.get_node("CheckpointDock").position + Vector3(-3, 0.33, 0))
	_begin("turn_90")
	await _motion(Vector3.RIGHT, 0.35, 40)
	await _motion(Vector3.FORWARD, 0.35, 24)
	await _motion(Vector3.LEFT, 0.35, 40)
	await _motion(Vector3.BACK, 0.35, 24)
	await _motion(Vector3.ZERO, 0, 36)
	await _place(_level.get_node("CheckpointDock").position + Vector3(-3, 0.33, 0))
	_begin("turn_180")
	await _motion(Vector3.RIGHT, 0.60, 45)
	await _motion(Vector3.LEFT, 0.60, 45)
	await _motion(Vector3.ZERO, 0, 36)
	for kind in 2:
		var carrier := _safe_carrier(kind, 14.0)
		await _place(carrier.global_position + Vector3(0, 0.5, 0))
		_begin("carrier_%d_idle" % kind)
		await _motion(Vector3.ZERO, 0, 600)
		_begin("carrier_%d_walk" % kind)
		await _motion(Vector3.RIGHT, 0.15, 32)
		await _motion(Vector3.LEFT, 0.15, 32)
		_begin("carrier_%d_jump_landing" % kind)
		Input.action_press("jump")
		await _ticks(1)
		Input.action_release("jump")
		await _motion(Vector3.ZERO, 0, 75)
	await _place(Vector3(0, 0.03, 2.55))
	_begin("dock_edge_departure")
	await _motion(Vector3.FORWARD, 0.35, 65)
	# Падающий герой подхватывается настоящим движущимся носителем.
	var carrier := _safe_carrier(0, 3.0)
	await _place(carrier.global_position + Vector3(0, 1.5, 0), 0)
	_begin("carrier_pickup")
	await _motion(Vector3.ZERO, 0, 80)
	_release()
	_validate()
	var report := {"physics_hz": Engine.physics_ticks_per_second, "legacy": _legacy,
		"input": "Synthetic Input Map, desired magnitude after radial deadzone; player speed unchanged",
		"limits": {"steady_placements_per_second": 6.5, "stance_error_m": 0.025,
			"grounded_turn_sole_delta_m_at_60hz": 0.08},
		"metrics": _metrics, "failures": _failures, "samples": _samples}
	var file := FileAccess.open(_directory + "/behavior.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("GAIT_BEHAVIOR ", JSON.stringify({"legacy": _legacy, "metrics": _metrics, "failures": _failures}))
	paused = true
	await _level.get_node("Feedback").prepare_shutdown()
	quit(0 if _failures.is_empty() else 1)

func _begin(label: String) -> void:
	_episode = label
	_elapsed = 0
	_previous = [{}, {}]
	_swing_start = [-1.0, -1.0]
	_previous_pelvis = float(_visual.get("_torso").position.y)
	_metrics[label] = {"frames": 0, "grounded_frames": 0, "steady_frames": 0,
		"placements": 0, "steady_placements": 0, "swing_seconds": [],
		"speed_sum": 0.0, "speed_max": 0.0, "stance_error_max": 0.0,
		"steady_speed_min": INF, "steady_speed_max": 0.0,
		"steady_pelvis_y_min": INF, "steady_pelvis_y_max": -INF,
		"steady_pelvis_frame_delta_max": 0.0, "steady_sole_frame_delta_max": 0.0,
		"grounded_sole_frame_delta_max": 0.0, "grounded_target_frame_delta_max": 0.0,
		"pose_error_max": 0.0, "grounded_pose_error_max": 0.0,
		"stance_drift_max": 0.0, "stance_total_drift_max": 0.0,
		"sole_frame_delta_max": 0.0, "pelvis_frame_delta_max": 0.0,
		"pelvis_y_min": 0.0, "phase_frame_delta_max": 0.0}

func _place(position: Vector3, settle := 24) -> void:
	_release()
	_episode = "setup"
	_player.position = position
	_player.velocity = Vector3.ZERO
	_player.set("support_body", null)
	_visual.set("_initialized", false)
	_camera.snap_to_target()
	await _ticks(settle)

func _nearest_carrier(kind: int) -> Node3D:
	var selected: Node3D
	var distance := INF
	for carrier in get_nodes_in_group("floating_platforms"):
		if carrier.kind == kind and absf(carrier.global_position.x) < distance:
			distance = absf(carrier.global_position.x)
			selected = carrier
	return selected

func _safe_carrier(kind: int, horizon_seconds: float) -> Node3D:
	var selected: Node3D
	var distance := INF
	for carrier in get_nodes_in_group("floating_platforms"):
		if carrier.kind != kind or carrier.position.y < -0.31:
			continue
		# Полный сценарий заканчивается до водопада, без рециклинга носителя.
		if carrier.position.x + carrier.drift_speed * horizon_seconds >= carrier.FALL_CREST - 2.0:
			continue
		if absf(carrier.position.x) < distance:
			distance = absf(carrier.position.x)
			selected = carrier
	assert(is_instance_valid(selected), "No carrier can safely complete requested ride")
	return selected

func _release() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)

func _motion(direction: Vector3, strength: float, count: int) -> void:
	for tick in count:
		_release()
		if strength > 0:
			var right := _camera.global_basis.x
			var back := _camera.global_basis.z
			right.y = 0
			back.y = 0
			var axes := Vector2(direction.dot(right.normalized()), direction.dot(back.normalized())).normalized()
			var deadzone := InputMap.action_get_deadzone("move_right")
			axes *= deadzone + strength * (1.0 - deadzone)
			Input.action_press("move_right" if axes.x >= 0 else "move_left", absf(axes.x))
			Input.action_press("move_back" if axes.y >= 0 else "move_forward", absf(axes.y))
		await _ticks(1)

func _ticks(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
		_time += 1.0 / Engine.physics_ticks_per_second
		if _episode != "setup":
			_sample()

func _sample() -> void:
	var delta := 1.0 / Engine.physics_ticks_per_second
	_elapsed += delta
	var metric: Dictionary = _metrics[_episode]
	metric.frames += 1
	var grounded := _player.is_on_floor()
	metric.grounded_frames += int(grounded)
	var steady := _elapsed > 0.5 and grounded
	metric.steady_frames += int(steady)
	var speed: float = _player.get("locomotion_velocity").length()
	metric.speed_sum += speed
	metric.speed_max = maxf(metric.speed_max, speed)
	var debug: Dictionary = _visual.gait_debug()
	var pelvis: float = _visual.get("_torso").position.y
	if steady:
		metric.steady_speed_min = minf(metric.steady_speed_min, speed)
		metric.steady_speed_max = maxf(metric.steady_speed_max, speed)
		metric.steady_pelvis_y_min = minf(metric.steady_pelvis_y_min, pelvis)
		metric.steady_pelvis_y_max = maxf(metric.steady_pelvis_y_max, pelvis)
		metric.steady_pelvis_frame_delta_max = maxf(metric.steady_pelvis_frame_delta_max, absf(pelvis - _previous_pelvis))
	metric.pelvis_frame_delta_max = maxf(metric.pelvis_frame_delta_max, absf(pelvis - _previous_pelvis))
	metric.pelvis_y_min = minf(metric.pelvis_y_min, pelvis)
	_previous_pelvis = pelvis
	var support := _player.get("support_body") as Node3D
	var sample := {"time": _time, "episode": _episode, "speed": speed,
		"grounded": grounded, "player": _vector(_player.position), "pelvis_y": pelvis,
		"visual_rotation": _vector(_visual.global_rotation),
		"support": str(support.name) if is_instance_valid(support) else "world", "feet": []}
	for index in 2:
		var foot: Dictionary = debug.feet[index]
		var sole: Vector3 = foot.sole
		var target: Vector3 = foot.target
		var local := support.to_local(sole) if is_instance_valid(support) else sole
		var local_target := support.to_local(target) if is_instance_valid(support) else target
		var pose_error := sole.distance_to(target)
		metric.pose_error_max = maxf(metric.pose_error_max, pose_error)
		if grounded:
			metric.grounded_pose_error_max = maxf(metric.grounded_pose_error_max, pose_error)
		var previous: Dictionary = _previous[index]
		var anchor := local
		if not previous.is_empty():
			var same: bool = previous.support == support
			if same:
				metric.sole_frame_delta_max = maxf(metric.sole_frame_delta_max, local.distance_to(previous.sole))
				if grounded and previous.grounded:
					metric.grounded_sole_frame_delta_max = maxf(metric.grounded_sole_frame_delta_max, local.distance_to(previous.sole))
					metric.grounded_target_frame_delta_max = maxf(metric.grounded_target_frame_delta_max, local_target.distance_to(previous.target))
				if steady:
					metric.steady_sole_frame_delta_max = maxf(metric.steady_sole_frame_delta_max, local.distance_to(previous.sole))
			metric.phase_frame_delta_max = maxf(metric.phase_frame_delta_max, absf(float(debug.phase) - previous.phase))
			if grounded and foot.stance and (not previous.stance or foot.plant_id != previous.plant_id):
				metric.placements += 1
				metric.steady_placements += int(steady)
				if _swing_start[index] >= 0:
					metric.swing_seconds.append(_time - _swing_start[index])
				_swing_start[index] = -1
			if grounded and not foot.stance and previous.stance:
				_swing_start[index] = _time
			if same and foot.stance and previous.stance and foot.plant_id == previous.plant_id:
				anchor = previous.anchor
				metric.stance_drift_max = maxf(metric.stance_drift_max, local.distance_to(previous.sole))
				metric.stance_total_drift_max = maxf(metric.stance_total_drift_max, local.distance_to(anchor))
		if grounded and foot.stance:
			metric.stance_error_max = maxf(metric.stance_error_max, foot.contact_error)
		_previous[index] = {"support": support, "sole": local, "anchor": anchor,
			"target": local_target, "grounded": grounded,
			"stance": foot.stance, "plant_id": foot.plant_id, "phase": float(debug.phase)}
		var leg: Node3D = _visual.get("_left_leg" if index == 0 else "_right_leg")
		sample.feet.append({"stance": foot.stance, "plant_id": foot.plant_id,
			"sole_support": _vector(local), "sole_world": _vector(sole), "error": foot.contact_error,
			"target_world": _vector(target), "target_support": _vector(local_target), "pose_error": pose_error,
			"hip_world": _vector(leg.global_position), "hip_rotation": _vector(leg.global_rotation),
			"hip_support": _vector(support.to_local(leg.global_position) if is_instance_valid(support) else leg.global_position),
			"hip_local_rotation": _vector(leg.rotation)})
	_samples.append(sample)

func _validate() -> void:
	for label in _metrics:
		var metric: Dictionary = _metrics[label]
		metric.speed_mean = metric.speed_sum / maxf(1, metric.frames)
		metric.steady_placements_per_second = metric.steady_placements / maxf(0.001, metric.steady_frames / float(Engine.physics_ticks_per_second))
		if metric.stance_error_max > 0.025:
			_failures.append("%s: stance error %.4f > .025 m" % [label, metric.stance_error_max])
		if metric.stance_total_drift_max > 0.025:
			_failures.append("%s: planted drift %.4f > .025 m" % [label, metric.stance_total_drift_max])
		if label.begins_with("dock_analog") and metric.steady_placements_per_second > 6.5:
			_failures.append("%s: cadence %.2f > 6.5 placements/s" % [label, metric.steady_placements_per_second])
		if label.ends_with("_idle") and metric.steady_placements > 0:
			_failures.append("%s: idle carrier starts gait" % label)
		if label in ["turn_90", "turn_180", "carrier_0_walk", "carrier_1_walk"]:
			if metric.grounded_sole_frame_delta_max > 0.08:
				_failures.append("%s: grounded sole jump %.4f > .08 m/frame at 60 Hz" % [label, metric.grounded_sole_frame_delta_max])
	var full: Dictionary = _metrics["dock_analog_1.00"]
	if full.speed_mean < 4.3 or full.grounded_frames < 145:
		_failures.append("full-speed scenario did not sustain real 4.8 m/s grounded motion")
	for strength in [0.15, 0.20, 0.35, 0.60]:
		var label := "dock_analog_%.2f" % strength
		var metric: Dictionary = _metrics[label]
		if absf(metric.speed_mean - 4.8 * strength) > 0.10 or metric.grounded_frames < 145:
			_failures.append("%s: analog scenario did not sustain requested real speed" % label)
	for kind in 2:
		for mode in ["idle", "walk"]:
			var label := "carrier_%d_%s" % [kind, mode]
			var metric: Dictionary = _metrics[label]
			if metric.grounded_frames < metric.frames - 2:
				_failures.append("%s: carrier support was lost during scenario" % label)
		var landing: Dictionary = _metrics["carrier_%d_jump_landing" % kind]
		if landing.grounded_frames < 15 or landing.grounded_frames > landing.frames - 15:
			_failures.append("carrier_%d: jump and landing were not both observed" % kind)
	if _metrics.carrier_pickup.grounded_frames < 20:
		_failures.append("carrier pickup did not acquire support")
	if _metrics.dock_edge_departure.grounded_frames >= _metrics.dock_edge_departure.frames - 5:
		_failures.append("edge departure did not leave support")
	for label in ["input_ramp", "turn_90", "turn_180"]:
		var metric: Dictionary = _metrics[label]
		if metric.grounded_frames < metric.frames - 2:
			_failures.append("%s: motion scenario left dock support" % label)

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
