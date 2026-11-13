extends Node3D
## Original, deterministic scenic geometry. No collision or gameplay state.
## Kept outside the navigable river and the three landing approaches.

const SURFACE: Shader = preload("res://shaders/scenery_surface.gdshader")
const ATLAS: Texture2D = preload("res://assets/art/woodland-atlas-v1.png")
const CoursePath = preload("res://scripts/course_path.gd")
var _rng := RandomNumberGenerator.new()
var _stone: ShaderMaterial
var _leaves: ShaderMaterial
var _surface: SurfaceTool


func _ready() -> void:
	name = "RiverScenery"
	_rng.seed = 312709
	_stone = ShaderMaterial.new()
	_stone.shader = SURFACE
	_stone.set_shader_parameter("painted_atlas", ATLAS)
	_leaves = ShaderMaterial.new()
	_leaves.shader = SURFACE
	_leaves.set_shader_parameter("painted_atlas", ATLAS)
	_leaves.set_shader_parameter("foliage", 1.0)
	_build_banks()
	_build_vegetation()
	_build_distance()


func _begin() -> void:
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_surface.set_color(color.srgb_to_linear())
	_surface.add_vertex(a)
	_surface.add_vertex(b)
	_surface.add_vertex(c)


func _finish() -> ArrayMesh:
	_surface.generate_normals()
	return _surface.commit()


func _show(mesh: Mesh, material: Material, label: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)


func _scatter(mesh: Mesh, material: Material, transforms: Array[Transform3D], label: String, shadows: bool = true) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in transforms.size():
		batch.set_instance_transform(index, transforms[index])
	instance.multimesh = batch
	instance.material_override = material
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _placement(at: Vector3, size: Vector3, angle: float = 0.0) -> Transform3D:
	at.x += CoursePath.center_x(at.z)
	return Transform3D(Basis(Vector3.UP, angle).scaled(size), at)


func _ellipsoid(at: Vector3, radius: Vector3, color: Color, segments: int = 10, rings: int = 6, roughness: float = 0.13) -> void:
	for ring in rings:
		for segment in segments:
			var points: Array[Vector3] = []
			for corner in [Vector2(segment, ring), Vector2(segment + 1, ring), Vector2(segment + 1, ring + 1), Vector2(segment, ring + 1)]:
				var azimuth: float = corner.x / segments * TAU
				var elevation: float = corner.y / rings * PI
				var unit := Vector3(sin(elevation) * cos(azimuth), cos(elevation), sin(elevation) * sin(azimuth))
				var wobble := 1.0 + roughness * sin(azimuth * 3.0 + elevation * 5.0) * sin(elevation)
				points.append(at + unit * radius * wobble)
			_triangle(points[0], points[1], points[2], color)
			_triangle(points[0], points[2], points[3], color)


func _branch(start: Vector3, end: Vector3, width: float, color: Color, end_width: float = 0.35) -> void:
	var axis := (end - start).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1:
		right = axis.cross(Vector3.RIGHT).normalized()
	var forward := axis.cross(right).normalized()
	for index in 7:
		var a := TAU * index / 7.0
		var b := TAU * (index + 1) / 7.0
		var one := (right * cos(a) + forward * sin(a)) * width
		var two := (right * cos(b) + forward * sin(b)) * width
		_triangle(start + one, start + two, end + one * end_width, color)
		_triangle(start + two, end + two * end_width, end + one * end_width, color)


func _bank_edge(z: float) -> float:
	# The lowest submerged toe remains outside the 17m navigable corridor.
	return 11.5 + sin(z * 0.21) * 0.8 + sin(z * 0.64) * 0.4


func _build_banks() -> void:
	_begin()
	for side in [-1.0, 1.0]:
		var rows: Array[PackedVector3Array] = []
		for index in 42:
			var z := -69.0 + index * 2.15
			var edge := _bank_edge(z)
			var height := 2.3 + sin(z * 0.18) * 0.9
			var center := CoursePath.center_x(z)
			rows.append(PackedVector3Array([
				Vector3(center + side * (edge - 0.5), -1.3, z),
				Vector3(center + side * edge, 0.35 + sin(z) * 0.15, z),
				Vector3(center + side * (edge + 1.8), height, z),
				Vector3(center + side * 20.0, height + 0.5, z),
				Vector3(center + side * 31.0, height + 1.0, z)]))
		for row in range(rows.size() - 1):
			for column in 4:
				var color := Color("74705a") if column < 2 else Color("647345")
				color = color.lightened(_rng.randf_range(-0.08, 0.08))
				if side > 0:
					_triangle(rows[row][column], rows[row + 1][column], rows[row][column + 1], color)
					_triangle(rows[row][column + 1], rows[row + 1][column], rows[row + 1][column + 1], color)
				else:
					_triangle(rows[row][column], rows[row][column + 1], rows[row + 1][column], color)
					_triangle(rows[row][column + 1], rows[row + 1][column + 1], rows[row + 1][column], color)
	_show(_finish(), _stone, "LayeredRockBanks")
	_begin()
	for side in [-1.0, 1.0]:
		for index in 20:
			var z := -64.0 + index * 4.0
			var x: float = CoursePath.center_x(z) + side * (_bank_edge(z) + 0.6)
			_ellipsoid(Vector3(x, 0.1, z), Vector3(0.95, 1.3, 2.1), Color("85806a"), 8, 5)
	_show(_finish(), _stone, "WaterlineBoulders")
	# The house receives irregular grassy hills behind and alongside its approach.
	_begin()
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(CoursePath.center_x(-61.5) + side * 10.0, -1.0, -61.5), Vector3(6.5, 3.5, 5.0), Color("70814b"), 18, 10)
		_ellipsoid(Vector3(side * 18.0, -1.4, 12.5), Vector3(7.5, 2.8, 4.8), Color("70814b"), 18, 10)
		# Exposed roots step down the rock shelves without reaching the waterway.
		for index in 13:
			var z := -59.0 + index * 5.0
			var edge := _bank_edge(z)
			var root_color := Color("685035")
			var upper := Vector3(side * (edge + 3.8), 2.8 + sin(z * 0.18) * 0.8, z)
			var joint := Vector3(side * (edge + 2.0), 1.65, z + 0.55)
			var tip := Vector3(side * (edge + 0.25), 0.25, z + 1.2)
			upper.x += CoursePath.center_x(upper.z)
			joint.x += CoursePath.center_x(joint.z)
			tip.x += CoursePath.center_x(tip.z)
			_branch(upper, joint, 0.22, root_color, 0.72)
			_branch(joint, tip, 0.16, root_color, 0.2)
			_branch(joint, tip + Vector3(side * 0.6, 0.2, -1.5), 0.12, root_color, 0.15)
	_show(_finish(), _leaves, "GardenMounds")


func _tree_mesh(variant: int) -> ArrayMesh:
	_begin()
	var bark := Color("594a32")
	var height := 7.0 + variant * 1.1
	var bend := Vector3(0.5 - variant * 0.3, height * 0.58, 0.25)
	_branch(Vector3.ZERO, bend, 0.50, bark, 0.70)
	_branch(bend, Vector3(-0.3, height, 0.0), 0.35, bark, 0.27)
	for root in 5:
		var angle := root * TAU / 5.0
		_branch(Vector3(cos(angle) * 1.0, 0.03, sin(angle) * 1.0), Vector3(0, 1.5, 0), 0.16, bark, 1.8)
	for limb in 8:
		var angle := limb * 2.399 + variant
		var elevation := height * (0.54 + float(limb % 3) * 0.12)
		var reach := 1.8 + float(limb % 2) * 0.75
		var end := Vector3(cos(angle) * reach, elevation + 0.9, sin(angle) * reach)
		_branch(Vector3(0.1, elevation - 1.0, 0), end, 0.17, bark)
		var leaf_color: Color = [Color("667d36"), Color("879440"), Color("4f713b"), Color("7e8837")][(limb + variant) % 4]
		_ellipsoid(end, Vector3(1.43, 1.1, 1.38), leaf_color, 9, 6, 0.22)
		_leaf_spray(end, Vector3(1.65, 1.3, 1.6), leaf_color, limb + variant * 3)
	_ellipsoid(Vector3(0, height + 0.6, 0), Vector3(1.65, 1.4, 1.55), Color("829344"), 10, 6, 0.2)
	_leaf_spray(Vector3(0, height + 0.6, 0), Vector3(1.9, 1.6, 1.8), Color("829344"), variant)
	return _finish()


func _leaf_spray(center: Vector3, radius: Vector3, color: Color, variation: int) -> void:
	# Folded oak leaf silhouettes break the round outline of a canopy cluster.
	for index in 44:
		var angle := index * 2.399 + variation * 0.7
		var y := -0.85 + index / 43.0 * 1.7
		var radial := sqrt(1.0 - y * y)
		var unit := Vector3(cos(angle) * radial, y, sin(angle) * radial)
		var at := center + unit * radius
		var along := Vector3(cos(angle + 0.4), 0.3 + sin(index * 1.7) * 0.4, sin(angle + 0.4)).normalized()
		var across := along.cross(Vector3.UP).normalized()
		var length := 0.28 + (index % 3) * 0.07
		var shade := color.lightened((index % 5 - 2) * 0.035)
		var base := at - along * length
		var tip := at + along * length
		var ridge := at + Vector3.UP * 0.055
		_triangle(base, ridge, at + across * length * 0.48, shade)
		_triangle(ridge, tip, at + across * length * 0.48, shade)
		_triangle(base, at - across * length * 0.48, ridge, shade.darkened(0.1))
		_triangle(ridge, at - across * length * 0.48, tip, shade.darkened(0.1))


func _bush_mesh() -> ArrayMesh:
	_begin()
	for index in 8:
		var angle := index * 2.399
		var position := Vector3(cos(angle), 0.45 + (index % 3) * 0.2, sin(angle)) * 0.65
		_ellipsoid(position, Vector3(0.65, 0.60, 0.65), Color("67883e").lightened((index % 3) * 0.06), 7, 4, 0.21)
	return _finish()


func _fern_mesh() -> ArrayMesh:
	_begin()
	for frond in 8:
		var angle := frond * TAU / 8.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-sin(angle), 0, cos(angle))
		for leaflet in range(1, 8):
			var t := leaflet / 8.0
			var base := direction * t * 0.95 + Vector3.UP * sin(t * 2.7) * 0.68
			var tip := direction * (t + 0.20) + Vector3.UP * sin((t + 0.12) * 2.7) * 0.68
			var spread := sin(t * PI) * 0.27
			var color := Color("6b963f").lightened(t * 0.1)
			_triangle(base, tip, base + side * spread - direction * 0.12, color)
			_triangle(base, base - side * spread - direction * 0.12, tip, color)
	return _finish()


func _grass_mesh() -> ArrayMesh:
	_begin()
	for blade in 12:
		var angle := blade * 2.399
		var base := Vector3(cos(angle) * 0.21, 0, sin(angle) * 0.21)
		var width := Vector3(cos(angle + 0.7), 0, sin(angle + 0.7)) * 0.055
		var height := 0.32 + (blade % 4) * 0.13
		var middle := base + Vector3(0.08 * cos(angle), height * 0.65, 0.08 * sin(angle))
		var tip := base + Vector3(0.3 * cos(angle), height, 0.3 * sin(angle))
		var color := Color("8a9d47").lightened((blade % 3) * 0.06)
		_triangle(base - width, middle - width * 0.6, base + width, color)
		_triangle(base + width, middle - width * 0.6, middle + width * 0.6, color)
		_triangle(middle - width * 0.6, tip, middle + width * 0.6, color)
	return _finish()


func _build_vegetation() -> void:
	var bushes: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var trees: Array = [[], [], []]
	for side in [-1.0, 1.0]:
		for index in 18:
			var z := -66.0 + index * 4.6 + _rng.randf_range(-1.0, 1.0)
			var x: float = side * _rng.randf_range(14.5, 23.0)
			var scale_factor := _rng.randf_range(0.85, 1.3)
			trees[index % 3].append(_placement(Vector3(x, 2.0, z), Vector3.ONE * scale_factor, _rng.randf() * TAU))
		for index in 140:
			var z := _rng.randf_range(-67.0, 16.0)
			var x: float = side * _rng.randf_range(13.6, 21.0)
			var y := 2.3 + sin(z * 0.18) * 0.9
			var size := _rng.randf_range(0.65, 1.45)
			bushes.append(_placement(Vector3(x, y, z), Vector3(size, size, size), _rng.randf() * TAU))
		for index in 180:
			var z := _rng.randf_range(-67.0, 15.5)
			var x: float = side * _rng.randf_range(13.3, 21.0)
			var y := 2.4 + sin(z * 0.18) * 0.9
			ferns.append(_placement(Vector3(x, y, z), Vector3.ONE * _rng.randf_range(0.7, 1.4), _rng.randf() * TAU))
		for index in 360:
			var z := _rng.randf_range(-67.0, 16.0)
			var x: float = side * _rng.randf_range(13.4, 24.0)
			grass.append(_placement(Vector3(x, 2.4 + sin(z * 0.18) * 0.9, z), Vector3.ONE * _rng.randf_range(0.7, 1.7), _rng.randf() * TAU))
	# Low garden plants frame the centre while preserving the 11m start path.
	for index in 130:
		var side := -1.0 if index % 2 == 0 else 1.0
		var x: float = side * _rng.randf_range(6.8, 28.0)
		var z := _rng.randf_range(9.0, 15.5) if index < 65 else _rng.randf_range(-65.5, -57.0)
		var at := Vector3(x, 0.05, z)
		grass.append(_placement(at, Vector3.ONE * _rng.randf_range(1.0, 1.7), _rng.randf() * TAU))
		if index % 3 == 0:
			ferns.append(_placement(at, Vector3.ONE * 0.8, _rng.randf() * TAU))
	for variant in 3:
		var placements: Array[Transform3D] = []
		for placement in trees[variant]:
			placements.append(placement)
		if variant == 0:
			for side in [-1.0, 1.0]:
				placements.append(_placement(Vector3(side * 9.7, 0, 12.5), Vector3(0.73, 0.83, 0.73), side * 0.7))
				placements.append(_placement(Vector3(side * 9.0, 0, -61.5), Vector3(0.85, 0.85, 0.85), side * 1.2))
				for index in 5:
					var z: float = 1.0 - index * 12.7 + side * 2.0
					placements.append(_placement(Vector3(side * (_bank_edge(z) + 1.4), 1.4, z), Vector3(0.9, 0.95, 0.9), index * 1.5))
		_scatter(_tree_mesh(variant), _leaves, placements, "BroadleafTrees%d" % variant)
	for side in [-1.0, 1.0]:
		for index in 12:
			var foreground := Vector3(side * (3.2 + (index % 4) * 0.65), 0.04, 6.3 + index / 4 * 0.55)
			ferns.append(_placement(foreground, Vector3.ONE * 0.65, index * 2.4))
			grass.append(_placement(foreground, Vector3.ONE * 0.9, index * 1.7))
		for index in 8:
			var at := Vector3(side * (6.7 + (index % 3) * 1.1), 0.08, 8.05 + index * 0.55)
			bushes.append(_placement(at, Vector3.ONE * (0.66 + (index % 2) * 0.16), index * 1.7))
			ferns.append(_placement(at + Vector3(side * 0.2, 0, -0.5), Vector3.ONE * 0.9, index * 1.1))
		for index in 9:
			var at := Vector3(side * (5.5 + (index % 3) * 1.2), 0.08, -56.3 - index * 0.7)
			bushes.append(_placement(at, Vector3.ONE * 0.9, index * 1.7))
			ferns.append(_placement(at + Vector3(side * 1.2, 0, 0.4), Vector3.ONE, index * 1.1))
	_scatter(_bush_mesh(), _leaves, bushes, "LeafyUndergrowth")
	_scatter(_fern_mesh(), _leaves, ferns, "RiverFerns", false)
	_scatter(_grass_mesh(), _leaves, grass, "GoldenGrass", false)
	_build_flowers()
	_begin()
	for side in [-1.0, 1.0]:
		for index in 6:
			var at := Vector3(side * (6.3 + (index % 2) * 1.8), 0.02, 8.1 + index * 0.9)
			_ellipsoid(at, Vector3(0.5, 0.28 + index % 2 * 0.12, 0.45), Color("8b866a"), 8, 5)
	_show(_finish(), _stone, "GardenEdgingRocks")


func _build_flowers() -> void:
	_begin()
	for index in 4:
		var at := Vector3(cos(index * 2.4) * 0.3, 0.35 + index * 0.08, sin(index * 2.4) * 0.3)
		_branch(at * Vector3(1,0,1), at, 0.018, Color("527d3a"))
		for petal in 5:
			var angle := petal * TAU / 5.0
			_ellipsoid(at + Vector3(cos(angle) * 0.07, 0, sin(angle) * 0.07), Vector3(0.07, 0.04, 0.07), Color("e6cb78"), 5, 3, 0.0)
	var flowers := _finish()
	var placements: Array[Transform3D] = []
	for index in 80:
		var side := -1.0 if index % 2 == 0 else 1.0
		var at := Vector3(side * _rng.randf_range(6.5, 20.0), 0.06, _rng.randf_range(8.5, 16.0) if index < 40 else _rng.randf_range(-65.0, -57.0))
		placements.append(_placement(at, Vector3.ONE, _rng.randf() * TAU))
	_scatter(flowers, _leaves, placements, "GardenWildflowers", false)


func _build_distance() -> void:
	_begin()
	for index in 14:
		var angle := PI + float(index) / 13.0 * PI
		var at := Vector3(cos(angle) * 65.0, -4.0, -49.0 + sin(angle) * 57.0)
		_ellipsoid(at, Vector3(19 + index % 3 * 4, 15 + index % 4 * 3, 20), Color("596f58").lightened((index % 3) * 0.025), 18, 9, 0.15)
	_show(_finish(), _leaves, "WoodlandRidge")
	# A wooded slope closes the reverse view beyond the start garden.
	_begin()
	for index in 7:
		_ellipsoid(Vector3(-38 + index * 12, -3.5, 33 + sin(index) * 4), Vector3(15, 9 + index % 3, 16), Color("596f58"), 16, 8)
	_show(_finish(), _stone, "SouthernHills")
	var distant: Array[Transform3D] = []
	for index in 42:
		var x: float = -63.0 + index * 3.0
		distant.append(_placement(Vector3(x, 3.0 + sin(index * 0.7) * 2.0, -77.0 - absf(x) * 0.22), Vector3.ONE * _rng.randf_range(1.25, 1.9), index * 2.4))
	for index in 25:
		var x := -36.0 + index * 3.0
		distant.append(_placement(Vector3(x, 1.1, 19.0 + sin(index * 0.7) * 2), Vector3.ONE * _rng.randf_range(0.9, 1.4), index * 2.4))
	_scatter(_tree_mesh(1), _leaves, distant, "DistantWoodland", false)
