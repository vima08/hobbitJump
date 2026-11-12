extends Node3D

const WOOD := Color("855539")
const GRASS := Color("6f9560")
const FloatingPlatform = preload("res://scripts/floating_platform.gd")
const TREE: PackedScene = preload("res://assets/third_party/kenney_survival/tree.glb")
const TALL_TREE: PackedScene = preload("res://assets/third_party/kenney_survival/tree-tall.glb")
const START_POSITION := Vector3(0, 0.05, 4.5)
const CHECKPOINT_POSITION := Vector3(0, 0.05, -24)
const END_POSITION := Vector3(0, 0.05, -52)
const DOCK_WIDTH := 32.0
const LANE_SPEEDS: Array[float] = [0.45, 0.95, 0.6, 1.1, 0.5, 0.85, 0.65, 1.0, 0.55, 1.05, 0.7, 1.15, 0.5, 0.9, 0.65, 1.1]
const PLATFORM_POSITIONS: Array[Vector3] = [
	Vector3(0, -0.3, 0.5), Vector3(1.0, -0.3, -2.5),
	Vector3(-0.7, -0.3, -5.5), Vector3(0.8, -0.3, -8.5),
	Vector3(0, -0.3, -11.5), Vector3(0.6, -0.3, -14.5),
	Vector3(-0.5, -0.3, -17.5), Vector3(0.4, -0.3, -20.5),
	Vector3(0, -0.3, -27.5), Vector3(-0.6, -0.3, -30.5),
	Vector3(0.7, -0.3, -33.5), Vector3(0, -0.3, -36.5),
	Vector3(-0.5, -0.3, -39.5), Vector3(0.6, -0.3, -42.5),
	Vector3(0, -0.3, -45.5), Vector3(-0.4, -0.3, -48.5),
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
	_box(self, Vector3(65, 0.15, 80), Vector3(0, -0.8, -24), Color("378f9d"))
	# The river flows left to right; both banks and streaks follow that direction.
	for index in range(70):
		var x := -24.0 + fmod(float(index) * 4.7, 48.0)
		var z := -54.0 + fmod(float(index) * 7.1, 61.0)
		_water_streaks.append(_box(self, Vector3(1.8, 0.015, 0.07), Vector3(x, -0.71, z), Color("62acb2")))
	_platform("StartBank", Vector3(65, 2, 9), Vector3(0, -1, 12), GRASS)
	# Butt joints: bank edge -54.5 equals dock edge -54.5, no coplanar overlap.
	_platform("EndBank", Vector3(65, 2, 12), Vector3(0, -1, -60.5), GRASS)
	for side in [-1, 1]:
		for index in range(11):
			var x := -28.0 + index * 5.6
			# Leave the central approach clear of foreground foliage and the house.
			if absf(x) < 7.0:
				continue
			var tree := (TREE if index % 2 == 0 else TALL_TREE).instantiate() as Node3D
			add_child(tree)
			tree.position = Vector3(x, 0, 13.5 if side == 1 else -61.0)
			tree.scale = Vector3.ONE * (4.5 + 0.5 * (index % 3))
			tree.rotation.y = index * 0.8


func _build_course() -> void:
	_platform("StartDock", Vector3(11, 0.6, 5.0), Vector3(0, -0.3, 5), WOOD)
	for index in range(PLATFORM_POSITIONS.size()):
		for copy in range(-3, 4):
			var platform := AnimatableBody3D.new()
			platform.set_script(FloatingPlatform)
			platform.name = "Float%d_%d" % [index, copy + 3]
			platform.kind = index % 2
			platform.drift_speed = LANE_SPEEDS[index]
			platform.position = PLATFORM_POSITIONS[index] + Vector3(copy * 7.0, 0, 0)
			add_child(platform)
	_platform("CheckpointDock", Vector3(DOCK_WIDTH, 0.6, 4), Vector3(0, -0.3, -24), WOOD)
	_platform("EndDock", Vector3(DOCK_WIDTH, 0.6, 5), Vector3(0, -0.3, -52), WOOD)
	_add_flag(Vector3(-2.0, 0, -24), Color("73b985"))
	_add_flag(Vector3(-2.0, 0, -52), Color("e2c163"))
	var checkpoint := _trigger("Checkpoint", Vector3(DOCK_WIDTH, 2, 3), Vector3(0, 1, -24))
	checkpoint.body_entered.connect(func(body: Node3D) -> void:
		if body == $Player and not $Player.spawn_position.is_equal_approx(CHECKPOINT_POSITION):
			$Player.set_checkpoint(CHECKPOINT_POSITION)
			$HUD.show_checkpoint()
	)
	# Finish only on the far half of the landing, not in midair over the river.
	var goal := _trigger("Goal", Vector3(DOCK_WIDTH, 2, 2), Vector3(0, 1, -53))
	goal.body_entered.connect(func(body: Node3D) -> void:
		if body == $Player:
			$HUD.show_goal()
	)
	_build_house()


func _add_flag(at: Vector3, color: Color) -> void:
	_box(self, Vector3(0.12, 2.3, 0.12), at + Vector3(0, 1.15, 0), Color("d9c7a1"))
	_box(self, Vector3(0.9, 0.55, 0.06), at + Vector3(0.5, 2, 0), color)


func _trigger(label: String, size: Vector3, at: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = label
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.position = at
	return area


func _build_house() -> void:
	# A small earth-roofed home is the landmark beyond the finish dock.
	_box(self, Vector3(5.4, 2.8, 3.8), Vector3(0, 1.4, -58), Color("d5bc86"))
	_box(self, Vector3(6.2, 0.6, 4.6), Vector3(0, 3.0, -58), Color("719252"))
	_box(self, Vector3(0.8, 1.5, 0.8), Vector3(1.6, 3.7, -58.5), Color("9c7864"))
	var door_mesh := CylinderMesh.new()
	door_mesh.top_radius = 0.95
	door_mesh.bottom_radius = 0.95
	door_mesh.height = 0.08
	door_mesh.radial_segments = 24
	var door := MeshInstance3D.new()
	door.mesh = door_mesh
	door.material_override = _material(Color("477a58"))
	add_child(door)
	door.rotation.x = PI / 2.0
	door.position = Vector3(0, 1.0, -56.06)
	_box(self, Vector3(0.14, 0.14, 0.08), Vector3(0.5, 1.0, -55.98), Color("ddb65c"))
	_box(self, Vector3(2.4, 0.02, 1.5), Vector3(0, 0.02, -55.25), Color("b9ab82"))


func _build_hero() -> void:
	var visual: Node3D = $Player/Visual
	$Player/Visual/Body.material_override = _material(Color("718047"))
	_box(visual, Vector3(0.43, 0.28, 0.4), Vector3(0, 1.0, 0), Color("d5ad7e"))
	_box(visual, Vector3(0.48, 0.16, 0.46), Vector3(0, 1.18, -0.04), Color("58402c"))
	for side in [-1, 1]:
		_box(visual, Vector3(0.24, 0.13, 0.45), Vector3(float(side) * 0.17, 0.08, 0.12), Color("d5ad7e"))
		_box(visual, Vector3(0.06, 0.06, 0.035), Vector3(float(side) * 0.12, 1.04, 0.215), Color("342e29"))
