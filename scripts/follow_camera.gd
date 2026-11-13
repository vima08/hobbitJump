extends Camera3D

@export var target: Node3D
@export var offset: Vector3 = Vector3(0, 2.6, 6.6)
@export var follow_speed: float = 7.0
@export var obstruction_return_speed := 4.0
@export var camera_radius := 0.22
var _focus := Vector3.ZERO
var _arm_length := 10.0
var _raised_view := 0.0
var _ground_y := 0.0
var _camera_shape := SphereShape3D.new()
var _anticipation_shape := SphereShape3D.new()
var _soft_materials: Array[ShaderMaterial] = []
var _soft_bodies: Array[RID] = []
var _soft_initialized := false


func _ready() -> void:
	_camera_shape.radius = camera_radius
	_anticipation_shape.radius = camera_radius + 1.2
	snap_to_target()


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	if not _soft_initialized:
		for visual in get_tree().get_nodes_in_group("camera_soft_visuals"):
			_soft_materials.append(visual.material_override)
		for body in get_tree().get_nodes_in_group("camera_soft_bodies"):
			_soft_bodies.append(body.get_rid())
		_soft_initialized = true
	# Ground framing keeps jump destinations in view; the gorge follows the fall.
	var fall_y := minf(0.0, target.global_position.y) if target.global_position.x > 22.0 else 0.0
	if target is CharacterBody3D and target.is_on_floor() and target.global_position.x <= 22.0:
		_ground_y = target.global_position.y
	var fall_blend := clampf(-fall_y * 2.0, 0.0, 1.0)
	var ground_height := fall_y if target.global_position.x > 22.0 else _ground_y
	var desired := Vector3(target.global_position.x, 0.65 + ground_height, target.global_position.z - 2.0 * (1.0 - fall_blend))
	var tracking_speed := lerpf(follow_speed, 18.0, fall_blend)
	_focus = _focus.lerp(desired, 1.0 - exp(-tracking_speed * delta))
	# Obstruction correction must never change yaw or rotate the movement axes.
	_focus.x = target.global_position.x
	var pivot := Vector3(_focus.x, _focus.y, target.global_position.z)
	# Follow the fall from outside the curved water curtain, keeping yaw fixed.
	# At depth, a camera directly above the hero can be inside that visual mesh.
	pivot.x += 1.6 * fall_blend
	var end := _focus + offset
	end.x = pivot.x
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _camera_shape
	query.collision_mask = 1
	query.margin = 0.015
	if target is CollisionObject3D:
		query.exclude = [target.get_rid()]
	query.exclude += _soft_bodies
	query.transform = Transform3D(Basis.IDENTITY, pivot)
	var space := get_world_3d().direct_space_state
	# cast_motion ignores initial overlaps. During a jump use the real body pivot
	# if the ground-framing pivot is still inside a rock the hero has cleared.
	if not space.intersect_shape(query, 1).is_empty():
		pivot.y = target.global_position.y + 0.65
		query.transform.origin = pivot
	var arm := end - pivot
	query.motion = arm
	var fractions := space.cast_motion(query)
	var normal_clearance := arm.length() * fractions[0]
	# Anticipate tall terrain, ignoring low decks that cannot obstruct the lens.
	query.shape = _anticipation_shape
	query.collision_mask = 4
	var anticipated := space.cast_motion(query)
	query.shape = _camera_shape
	query.collision_mask = 1
	var anticipated_clearance := minf(normal_clearance, arm.length() * anticipated[0])
	anticipated_clearance = lerpf(anticipated_clearance, normal_clearance, fall_blend)
	# Tall stone can leave no room for a conventional shoulder view.
	# Rise above the hero without changing yaw; tree occluders use cutouts.
	var raise_needed := 1.0 - smoothstep(1.8, 3.0, anticipated_clearance)
	if raise_needed > _raised_view:
		_raised_view = move_toward(_raised_view, raise_needed, delta * 4.0)
	else:
		_raised_view = lerpf(_raised_view, raise_needed, 1.0 - exp(-obstruction_return_speed * delta))
	# The close overhead view follows jump height too: ground framing alone
	# would put a jumping hero's head above the lens beside the stone arch.
	var jump_lift := maxf(0.0, target.global_position.y - _ground_y) * smoothstep(0.0, 0.2, _raised_view)
	if jump_lift > 0.0:
		pivot.y = maxf(pivot.y, 0.65 + _ground_y + jump_lift)
	query.transform.origin = pivot
	arm = arm.lerp(Vector3(0, 2.0, 0.2), _raised_view)
	query.motion = arm
	fractions = space.cast_motion(query)
	var safe_length := maxf(0.0, arm.length() * fractions[0] - 0.035)
	if safe_length < 1.5:
		# Safety fallback for a teleport/reset next to an obstacle: never interpolate
		# through stone just to preserve smoothness.
		_raised_view = 1.0
		arm = Vector3(0, 2.0, 0.2)
		query.motion = arm
		fractions = space.cast_motion(query)
		safe_length = maxf(0.0, arm.length() * fractions[0] - 0.035)
	if safe_length < _arm_length:
		_arm_length = safe_length
	else:
		_arm_length = lerpf(_arm_length, safe_length, 1.0 - exp(-obstruction_return_speed * delta))
	var fraction := _arm_length / maxf(arm.length(), 0.01)
	global_position = pivot + arm * fraction
	# A compressed camera frames the hero instead of staring two metres beyond
	# them. The camera remains behind the pivot, with no arbitrary normal push.
	var look_point := _focus.lerp(pivot, maxf(_raised_view, 1.0 - fraction))
	look_point.x = global_position.x
	if global_position.distance_squared_to(look_point) > 0.0001:
		look_at(look_point)
	_update_cutouts()


func _update_cutouts() -> void:
	for material in _soft_materials:
		material.set_shader_parameter("camera_cutout_start", global_position)
		material.set_shader_parameter("camera_cutout_end", target.global_position + Vector3.UP * 0.7)
		material.set_shader_parameter("camera_cutout_radius", 0.9)


func snap_to_target() -> void:
	if not is_instance_valid(target):
		return
	_ground_y = maxf(0.0, target.global_position.y)
	_focus = Vector3(target.global_position.x, 0.65 + _ground_y, target.global_position.z - 2.0)
	_arm_length = offset.length()
	_raised_view = 0.0
	global_position = _focus + offset
	look_at(_focus)
	_update_cutouts()
