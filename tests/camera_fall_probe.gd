extends "res://tests/river_capture.gd"
## Independent projection probe at the original waterfall capture moments.
## No rendered images: framing does not prove visibility through water/geometry.
var _probe_rows: Array = []

func _picture(label: String) -> void:
	if not label.begins_with("fall-") or _player.global_position.x <= 22 or _player.global_position.y >= 0:
		return
	var camera: Camera3D = _level.get_node("Camera")
	var back := camera.global_basis.z
	var yaw := rad_to_deg(atan2(back.x, back.z))
	var landmarks: Array = []
	var any_outside := false
	for height in [0.05, 0.7, 1.4]:
		var point: Vector3 = _player.global_position + Vector3.UP * height
		var screen := camera.unproject_position(point)
		var behind := camera.is_position_behind(point)
		var outside := behind or not root.get_visible_rect().has_point(screen)
		any_outside = any_outside or outside
		landmarks.append({"height": height, "screen": [screen.x, screen.y], "behind": behind, "outside": outside})
	_probe_rows.append({"capture": label, "camera": _vector(camera.global_position),
		"player": _vector(_player.global_position), "yaw_deg": yaw,
		"pitch_deg": rad_to_deg(camera.global_basis.get_euler().x),
		"visual_visible": _player.visual.visible, "landmarks": landmarks})
	_check(absf(yaw) <= 1.0, "Waterfall yaw remains stable at " + label)
	_check(not any_outside, "Waterfall head/body/feet remain framed at " + label)
	_write_report()

func _finish() -> void:
	_check(_probe_rows.size() >= 2, "Waterfall probe captured actual falling positions")
	_write_report()
	await super._finish()

func _write_report() -> void:
	var report := FileAccess.open(directory.path_join("camera-fall-probe.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"frames": _probe_rows, "failures": _failures,
		"viewport": [root.size.x, root.size.y], "engine_reported_fps": Engine.get_frames_per_second(),
		"command_arguments": OS.get_cmdline_args(),
		"note": "Samples at river_capture fall PNG moments, only player.x>22 and player.y<0. Headless projection cannot validate occlusion or visual comfort."}, "  "))

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
