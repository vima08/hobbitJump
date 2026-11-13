extends "res://tests/prototype_smoke.gd"
## Fixtures choose the episode; every recorded movement then uses real physics.
var directory := "res://artifacts/river-movement/round-1"

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--round="):
			directory = "res://artifacts/river-movement/round-" + argument.trim_prefix("--round=")
	DirAccess.make_dir_recursive_absolute(directory)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_level = current_scene
	_player = _level.get_node("Player")
	await _ticks(20)
	await _picture("start")
	var camera: Camera3D = _level.get_node("Camera")
	camera.set_process(false)
	camera.position = Vector3(12, 22, 18)
	camera.look_at(Vector3(-3, -1, -20))
	await _ticks(60)
	await _picture("river-overview")
	for kind in ([] if "--falls-only" in OS.get_cmdline_user_args() else [0, 1]):
		var raft := _nearest_float(kind, -23)
		raft.position.x = -24.8
		camera.position = Vector3(-16, 3, raft.position.z + 7)
		camera.look_at(Vector3(-23, 0, raft.position.z))
		for frame in range(120):
			await _ticks(1)
			if frame % 30 == 0:
				await _picture("inlet-%d-%03d" % [kind, frame])
	for kind in [0, 1]:
		var raft := _nearest_float(kind, 20)
		raft.position.x = 22.1
		_player.position = raft.position + Vector3(0, 0.45, 0)
		_player.velocity = Vector3.ZERO
		_player.support_body = null
		if kind == 1:
			_player.set_checkpoint(_level.CHECKPOINT_POSITION)
		camera.set_process(true)
		camera.snap_to_target()
		for frame in range(180):
			await _ticks(1)
			if frame % 20 == 0:
				await _picture("fall-%d-%03d" % [kind, frame])
		_check(_player.global_position.distance_to(_player.spawn_position) < 0.3, "Recorded waterfall returns to current checkpoint, kind %d" % kind)
	await _finish()

func _picture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
