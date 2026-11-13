extends Node3D
## The river source and outfall use global course coordinates, not lane offsets.

const SURFACE := preload("res://shaders/scenery_surface.gdshader")
const ATLAS := preload("res://assets/art/woodland-atlas-v1.png")
const FALL_SHADER := preload("res://shaders/waterfall.gdshader")
var _stone: ShaderMaterial
var _water: ShaderMaterial
var _surface: SurfaceTool
var _river_time := 0.0


func _ready() -> void:
	name = "RiverLandscape"
	_stone = ShaderMaterial.new()
	_stone.shader = SURFACE
	_stone.set_shader_parameter("painted_atlas", ATLAS)
	_water = ShaderMaterial.new()
	_water.shader = FALL_SHADER
	_build_inlet()
	_build_land_limits()
	_build_waterfall()


func _physics_process(delta: float) -> void:
	_river_time += delta
	_water.set_shader_parameter("river_time", _river_time)


func _begin() -> void:
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_surface.set_color(color.srgb_to_linear())
	for point in [a, b, c]:
		_surface.add_vertex(point)


func _finish(label: String, material: Material, solid: bool = false) -> MeshInstance3D:
	_surface.generate_normals()
	var mesh := _surface.commit()
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)
	if label == "RoundedFallingWater":
		# The curtain opens locally when the falling hero is behind it.
		visual.add_to_group("camera_soft_visuals")
	if solid:
		var body := StaticBody3D.new()
		body.name = label + "Collision"
		body.collision_layer = 5 # Gameplay + camera terrain anticipation.
		var collision := CollisionShape3D.new()
		var shape := mesh.create_trimesh_shape()
		# The source is a thin stone shell, so both sides must be physical.
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	return visual


func _rock(at: Vector3, radius: Vector3, color: Color) -> void:
	for ring in 7:
		for segment in 12:
			var points: Array[Vector3] = []
			for corner in [Vector2(segment, ring), Vector2(segment + 1, ring), Vector2(segment + 1, ring + 1), Vector2(segment, ring + 1)]:
				var azimuth: float = corner.x / 12.0 * TAU
				var elevation: float = corner.y / 7.0 * PI
				var unit := Vector3(sin(elevation) * cos(azimuth), cos(elevation), sin(elevation) * sin(azimuth))
				var wobble := 1.0 + sin(azimuth * 3.0 + elevation * 5.0) * sin(elevation) * 0.09
				points.append(at + unit * radius * wobble)
			_triangle(points[0], points[1], points[2], color)
			_triangle(points[0], points[2], points[3], color)


func _build_inlet() -> void:
	# A continuous low stone shelf, not a separate tunnel for every row.
	# The underside is 0.85m above water: floats pass, a standing hero cannot.
	_begin()
	for index in 29:
		var z := -55.0 + index * 2.0
		var next_z := z + 2.0
		var top := 3.5 + sin(z * 0.25) * 0.6
		var next_top := 3.5 + sin(next_z * 0.25) * 0.6
		var a := Vector3(-23, 0.85, z)
		var b := Vector3(-23, 0.85, next_z)
		var c := Vector3(-23.4, next_top, next_z)
		var d := Vector3(-23.4, top, z)
		_triangle(a, b, c, Color("797862"))
		_triangle(a, c, d, Color("797862"))
		_triangle(Vector3(-35, 0.85, z), Vector3(-35, 0.85, next_z), a, Color("575747"))
		_triangle(a, Vector3(-35, 0.85, next_z), b, Color("575747"))
		_triangle(d, c, Vector3(-38, 4.3, z), Color("70814b"))
		_triangle(Vector3(-38, 4.3, z), c, Vector3(-38, 4.3, next_z), Color("70814b"))
	_finish("ContinuousInletRockShelf", _stone, true)
	_begin()
	for index in 20:
		# Weathered protrusions above the exact physical low ceiling.
		_rock(Vector3(-26.3, 3.8, -54.0 + index * 3.0), Vector3(3.0, 1.2, 2.2), Color("81806b"))
	_finish("InletCrownBoulders", _stone, true)
	# The common channel remains deep below the barrel bottoms.
	_begin()
	_triangle(Vector3(-43, -2.4, -55), Vector3(-22.8, -2.4, -55), Vector3(-43, -2.4, 3), Color("535e4d"))
	_triangle(Vector3(-22.8, -2.4, -55), Vector3(-22.8, -2.4, 3), Vector3(-43, -2.4, 3), Color("535e4d"))
	_finish("SubmergedSourceFloor", _stone, true)


func _build_land_limits() -> void:
	_begin()
	# Actual rocks across the ends of the accessible garden banks.
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			for index in 7:
				var z := (5.0 + index * 2.7) if side > 0 else (-56.0 - index * 2.7)
				var x := -(25.0 + sin(index * 1.3)) if end < 0 else 32.0 + sin(index * 1.3)
				_rock(Vector3(x, 0.9, z), Vector3(3.3, 2.5 + (index % 2) * 0.7, 2.6), Color("777760"))
	_finish("VisibleGardenRockLimits", _stone, true)
	_begin()
	# Rock supports stay outside the full span of the falling current.
	for z in [-58.0, 6.0]:
		for index in 6:
			_rock(Vector3(34.5 + index * 1.8, -3.8, z), Vector3(3.3, 6.0, 2.8), Color("686e5b"))
	_finish("OutfallAbutments", _stone, true)


func _fall_point(z: float, t: float) -> Vector3:
	# Rounded lip, then a free fall into the lower reach. No solid crest wall.
	var x := 23.0 + t * 4.8
	var y := -0.725 - t * t * 9.4
	return Vector3(x, y + sin(z * 2.3) * 0.045 * t, z)


func _build_waterfall() -> void:
	_begin()
	for strip in 116:
		var z := -55.0 + strip * 0.5
		for segment in 15:
			var t := segment / 15.0
			var next_t := (segment + 1) / 15.0
			_triangle(_fall_point(z, t), _fall_point(z + 0.5, t), _fall_point(z, next_t), Color.WHITE)
			_triangle(_fall_point(z + 0.5, t), _fall_point(z + 0.5, next_t), _fall_point(z, next_t), Color.WHITE)
	_finish("RoundedFallingWater", _water)
	# A shallowly curved crest and broken ribbons make the drop legible from upstream.
	_begin()
	for strip in 116:
		var z := -55.0 + strip * 0.5
		var left := 20.5 + sin(z * 1.7) * 0.4
		_triangle(Vector3(left, -0.710, z), Vector3(23, -0.710, z), Vector3(left, -0.710, z + 0.5), Color.WHITE)
		_triangle(Vector3(23, -0.710, z), Vector3(23, -0.710, z + 0.5), Vector3(left, -0.710, z + 0.5), Color.WHITE)
	_finish("AcceleratingCrestRipples", _water)
	_begin()
	_triangle(Vector3(26.0, -10.15, -62), Vector3(68, -10.15, -62), Vector3(26.0, -10.15, 10), Color.WHITE)
	_triangle(Vector3(68, -10.15, -62), Vector3(68, -10.15, 10), Vector3(26.0, -10.15, 10), Color.WHITE)
	_finish("LowerRiverReach", _water)
