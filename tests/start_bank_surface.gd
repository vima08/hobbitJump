extends SceneTree
## Real player/input regression for the visible grass beside the start dock.
var _level: Node3D
var _player: CharacterBody3D
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _exclude: Array[RID] = []
var _falls := 0
var _respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _ticks(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _check(ok: bool, label: String, data: Dictionary = {}) -> void:
	_checks.append({"pass": ok, "label": label, "measurements": data})
	print("PASS: " if ok else "FAIL: ", label, " ", data)
	if not ok:
		_failures.append(label)


func _release() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)


func _ray(x: float, z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 5, z), Vector3(x, -2, z), 1)
	query.exclude = _exclude
	return _level.get_world_3d().direct_space_state.intersect_ray(query)


func _mesh_height(mesh: Mesh, x: float, z: float) -> float:
	var faces := mesh.get_faces()
	var point := Vector2(x, z)
	for index in range(0, faces.size(), 3):
		var a := Vector2(faces[index].x, faces[index].z)
		var b := Vector2(faces[index + 1].x, faces[index + 1].z)
		var c := Vector2(faces[index + 2].x, faces[index + 2].z)
		var denominator := (b - a).cross(c - a)
		if absf(denominator) < 0.00001:
			continue
		var u := (point - a).cross(c - a) / denominator
		var v := (b - a).cross(point - a) / denominator
		if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
			return faces[index].y * (1.0 - u - v) + faces[index + 1].y * u + faces[index + 2].y * v
	return NAN


func _surface_rays() -> void:
	var mesh: Mesh = _level.get_node("RiverScenery/StartShoreSlope").mesh
	var count := 0
	var error := 0.0
	var matched := true
	for x in [-18.0, -9.0, -6.0, 6.0, 9.0, 18.0]:
		for z in [3.5, 4.5, 5.5, 6.5, 8.0, 12.0, 16.0, 22.0, 25.0]:
			var expected := _mesh_height(mesh, x, z)
			var hit := _ray(x, z)
			matched = matched and not is_nan(expected) and not hit.is_empty()
			if not hit.is_empty():
				error = maxf(error, absf(hit.position.y - expected))
			count += 1
	_check(matched and error < 0.002, "grass collision matches visible mesh on both sides, toe to crest", {"samples": count, "maximum_error": error})
	_check(_level.get_node_or_null("StartBank") == null, "flat hidden StartBank support removed")
	var river_clear := true
	for x in [-18.0, -9.0, 9.0, 18.0]:
		for z in [2.0, 0.5, -2.5, -8.5, -18.0]:
			river_clear = river_clear and _ray(x, z).is_empty()
	_check(river_clear, "open river has no added ground above water")
	_check(_ray(23.5, 5.0).is_empty() and _ray(23.5, -1.0).is_empty(), "shore ends at visible waterfall edge x=23")
	var hull := BoxShape3D.new()
	hull.size = Vector3(3.0, 1.8, 1.8)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull
	query.exclude = _exclude
	query.collision_mask = 1
	var clear := true
	for index in 221:
		query.transform = Transform3D(Basis.IDENTITY, Vector3(-22.0 + index * 0.2, -0.65, 0.5))
		clear = clear and _level.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
	_check(clear, "first float row full hull still clears shore across river", {"samples": 221})


func _walk_to(target: Vector2) -> Dictionary:
	var grounded := true
	var max_error := 0.0
	var max_camera_raise := 0.0
	for tick in 360:
		var at := Vector2(_player.position.x, _player.position.z)
		var delta := target - at
		_release()
		if delta.length() < 0.13:
			await _ticks(8)
			return {"reached": true, "grounded": grounded, "maximum_surface_error": max_error, "maximum_camera_raise": max_camera_raise, "position": str(_player.position)}
		var input := delta.normalized() * minf(0.6, delta.length() * 2.0)
		Input.action_press("move_right" if input.x > 0 else "move_left", absf(input.x))
		Input.action_press("move_back" if input.y > 0 else "move_forward", absf(input.y))
		await _ticks(1)
		grounded = grounded and _player.is_on_floor()
		max_camera_raise = maxf(max_camera_raise, _level.get_node("Camera")._raised_view)
		var hit := _ray(_player.position.x, _player.position.z)
		if not hit.is_empty():
			max_error = maxf(max_error, absf(_player.position.y - hit.position.y))
	_release()
	return {"reached": false, "grounded": grounded, "position": str(_player.position)}


func _walking() -> void:
	for side in [-1.0, 1.0]:
		_player.respawn()
		await _ticks(15)
		var falls_before := _falls
		for target in [Vector2(side * 9.0, 4.8), Vector2(side * 9.0, 12.0), Vector2(side * 9.0, 5.0), Vector2(0, 4.8)]:
			var result := await _walk_to(target)
			_check(result.reached and result.grounded and result.get("maximum_surface_error", 100.0) < 0.08 and _falls == falls_before,
				"real player walks dock/grass roundtrip side=%s target=%s" % [side, target], result)
			_check(result.get("maximum_camera_raise", 100.0) < 0.05, "grass does not trigger overhead camera side=%s target=%s" % [side, target], {"maximum_raise": result.get("maximum_camera_raise")})
		# Walk off the same grass into water: fixture never teleports over river.
		await _walk_to(Vector2(side * 9.0, 5.0))
		var returns_before := _respawns
		Input.action_press("move_forward")
		for tick in 180:
			await _ticks(1)
			if _falls > falls_before:
				break
		_release()
		await _ticks(60)
		_check(_falls == falls_before + 1 and _respawns == returns_before + 1 and _player.position.distance_to(_player.spawn_position) < 0.15,
			"leaving grass into water still falls and respawns side=%s" % side, {"falls": _falls - falls_before, "respawns": _respawns - returns_before})


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	_player.camera = null
	_exclude.append(_player.get_rid())
	for platform in get_nodes_in_group("floating_platforms"):
		_exclude.append(platform.get_rid())
	_player.fell_into_water.connect(func(_at: Vector3): _falls += 1)
	_player.respawned.connect(func(): _respawns += 1)
	await _ticks(15)
	_surface_rays()
	await _walking()
	_release()
	DirAccess.make_dir_recursive_absolute("res://artifacts/start-bank")
	var report := FileAccess.open("res://artifacts/start-bank/surface.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": _checks, "failures": _failures, "limitations": "Real Player with synthetic Input; headless cannot assess appearance or physical keyboard/gamepad."}, "\t"))
	report.close()
	print("START BANK: ", _checks.size(), " checks, ", _failures.size(), " failures")
	await _level.get_node("Feedback").prepare_shutdown()
	quit(0 if _failures.is_empty() else 1)
