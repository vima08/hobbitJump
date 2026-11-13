extends "res://tests/gait_behavior.gd"
## Запись: --write-movie <path.avi> --fixed-fps 60; -- --legacy для baseline.
## Обычная и боковая камеры, без изменения физических параметров игрока.
var _side := false
var _label: Label

func _run() -> void:
	_directory = "res://artifacts/gait/capture-after"
	for argument in OS.get_cmdline_user_args():
		if argument == "--legacy":
			_legacy = true
			_directory = "res://artifacts/gait/capture-baseline"
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
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	_label = Label.new()
	_label.position = Vector2(24, 82)
	_label.add_theme_font_size_override("font_size", 22)
	overlay.add_child(_label)
	await _ticks(12)
	for side in [false, true]:
		_side = side
		_camera.set_process(not side)
		for strength in [0.15, 0.35, 1.0]:
			await _place(_level.get_node("CheckpointDock").position + Vector3(-7, 0.33, 0))
			_begin(("side" if side else "normal") + "_%.2f" % strength)
			_label.text = ("ДО" if _legacy else "ПОСЛЕ") + " · " + ("сбоку" if side else "обычная камера") + " · %.2f м/с → стоп" % (strength * 4.8)
			await _motion(Vector3.RIGHT, strength, 150)
			await _motion(Vector3.ZERO, 0, 36)
		await _place(_level.get_node("CheckpointDock").position + Vector3(-5, 0.33, 0))
		_begin(("side" if side else "normal") + "_turn")
		_label.text = ("ДО" if _legacy else "ПОСЛЕ") + " · разворот, разгон и торможение"
		await _motion(Vector3.RIGHT, 0.35, 45)
		await _motion(Vector3.LEFT, 0.35, 45)
		await _motion(Vector3.RIGHT, 1, 45)
		await _motion(Vector3.ZERO, 0, 36)
	_side = true
	_camera.set_process(false)
	for kind in 2:
		var carrier := _nearest_carrier(kind)
		await _place(carrier.global_position + Vector3(0, 0.5, 0))
		_begin("carrier_%d" % kind)
		_label.text = ("ДО" if _legacy else "ПОСЛЕ") + " · " + ("брёвна" if kind == 0 else "бочки") + " · покой / ходьба / прыжок"
		await _motion(Vector3.ZERO, 0, 90)
		await _motion(Vector3.RIGHT, 0.15, 32)
		await _motion(Vector3.LEFT, 0.15, 32)
		Input.action_press("jump")
		await _motion(Vector3.ZERO, 0, 1)
		Input.action_release("jump")
		await _motion(Vector3.ZERO, 0, 75)
	_release()
	var file := FileAccess.open(_directory + "/capture-telemetry.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"physics_hz": Engine.physics_ticks_per_second, "legacy": _legacy,
		"metrics": _metrics, "samples": _samples}, "  "))
	paused = true
	await _level.get_node("Feedback").prepare_shutdown()
	quit()

func _motion(direction: Vector3, strength: float, count: int) -> void:
	for tick in count:
		if _side:
			_camera.position = _player.position + Vector3(0, 1.0, 3.4)
			_camera.look_at(_player.position + Vector3(0, 0.48, 0))
			_camera.fov = 36
		else:
			_camera.fov = 56
		await super._motion(direction, strength, 1)
