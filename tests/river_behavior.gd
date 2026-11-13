extends SceneTree
## Fixture setup may place actors. Every measured departure uses real Input/physics.
var _level: Node3D
var _player: CharacterBody3D
var _float: AnimatableBody3D
var _floats: Array[Node] = []
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _jumps := 0
var _falls: Array[Vector3] = []
var _respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _ticks(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _check(ok: bool, label: String, measurements: Dictionary = {}) -> void:
	_checks.append({"pass": ok, "label": label, "measurements": measurements})
	print("PASS: " if ok else "FAIL: ", label, " ", measurements)
	if not ok:
		_failures.append(label)


func _release() -> void:
	for action in ["move_right", "move_left", "move_back", "move_forward", "jump"]:
		Input.action_release(action)


func _jump(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Z
	event.pressed = pressed
	Input.parse_input_event(event)


func _place_player(at: Vector3) -> void:
	_release()
	_player.respawn()
	_player.position = at
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


func _setup(kind: int, x: float = 0.0, speed: float = 0.55) -> void:
	_release()
	_jump(false)
	_player.set_physics_process(false)
	for platform in _floats:
		platform.set_physics_process(false)
		platform.collision_layer = 0
	_float = _floats[kind] as AnimatableBody3D
	# Group order is not relied on: select by the actual kind property.
	for platform in _floats:
		if platform.kind == kind:
			_float = platform
			break
	_float.position = Vector3(x, -0.3, -11.5)
	_float.rotation = Vector3.ZERO
	_float.drift_speed = speed
	_float._restore_collision = false
	_float.collision_layer = 1
	_float.set_physics_process(true)
	_float.reset_physics_interpolation()
	# Let PhysicsServer forget the previous setup teleport before rider placement.
	await _ticks(3)
	_place_player(_float.position + Vector3(0, 0.36, 0) if x >= -23.0 else Vector3(0, 0.05, 4.5))
	_player.set_physics_process(true)
	await _ticks(12)
	var offset := _player.position - _float.position
	_check(_player.is_on_floor() and (x < -23.0 or (absf(offset.x) < 0.15 and absf(offset.z) < 0.15)), "fixture settles kind=%d" % kind, {"offset": str(offset)})


func _move(direction: Vector2, strength: float) -> void:
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left", strength * absf(direction.x))
	if direction.y != 0:
		Input.action_press("move_back" if direction.y > 0 else "move_forward", strength * absf(direction.y))


func _depart(direction: Vector2, strength: float) -> Dictionary:
	_move(direction, strength)
	var previous := _player.position - _float.position
	for tick in 240:
		await _ticks(1)
		var offset := _player.position - _float.position
		if not _player.is_on_floor():
			return {"left": true, "tick": tick, "offset": offset, "last_grounded": previous}
		previous = offset
	return {"left": false, "offset": _player.position - _float.position}


func _edges() -> void:
	var directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]
	for kind in 2:
		var half := Vector2(1.5 if kind == 0 else 1.3, 0.9)
		for direction in directions:
			await _setup(kind)
			if direction.x != 0 and direction.y != 0:
				# Start on a ray toward the visible corner; 45 degrees would hit Z first.
				direction = Vector2(direction.x * half.x, direction.y * half.y).normalized()
			var result := await _depart(direction, 0.4)
			var offset: Vector3 = result.offset
			var outside := Vector2(maxf(0, absf(offset.x) - half.x), maxf(0, absf(offset.z) - half.y)).length()
			var reached_corner := direction.x == 0 or direction.y == 0 or (absf(offset.x) > half.x - 0.15 and absf(offset.z) > half.y - 0.15)
			_check(result.left and outside <= 0.14 and reached_corner, "slow edge/corner kind=%d dir=%s" % [kind, direction], {"offset": str(offset), "outside_visible_deck": outside, "reached_corner": reached_corner})
			_release()
			var departure_y := _player.position.y
			await _ticks(10)
			var relative := _player.position - _float.position
			var recaught := _player.is_on_floor() and absf(relative.x) <= half.x + 0.05 and absf(relative.z) <= half.y + 0.05
			var falling := not _player.is_on_floor() and _player.position.y < departure_y - 0.1
			_check(falling or recaught, "stopping after edge falls or is physically recaught kind=%d dir=%s" % [kind, direction], {"recaught": recaught, "relative": str(relative)})
		# Fast side departure exercises frame-sized overhang separately.
		await _setup(kind)
		var running := await _depart(Vector2.RIGHT, 1.0)
		_check(running.left, "running edge departure kind=%d" % kind, {"offset": str(running.offset)})
		# No input: the river must carry the player without drifting off the deck.
		await _setup(kind)
		var relative_before := _player.position - _float.position
		await _ticks(600)
		var relative_after := _player.position - _float.position
		_check(_player.is_on_floor() and relative_before.distance_to(relative_after) < 0.05, "ten second idle carriage kind=%d" % kind, {"relative_error": relative_before.distance_to(relative_after), "locomotion_speed": _player.locomotion_velocity.length()})


func _coyote() -> void:
	for kind in 2:
		for delay in [2, 5, 8]:
			await _setup(kind)
			# Upstream edge avoids the carrier catching up underneath the hero.
			var result := await _depart(Vector2.LEFT, 0.4)
			_release()
			await _ticks(delay)
			var jumps_before := _jumps
			_jump(true)
			await _ticks(2)
			_jump(false)
			_check(result.left and ((_jumps > jumps_before) == (delay < 6)), "coyote kind=%d delay=%d/60s" % [kind, delay], {"jumps": _jumps - jumps_before, "vertical_velocity": _player.velocity.y})


func _river_limits() -> void:
	for kind in 2:
		await _setup(kind, 10.0)
		var reset_count := _respawns
		await _ticks(180)
		_check(_player.position.x > 10.0 and _player.is_on_floor() and _respawns == reset_count, "old 8.5m boundary is traversable kind=%d" % kind, {"x": _player.position.x})
		await _setup(kind, -22.0)
		_move(Vector2.LEFT, 1.0)
		var minimum_x := _player.position.x
		var hit_rock := false
		for tick in 35:
			await _ticks(1)
			minimum_x = minf(minimum_x, _player.position.x)
			for contact in _player.get_slide_collision_count():
				if absf(_player.get_slide_collision(contact).get_normal().x) > 0.8:
					hit_rock = true
		_check(hit_rock and minimum_x > -22.9, "low source shelf physically blocks hero kind=%d" % kind, {"minimum_x": minimum_x, "wall_contact": hit_rock})
		await _setup(kind, -28.0, 1.1)
		# Leave the player ashore while the actual float traverses the source.
		_place_player(Vector3(0, 0.05, 4.5))
		var collision_free := true
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _float.get_child(0).shape
		query.collision_mask = 1
		query.exclude = [_float.get_rid(), _player.get_rid()]
		for tick in 420:
			await _ticks(1)
			query.transform = _float.global_transform
			collision_free = collision_free and _level.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
		_check(collision_free and _float.position.x > -21.0, "float clears common source without solid intersection kind=%d" % kind, {"x": _float.position.x})


func _lifecycle() -> void:
	for kind in 2:
		# Ordinary open water uses the same delayed return before and after checkpoint.
		for checkpoint in [Vector3(0, 0.05, 4.5), Vector3(1, 0.05, -24)]:
			await _setup(kind)
			_player.set_checkpoint(checkpoint)
			var respawns_before := _respawns
			var result := await _depart(Vector2.LEFT, 1.0)
			_release()
			await _ticks(90)
			_check(result.left and _respawns == respawns_before + 1 and _player.position.distance_to(checkpoint) < 0.15, "open water returns to active dock kind=%d checkpoint=%s" % [kind, checkpoint], {"player": str(_player.position)})
		await _setup(kind, 22.6, 1.1)
		var falls_before := _falls.size()
		var reset_before := _respawns
		var checkpoint := Vector3(1.0, 0.05, -24.0)
		_player.set_checkpoint(checkpoint)
		var saw_fall := false
		var hidden_before_recycle := false
		var recycled := false
		var lowest := 0.0
		var previous_x := _float.position.x
		for tick in 480:
			await _ticks(1)
			lowest = minf(lowest, _float.position.y)
			saw_fall = saw_fall or (_float.position.x > 23.1 and _float.position.y < -0.5)
			hidden_before_recycle = hidden_before_recycle or not _float.visible
			if _float.position.x < previous_x - 40.0:
				recycled = true
				break
			previous_x = _float.position.x
		_check(saw_fall and hidden_before_recycle and recycled and lowest < -14.0, "physical fall precedes hidden recycling kind=%d" % kind, {"lowest_y": lowest, "recycle_x": _float.position.x})
		_check(_falls.size() > falls_before and _respawns > reset_before and _player.position.distance_to(checkpoint) < 0.15, "rider falls and returns to checkpoint kind=%d" % kind, {"last_fall": str(_falls.back()) if not _falls.is_empty() else "none", "player": str(_player.position)})
		if _falls.size() > falls_before:
			_check(_falls.back().y < -5.0 and _falls.back().x > 22.0, "death after physical drop kind=%d" % kind, {"death_position": str(_falls.back())})
		_player.set_checkpoint(Vector3(0, 0.05, 4.5))


func _full_lifecycle() -> void:
	for kind in 2:
		await _setup(kind, -26.0, 1.1)
		_place_player(Vector3(0, 0.05, 4.5))
		var local_hull := AABB()
		var first := true
		for child in _float.get_children():
			if child is MeshInstance3D:
				var bounds: AABB = child.transform * child.get_aabb()
				local_hull = bounds if first else local_hull.merge(bounds)
				first = false
		var previous_x := _float.position.x
		var reset_ticks: Array[int] = []
		var hidden_only_below_pool := true
		var whole_hull_under_roof := true
		var visible_in_open_water := true
		for tick in 9400:
			await _ticks(1)
			var world_hull: AABB = _float.global_transform * local_hull
			var recycled := _float.position.x < previous_x - 40.0
			if recycled:
				reset_ticks.append(tick)
				whole_hull_under_roof = whole_hull_under_roof and world_hull.end.x < -23.0 and world_hull.position.x > -35.0 and world_hull.end.y < 0.85
			elif not _float.visible:
				hidden_only_below_pool = hidden_only_below_pool and world_hull.end.y < -10.15
			if _float.position.x > -21.0 and _float.position.x < 23.0:
				visible_in_open_water = visible_in_open_water and _float.visible
			previous_x = _float.position.x
			if reset_ticks.size() == 3:
				break
		var periods: Array[int] = []
		if reset_ticks.size() == 3:
			periods = [reset_ticks[1] - reset_ticks[0], reset_ticks[2] - reset_ticks[1]]
		var timing_ok := periods.size() == 2
		for ticks in periods:
			timing_ok = timing_ok and absf(ticks - 56.0 / 1.1 * 60.0) <= 1.0
		_check(timing_ok, "two complete unaccelerated lifecycle periods kind=%d" % kind, {"speed": 1.1, "period_ticks": periods, "reset_ticks": reset_ticks})
		_check(whole_hull_under_roof, "whole visible hull resets beneath source roof kind=%d" % kind, {"local_hull": str(local_hull)})
		_check(hidden_only_below_pool and visible_in_open_water, "hull hides only below lower pool or beneath source roof kind=%d" % kind)


func _channel_sweeps() -> void:
	# Use the full visible hull, including the submerged barrels, not the inset collider.
	var hull := BoxShape3D.new()
	hull.size = Vector3(3.0, 1.8, 1.8)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull
	query.collision_mask = 1
	var excluded: Array[RID] = [_player.get_rid()]
	for platform in _floats:
		excluded.append(platform.get_rid())
	query.exclude = excluded
	for row in _level.PLATFORM_POSITIONS:
		var clear := true
		var obstruction := ""
		for index in 276:
			query.transform = Transform3D(Basis.IDENTITY, Vector3(-32.0 + index * 0.2, -0.65, row.z))
			var contacts := _level.get_world_3d().direct_space_state.intersect_shape(query)
			if not contacts.is_empty():
				clear = false
				obstruction = str(contacts[0].collider.get_path())
				break
		_check(clear, "full visible hull has clear X sweep z=%s" % row.z, {"obstruction": obstruction, "samples": 276, "full_hull": str(hull.size)})


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	_player.camera = null
	_floats = get_nodes_in_group("floating_platforms")
	_player.jumped.connect(func(): _jumps += 1)
	_player.fell_into_water.connect(func(at: Vector3): _falls.append(at))
	_player.respawned.connect(func(): _respawns += 1)
	await _ticks(15)
	await _edges()
	await _coyote()
	await _river_limits()
	await _lifecycle()
	await _full_lifecycle()
	await _channel_sweeps()
	_release()
	_jump(false)
	DirAccess.make_dir_recursive_absolute("res://artifacts/river-movement/round-1")
	var report := FileAccess.open("res://artifacts/river-movement/round-1/behavior.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": _checks, "failures": _failures, "physics_fps": Engine.physics_ticks_per_second, "limitations": "Synthetic Input and real physics; no human/controller/visual acceptance."}, "\t"))
	report.close()
	print("RIVER BEHAVIOR: ", _checks.size(), " checks, ", _failures.size(), " failures")
	# Fixed-fps tests can finish before the audio thread has consumed stop commands.
	await _level.get_node("Feedback").prepare_shutdown()
	_floats.clear()
	_float = null
	_player = null
	_level = null
	current_scene.queue_free()
	await _ticks(2)
	quit(0 if _failures.is_empty() else 1)
