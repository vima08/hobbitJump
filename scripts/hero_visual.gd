extends Node3D
## Support-local foot anchors and a small two-bone rig over the accepted mesh.
const MODEL: PackedScene = preload("res://assets/characters/hobbit.glb")
@export var walk_step_rate := 3.2
@export var run_step_rate := 4.2
@export var contact_span := 0.28
@export var foot_lift := 0.045
var _phase := 0.0
var _model: Node3D
var _torso: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _feet: Array[Dictionary] = []
var _support: Node3D
var _initialized := false
var _was_grounded := false
var _landing := 0.0
var _gait_rate := 1.5
var _run_blend := 0.0
var _pelvis_lower := 0.0
var _motion_blend := 0.0
var _travel_direction := Vector3.ZERO
var _last_position := Vector3.ZERO

func _ready() -> void:
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	_enable_vertex_colors(_model)
	_torso = _model.find_child("Torso", true, false)
	_left_arm = _model.find_child("ArmLeft", true, false)
	_right_arm = _model.find_child("ArmRight", true, false)
	for suffix in ["Left", "Right"]:
		var leg := _model.find_child("Leg" + suffix, true, false) as Node3D
		if suffix == "Left":
			_left_leg = leg
		else:
			_right_leg = leg
		var surface := leg.get_child(0) as MeshInstance3D
		var skeleton := Skeleton3D.new()
		skeleton.name = "FootRig"
		leg.add_child(skeleton)
		var rest := [Vector3.ZERO, Vector3(0, -0.18, 0), Vector3(0, -0.14, 0)]
		var skin := Skin.new()
		var combined := Transform3D.IDENTITY
		for index in 3:
			skeleton.add_bone(["Upper", "Lower", "Foot"][index])
			skeleton.set_bone_parent(index, index - 1)
			var transform := Transform3D(Basis.IDENTITY, rest[index])
			skeleton.set_bone_rest(index, transform)
			skeleton.reset_bone_pose(index)
			combined *= transform
			skin.add_bind(index, combined.affine_inverse())
		var rigged := ArrayMesh.new()
		for index in surface.mesh.get_surface_count():
			var arrays := surface.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			for vertex in vertices:
				var knee := smoothstep(-0.145, -0.215, vertex.y)
				var ankle := smoothstep(-0.265, -0.305, vertex.y)
				bones.append_array(PackedInt32Array([0, 1, 2, 0]))
				weights.append_array(PackedFloat32Array([1.0 - knee, knee * (1.0 - ankle), knee * ankle, 0.0]))
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			rigged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			rigged.surface_set_material(index, surface.mesh.surface_get_material(index))
		surface.mesh = rigged
		surface.skeleton = surface.get_path_to(skeleton)
		surface.skin = skin
		_feet.append({"leg": leg, "rig": skeleton, "anchor": Vector3.ZERO,
			"from": Vector3.ZERO, "to": Vector3.ZERO, "target": Vector3.ZERO, "stance": true, "orientation": Basis.IDENTITY, "plant_id": 0})
	var fill := OmniLight3D.new()
	fill.name = "FaceFill"
	fill.position = Vector3(0.15, 1.15, 0.8)
	fill.light_color = Color("e4d5bd")
	fill.light_energy = 0.25
	fill.omni_range = 2.0
	fill.light_cull_mask = 2
	add_child(fill)

func _enable_vertex_colors(node: Node) -> void:
	if node is MeshInstance3D:
		node.layers = 2
		for index in node.mesh.get_surface_count():
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/hero_cloth.gdshader")
			material.set_shader_parameter("hero_atlas", preload("res://assets/art/hero-atlas-v1.png"))
			node.set_surface_override_material(index, material)
	for child in node.get_children():
		_enable_vertex_colors(child)

func _anchor_from_world(point: Vector3) -> Vector3:
	return _support.to_local(point) if is_instance_valid(_support) else point

func _anchor_to_world(point: Vector3) -> Vector3:
	return _support.to_global(point) if is_instance_valid(_support) else point

func _neutral_sole(index: int) -> Vector3:
	return _surface_point(to_global(Vector3(-0.145 if index == 0 else 0.145, 0, 0.04)))

func _surface_point(point: Vector3) -> Vector3:
	var player := get_parent() as CharacterBody3D
	if not player.is_on_floor():
		return point
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.45, point - Vector3.UP * 0.4, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (not is_instance_valid(_support) or hit.collider == _support):
		return hit.position
	# A capsule may be caught on a deck corner while its centre is outside
	# the inset collider. Put the foot back onto a real ray-tested top face.
	if is_instance_valid(_support):
		for child in _support.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				var local: Vector3 = child.to_local(point)
				var half: Vector3 = child.shape.size * 0.5
				local.x = clampf(local.x, -half.x + 0.01, half.x - 0.01)
				local.z = clampf(local.z, -half.z + 0.01, half.z - 0.01)
				local.y = half.y
				var candidate: Vector3 = child.to_global(local)
				query.from = candidate + Vector3.UP * 0.12
				query.to = candidate - Vector3.UP * 0.12
				hit = get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and hit.collider == _support:
					return hit.position
	return point

func _reset_contacts() -> void:
	for index in 2:
		var foot := _feet[index]
		foot.anchor = _anchor_from_world(_neutral_sole(index))
		foot.orientation = _support.global_basis.inverse() * global_basis if is_instance_valid(_support) else global_basis
		foot.stance = true
		foot["fresh"] = true
		foot["progress"] = 0.0
		foot["preview"] = _anchor_to_world(foot.anchor) - global_position
	_phase = 0.0
	_initialized = true

func _physics_process(delta: float) -> void:
	var player := get_parent() as CharacterBody3D
	var relative: Vector3 = player.get("locomotion_velocity")
	var support := player.get("support_body") as Node3D
	var speed := Vector2(relative.x, relative.z).length()
	var grounded := player.is_on_floor()
	if support != _support or not _initialized or global_position.distance_to(_last_position) > 1.0 or (grounded and not _was_grounded):
		_support = support
		_reset_contacts()
	_last_position = global_position
	if grounded and not _was_grounded:
		_landing = 1.0
	_was_grounded = grounded
	_landing = move_toward(_landing, 0, delta * 5.5)
	var moving := grounded and speed > 0.03
	_run_blend = lerpf(_run_blend, smoothstep(1.2, 3.2, speed), 1.0 - exp(-12.0 * delta))
	_motion_blend = move_toward(_motion_blend, clampf(speed / 1.5, 0, 1) if grounded else 0.0, delta * 7.0)
	var walk_rate := lerpf(1.3, walk_step_rate, clampf(speed / 1.5, 0, 1))
	_gait_rate = lerpf(_gait_rate, lerpf(walk_rate, run_step_rate, _run_blend), 1.0 - exp(-12.0 * delta))
	var cycle_time := 2.0 / _gait_rate
	# Short planted contacts and longer flight preserve reach at full speed.
	var duty := minf(0.54, contact_span / maxf(speed, 0.03) / cycle_time)
	var lead := minf(contact_span * 0.5, speed * cycle_time * duty * 0.5)
	var direction := Vector3(relative.x, 0, relative.z).normalized()
	_travel_direction = _travel_direction.lerp(direction, 1.0 - exp(-10.0 * delta))
	var old_phase := _phase
	if moving:
		_phase += delta * _gait_rate * PI
	var settling := -1
	if not moving:
		for index in 2:
			if not _feet[index].stance:
				settling = index
		if settling < 0:
			for index in 2:
				if _anchor_to_world(_feet[index].anchor).distance_to(_neutral_sole(index)) > 0.045:
					settling = index
					break
	var hop := sin(_phase * 2.0 - PI * 0.5) * 0.016 * _run_blend * _motion_blend
	var crouch := 0.025 * _landing
	for foot in _feet:
		foot.leg.position.y = 0.43 + hop
	_torso.position.y = hop - crouch
	if grounded:
		for index in 2:
			var foot := _feet[index]
			var neutral_offset := to_global(Vector3(-0.145 if index == 0 else 0.145, 0, 0.04)) - global_position
			var placement := neutral_offset + _travel_direction * lead if moving else neutral_offset
			foot["preview"] = (foot.preview as Vector3).lerp(placement, 1.0 - exp(-8.0 * delta))
			var phase := fposmod(_phase / TAU + index * 0.5, 1.0)
			var previous := fposmod(old_phase / TAU + index * 0.5, 1.0)
			if moving and phase < previous:
				foot.anchor = _anchor_from_world(_surface_point(global_position + foot.preview))
				foot.orientation = _support.global_basis.inverse() * global_basis if is_instance_valid(_support) else global_basis
				foot.stance = true
				foot.plant_id += 1
				foot["fresh"] = false
			var swing_now := moving and phase >= duty
			if moving and foot.stance:
				var contact_local := to_local(_anchor_to_world(foot.anchor))
				var neutral := Vector3(-0.145 if index == 0 else 0.145, 0, 0.04)
				var reach := Vector2(contact_local.x - neutral.x, contact_local.z - neutral.z).length()
				swing_now = swing_now or reach > 0.15 or (foot.get("fresh", false) and phase >= duty * 0.5)
			if not moving:
				swing_now = index == settling
			if swing_now and foot.stance:
				foot.from = _anchor_to_world(foot.anchor) - global_position
				foot.stance = false
				foot["progress"] = 0.0
				foot["release_phase"] = phase
			if not foot.stance:
				var progress: float = foot.get("progress", 0.0)
				var release_phase: float = foot.get("release_phase", duty)
				progress = maxf(progress, clampf((phase - release_phase) / maxf(0.01, 1.0 - release_phase), 0, 1)) if moving else minf(1.0, progress + delta / 0.17)
				foot["progress"] = progress
				var destination: Vector3 = foot.preview
				var offset: Vector3 = foot.from.lerp(destination, smoothstep(0, 1, progress))
				var lift := lerpf(foot_lift, 0.15, _run_blend)
				foot.target = _surface_point(global_position + offset) + Vector3.UP * sin(progress * PI) * lift
				var recovery := global_basis * Basis(Vector3.RIGHT, sin(progress * PI) * 0.30 * _run_blend)
				foot.orientation = _support.global_basis.inverse() * recovery if is_instance_valid(_support) else recovery
				if not moving and progress >= 1.0:
					foot.anchor = _anchor_from_world(foot.target)
					foot.stance = true
					foot.plant_id += 1
			if foot.stance:
				foot.target = _anchor_to_world(foot.anchor)
		# Reach correction never advances the animation clock.
		for foot in _feet:
			var planted: Basis = _support.global_basis * foot.orientation if is_instance_valid(_support) else foot.orientation
			var offset: Vector3 = foot.leg.global_basis.inverse() * planted * Vector3(0, -0.11, 0.04)
			var ankle: Vector3 = foot.leg.to_local(foot.target) - offset
			var horizontal := Vector2(ankle.x, ankle.z).length()
			var height := sqrt(maxf(0.001, 0.319 * 0.319 - horizontal * horizontal))
			crouch = maxf(crouch, -ankle.y - height + 0.006)
		crouch = clampf(crouch, 0, 0.12)
		_pelvis_lower = lerpf(_pelvis_lower, crouch, 1.0 - exp(-18.0 * delta))
		_torso.position.y = hop - _pelvis_lower
		for foot in _feet:
			foot.leg.position.y = 0.43 + hop - _pelvis_lower
			_pose_leg(foot, foot.target)
	else:
		_initialized = false
		var rise := clampf(player.velocity.y / 7.0, 0, 1)
		for index in 2:
			var foot := _feet[index]
			foot.stance = false
			_pose_leg(foot, _neutral_sole(index) + global_basis * Vector3(0, 0.06 + rise * 0.06, rise * (0.12 if index == 0 else -0.06)))
	var stride := sin(_phase) * lerpf(0.28, 0.52, _run_blend) * _motion_blend
	var air_pose := -0.75 if not grounded else -_landing * 0.25
	_left_arm.rotation.x = -stride + air_pose
	_right_arm.rotation.x = stride + air_pose
	_left_arm.rotation.z = -0.3 if not grounded else 0.0
	_right_arm.rotation.z = 0.3 if not grounded else 0.0
	# The model faces +Z: positive local X pitches the upper body forward.
	_torso.rotation.x = _motion_blend * lerpf(0.04, 0.12, _run_blend) + _landing * 0.08
	_torso.rotation.z = sin(_phase) * 0.016 * _motion_blend


func _pose_leg(foot: Dictionary, sole: Vector3) -> void:
	var leg: Node3D = foot.leg
	var rig: Skeleton3D = foot.rig
	# Foot bone is at ankle; the sole marker is 11 cm below and 4 cm forward.
	var planted_basis: Basis = _support.global_basis * foot.orientation if is_instance_valid(_support) else foot.orientation
	var foot_rotation := (leg.global_basis.inverse() * planted_basis).get_rotation_quaternion()
	var target := leg.to_local(sole) - foot_rotation * Vector3(0, -0.11, 0.04)
	var reach := clampf(target.length(), 0.025, 0.3195)
	var axis := target.normalized()
	var along := (0.18 * 0.18 - 0.14 * 0.14 + reach * reach) / (2.0 * reach)
	var bend := Vector3.FORWARD * -1.0
	bend = (bend - axis * bend.dot(axis)).normalized()
	var knee := axis * along + bend * sqrt(maxf(0.0, 0.18 * 0.18 - along * along))
	var upper := Quaternion(Vector3.DOWN, knee.normalized())
	var lower := Quaternion(Vector3.DOWN, (axis * reach - knee).normalized())
	rig.set_bone_pose_rotation(0, upper)
	rig.set_bone_pose_rotation(1, upper.inverse() * lower)
	rig.set_bone_pose_rotation(2, lower.inverse() * foot_rotation)
	rig.force_update_all_bone_transforms()

func gait_debug() -> Dictionary:
	var result := {"phase": _phase, "step_rate": _gait_rate, "run_blend": _run_blend, "pelvis_y": _torso.position.y, "feet": []}
	for foot in _feet:
		var rig: Skeleton3D = foot.rig
		var actual: Vector3 = rig.to_global(rig.get_bone_global_pose(2) * Vector3(0, -0.11, 0.04))
		result.feet.append({"sole": actual, "target": foot.target, "stance": foot.stance, "plant_id": foot.plant_id,
			"contact_error": actual.distance_to(foot.target) if foot.stance else 0.0})
	return result
