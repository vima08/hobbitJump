extends Node3D
## Visual animation only: the character collision and platform motion stay separate.

const MODEL: PackedScene = preload("res://assets/characters/hobbit.glb")
var _phase := 0.0
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _torso: Node3D
var _model: Node3D
var _was_grounded := true
var _landing := 0.0


func _ready() -> void:
	var model := MODEL.instantiate() as Node3D
	_model = model
	add_child(model)
	_enable_vertex_colors(model)
	_left_leg = model.find_child("LegLeft", true, false)
	_right_leg = model.find_child("LegRight", true, false)
	_left_arm = model.find_child("ArmLeft", true, false)
	_right_arm = model.find_child("ArmRight", true, false)
	_torso = model.find_child("Torso", true, false)
	# A soft character fill keeps facial modelling legible under the forest canopy.
	var fill := OmniLight3D.new()
	fill.name = "FaceFill"
	fill.position = Vector3(0.15, 1.15, 0.8)
	fill.light_color = Color("e4d5bd")
	fill.light_energy = 0.25
	fill.omni_range = 2.0
	fill.light_cull_mask = 2
	add_child(fill)


func _enable_vertex_colors(node: Node) -> void:
	# glTF COLOR_0 is present, but the importer may leave this material flag off.
	if node is MeshInstance3D:
		node.layers = 2
		for index in node.mesh.get_surface_count():
			var imported := node.mesh.surface_get_material(index) as StandardMaterial3D
			if imported:
				var material := ShaderMaterial.new()
				material.shader = preload("res://shaders/hero_cloth.gdshader")
				material.set_shader_parameter("hero_atlas", preload("res://assets/art/hero-atlas-v1.png"))
				node.set_surface_override_material(index, material)
	for child in node.get_children():
		_enable_vertex_colors(child)


func _physics_process(delta: float) -> void:
	var player := get_parent() as CharacterBody3D
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var grounded := player.is_on_floor()
	var walking := clampf(speed / player.move_speed, 0, 1) if grounded else 0.0
	if grounded and not _was_grounded:
		_landing = 1.0
	_was_grounded = grounded
	_landing = move_toward(_landing, 0.0, delta * 5.5)
	_phase += speed * delta * 2.9
	var stride := sin(_phase) * 0.55 * walking
	var blend := 1.0 - exp(-18.0 * delta)
	var rising := clampf(player.velocity.y / 7.0, 0.0, 1.0) if not grounded else 0.0
	var falling := clampf(-player.velocity.y / 7.0, 0.0, 1.0) if not grounded else 0.0
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, stride + rising * 0.48 - falling * 0.12, blend)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -stride + rising * 0.26 - falling * 0.12, blend)
	var air_pose := -0.65 - rising * 0.55 + falling * 0.28 if not grounded else -_landing * 0.28
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -stride + air_pose, blend)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, stride + air_pose, blend)
	var spread := 0.0 if grounded else 0.32 + falling * 0.12
	_left_arm.rotation.z = lerpf(_left_arm.rotation.z, -spread, blend)
	_right_arm.rotation.z = lerpf(_right_arm.rotation.z, spread, blend)
	# Small whole-body compression keeps all six original pivots connected.
	_model.scale = Vector3(1.0 + _landing * 0.035, 1.0 - _landing * 0.09, 1.0 + _landing * 0.035)
	_torso.position.y = absf(sin(_phase)) * 0.012 * walking
	_torso.rotation.x = lerpf(_torso.rotation.x, -rising * 0.07 + falling * 0.035 + _landing * 0.10, blend)
	_torso.rotation.z = sin(_phase) * 0.022 * walking
