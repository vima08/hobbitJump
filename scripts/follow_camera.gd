extends Camera3D

@export var target: Node3D
@export var offset: Vector3 = Vector3(0, 10, 12)
@export var follow_speed: float = 7.0
var _focus := Vector3.ZERO


func _ready() -> void:
	snap_to_target()


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Follow the route on the ground; jumping must not pull the landing out of frame.
	var desired := Vector3(target.global_position.x, 0.0, target.global_position.z - 2.0)
	_focus = _focus.lerp(desired, 1.0 - exp(-follow_speed * delta))
	global_position = _focus + offset
	look_at(_focus)


func snap_to_target() -> void:
	if not is_instance_valid(target):
		return
	_focus = Vector3(target.global_position.x, 0.0, target.global_position.z - 2.0)
	global_position = _focus + offset
	look_at(_focus)
