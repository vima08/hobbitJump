extends Node3D

const WOOD := Color("855539")
const GRASS := Color("6f9560")
const FloatingPlatform = preload("res://scripts/floating_platform.gd")
const PLATFORM_POSITIONS: Array[Vector3] = [
	Vector3(0, -0.3, 0.5), Vector3(1.0, -0.3, -2.5),
	Vector3(-0.7, -0.3, -5.5), Vector3(0.8, -0.3, -8.5),
	Vector3(0, -0.3, -11.5),
]
var _water_streaks: Array[MeshInstance3D] = []


func _physics_process(delta: float) -> void:
	for streak in _water_streaks:
		streak.position.x = wrapf(streak.position.x + 0.75 * delta, -24.5, 24.5)


func _ready() -> void:
	_build_environment()
	_build_course()
	_build_hero()
	$Player.respawned.connect($Camera.snap_to_target)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
	instance.position = at
	return instance


func _platform(label: String, size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	add_child(body)
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_box(body, size, Vector3.ZERO, color)
	return body


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b7d9db")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5e5e1")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	_box(self, Vector3(65, 0.15, 45), Vector3(0, -0.8, -5), Color("378f9d"))
	# The river flows left to right; both banks and streaks follow that direction.
	for index in range(26):
		var x := -24.0 + fmod(float(index) * 4.7, 48.0)
		var z := -16.0 + fmod(float(index) * 7.1, 24.0)
		_water_streaks.append(_box(self, Vector3(1.8, 0.015, 0.07), Vector3(x, -0.71, z), Color("62acb2")))
	_platform("StartBank", Vector3(65, 2, 9), Vector3(0, -1, 12), GRASS)
	_platform("EndBank", Vector3(65, 2, 9), Vector3(0, -1, -21), GRASS)
	for side in [-1, 1]:
		for index in range(8):
			var at := Vector3(-21.0 + index * 6.0, 0, 11.0 if side == 1 else -20.0)
			_box(self, Vector3(0.45, 2.4, 0.45), at + Vector3(0, 1.2, 0), WOOD)
			_box(self, Vector3(2.5, 2.8, 2.5), at + Vector3(0, 3.0, 0), Color("51734e"))


func _build_course() -> void:
	_platform("StartDock", Vector3(11, 0.6, 5.0), Vector3(0, -0.3, 5), WOOD)
	for index in range(PLATFORM_POSITIONS.size()):
		for copy in range(-3, 4):
			var platform := AnimatableBody3D.new()
			platform.set_script(FloatingPlatform)
			platform.name = "Float%d_%d" % [index, copy + 3]
			platform.kind = index % 2
			platform.position = PLATFORM_POSITIONS[index] + Vector3(copy * 7.0, 0, 0)
			add_child(platform)
	_platform("EndDock", Vector3(11, 0.6, 4), Vector3(0, -0.3, -15), WOOD)
	_box(self, Vector3(0.12, 2.3, 0.12), Vector3(-1.8, 1.15, -15), Color("d9c7a1"))
	_box(self, Vector3(0.9, 0.55, 0.06), Vector3(-1.3, 2.0, -15), Color("d4b35c"))
	var goal := Area3D.new()
	goal.name = "PracticeGoal"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(11, 2, 3)
	collision.shape = shape
	goal.add_child(collision)
	add_child(goal)
	goal.position = Vector3(0, 1, -15)
	goal.body_entered.connect(func(body: Node3D) -> void:
		if body == $Player:
			$HUD.show_goal()
	)


func _build_hero() -> void:
	var visual: Node3D = $Player/Visual
	$Player/Visual/Body.material_override = _material(Color("718047"))
	_box(visual, Vector3(0.43, 0.28, 0.4), Vector3(0, 1.0, 0), Color("d5ad7e"))
	_box(visual, Vector3(0.48, 0.16, 0.46), Vector3(0, 1.18, -0.04), Color("58402c"))
	for side in [-1, 1]:
		_box(visual, Vector3(0.24, 0.13, 0.45), Vector3(float(side) * 0.17, 0.08, 0.12), Color("d5ad7e"))
		_box(visual, Vector3(0.06, 0.06, 0.035), Vector3(float(side) * 0.12, 1.04, 0.215), Color("342e29"))
