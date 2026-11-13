extends Node3D

const WOOD := Color("855539")
const GRASS := Color("6f9560")
const FloatingPlatform = preload("res://scripts/floating_platform.gd")
const WATER_SHADER: Shader = preload("res://shaders/river.gdshader")
const Scenery = preload("res://scripts/scenery.gd")
const ArtMaterials = preload("res://scripts/art_materials.gd")
const DockArt = preload("res://scripts/dock_art.gd")
const CoursePath = preload("res://scripts/course_path.gd")
const START_POSITION := Vector3(0, 0.05, 4.5)
var CHECKPOINT_POSITION := Vector3(CoursePath.center_x(-24), 0.05, -24)
var END_POSITION := Vector3(CoursePath.center_x(-52), 0.05, -52)
const DOCK_WIDTH := 18.0
const LANE_SPEEDS: Array[float] = [0.45, 0.95, 0.6, 1.1, 0.5, 0.85, 0.65, 1.0, 0.55, 1.05, 0.7, 1.15, 0.5, 0.9, 0.65, 1.1]
const PLATFORM_POSITIONS: Array[Vector3] = [
	Vector3(0, -0.3, 0.5), Vector3(2.8, -0.3, -2.5),
	Vector3(-1.4, -0.3, -5.5), Vector3(1.7, -0.3, -8.5),
	Vector3(-2.7, -0.3, -11.5), Vector3(0.5, -0.3, -14.5),
	Vector3(3.0, -0.3, -17.5), Vector3(-0.8, -0.3, -20.5),
	Vector3(0, -0.3, -27.5), Vector3(-2.6, -0.3, -30.5),
	Vector3(1.8, -0.3, -33.5), Vector3(-0.9, -0.3, -36.5),
	Vector3(2.7, -0.3, -39.5), Vector3(-1.7, -0.3, -42.5),
	Vector3(0.3, -0.3, -45.5), Vector3(-3.0, -0.3, -48.5),
]
var _water_material: ShaderMaterial
var _river_time := 0.0
var _closing := false


func _physics_process(delta: float) -> void:
	_river_time += delta
	_water_material.set_shader_parameter("river_time", _river_time)


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_build_environment()
	_build_course()
	add_child(Scenery.new())
	$Player.respawned.connect($Camera.snap_to_target)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _closing:
		_closing = true
		get_tree().paused = true
		await $Feedback.prepare_shutdown()
		get_tree().quit()


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.srgb_to_linear()
	material.roughness = 0.9
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	if color == WOOD:
		instance.material_override = ArtMaterials.painted(1, 0.3, Color("a1a18c"))
	elif color == GRASS:
		instance.material_override = ArtMaterials.painted(0, 0.32)
	parent.add_child(instance)
	instance.position = at
	return instance


func _platform(label: String, size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	at.x += CoursePath.center_x(at.z)
	var body := StaticBody3D.new()
	body.name = label
	add_child(body)
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	if label.ends_with("Dock"):
		var art := DockArt.new()
		art.size = size
		body.add_child(art)
	else:
		_box(body, size, Vector3.ZERO, color)
	return body


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("547784")
	sky_material.sky_horizon_color = Color("c4c9aa")
	sky_material.ground_horizon_color = Color("b0b69a")
	sky_material.ground_bottom_color = Color("41574a")
	sky_material.sun_angle_max = 8.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c3d1d2")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("728d86")
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.35
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -36, 0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 145, 0)
	fill.light_color = Color("b6cbd1")
	fill.light_energy = 0.48
	add_child(fill)
	var water := _box(self, Vector3(65, 0.15, 80), Vector3(0, -0.8, -24), Color("378f9d"))
	_water_material = ShaderMaterial.new()
	_water_material.shader = WATER_SHADER
	water.material_override = _water_material
	_platform("StartBank", Vector3(65, 2, 10.5), Vector3(0, -1, 11.25), GRASS)
	# Butt joints: bank edge -54.5 equals dock edge -54.5, no coplanar overlap.
	_platform("EndBank", Vector3(65, 2, 12), Vector3(0, -1, -60.5), GRASS)


func _build_course() -> void:
	_platform("StartDock", Vector3(11, 0.6, 3.5), Vector3(0, -0.3, 4.25), WOOD)
	for index in range(PLATFORM_POSITIONS.size()):
		for copy in range(-3, 4):
			var platform := AnimatableBody3D.new()
			platform.set_script(FloatingPlatform)
			platform.name = "Float%d_%d" % [index, copy + 3]
			platform.kind = index % 2
			platform.visual_variant = posmod(index + copy, 3)
			platform.drift_speed = LANE_SPEEDS[index]
			platform.lane_center_x = CoursePath.center_x(PLATFORM_POSITIONS[index].z)
			platform.position = PLATFORM_POSITIONS[index] + Vector3(copy * 7.0 + platform.lane_center_x, 0, 0)
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
	at.x += CoursePath.center_x(at.z)
	_box(self, Vector3(0.12, 2.3, 0.12), at + Vector3(0, 1.15, 0), Color("d9c7a1"))
	_box(self, Vector3(0.9, 0.55, 0.06), at + Vector3(0.5, 2, 0), color)


func _trigger(label: String, size: Vector3, at: Vector3) -> Area3D:
	at.x += CoursePath.center_x(at.z)
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
	var house := preload("res://scripts/hobbit_house.gd").new()
	house.position = Vector3(CoursePath.center_x(-58.0), 0, -58)
	add_child(house)
