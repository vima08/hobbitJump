extends Node3D
## Deterministic woodland on the real Z shores and behind the inlet.
## No scenery crosses the X-directed float lanes.

const SURFACE: Shader = preload("res://shaders/scenery_surface.gdshader")
const ATLAS: Texture2D = preload("res://assets/art/woodland-atlas-v1.png")
const CoursePath := preload("res://scripts/course_path.gd")
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
	_build_channel_islets()
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
	if label.begins_with("InterRowTreeCrown") or label.begins_with("InterRowTreeTrunk"):
		# Only the part obscuring the hero fades; other trees keep their material.
		instance.material_override = material.duplicate()
		instance.add_to_group("camera_soft_visuals")


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


func _build_banks() -> void:
	# The actual river flows +X: only the Z shores have riverbank toes.
	for side in [-1.0, 1.0]:
		_begin()
		var rows: Array[PackedVector3Array] = []
		for index in 31:
			var x := -37.0 + index * 2.0
			var edge := 3.0 if side > 0 else -51.0
			var wobble := sin(x * 0.28) * 0.28
			rows.append(PackedVector3Array([
				Vector3(x, -1.4, edge + side * wobble),
				Vector3(x, -0.05, edge + side * (1.2 + wobble)),
				Vector3(x, 0.05, edge + side * 5.0),
				Vector3(x, 1.6 + sin(x * 0.19) * 0.35, edge + side * 12.0),
				Vector3(x, 2.7, edge + side * 23.0)]))
		for row in range(rows.size() - 1):
			for column in 4:
				var color := Color("74705a") if column == 0 else Color("70814b")
				color = color.lightened(_rng.randf_range(-0.06, 0.06))
				_triangle(rows[row][column], rows[row + 1][column], rows[row][column + 1], color)
				_triangle(rows[row][column + 1], rows[row + 1][column], rows[row + 1][column + 1], color)
		# Start-shore support is made from the very same triangles as its visible
		# slope. Keep the far shore decorative; its landing has separate support.
		if side > 0:
			_show_solid(_finish(), _stone, "StartShoreSlope")
		else:
			_show(_finish(), _stone, "FarShoreSlope")
	_begin()
	# The visible terrace ends exactly where the physical bank ends: x=23.
	# Only land is closed; the falling-water span -51<z<3 remains open.
	for side in [-1.0, 1.0]:
		var edge := 3.0 if side > 0 else -51.0
		var wobble := sin(23.0 * 0.28) * 0.28
		var crest_height := 1.6 + sin(23.0 * 0.19) * 0.35
		var end_depth := 13.0 if side > 0 else 16.0
		var depths: Array[float] = [0.0, 1.2 + wobble, 5.0, 12.0, end_depth]
		var heights: Array[float] = [-1.4, -0.05, 0.05, crest_height, lerpf(crest_height, 2.7, (end_depth - 12.0) / 11.0)]
		for index in range(depths.size() - 1):
			var a := Vector3(23, heights[index], edge + side * depths[index])
			var b := Vector3(23, heights[index + 1], edge + side * depths[index + 1])
			var c := Vector3(23, -10.15, b.z)
			var d := Vector3(23, -10.15, a.z)
			_triangle(a, b, c, Color("777760"))
			_triangle(a, c, d, Color("686e5b"))
	_show_solid(_finish(), _stone, "RightShoreCliffFaces")
	_begin()
	for side in [-1.0, 1.0]:
		var shore_z := 6.0 if side > 0 else -55.5
		for index in 10:
			var x := -29.0 + index * 6.3
			if absf(x) < 12.0 or x > 20.0:
				continue
			_ellipsoid(Vector3(x, -0.2, shore_z), Vector3(1.4, 0.9, 1.1), Color("85806a"), 9, 6)
	_show(_finish(), _stone, "ShoreBoulders")

func _show_solid(mesh: Mesh, material: Material, label: String) -> void:
	_show(mesh, material, label)
	var body := StaticBody3D.new()
	body.name = label + "Collision"
	if label.begins_with("InterRowTreeTrunk"):
		body.add_to_group("camera_soft_bodies")
	elif label == "RightShoreCliffFaces":
		body.collision_layer = 5
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _build_channel_islets() -> void:
	# Four separate stony slivers live only at exact inter-row midpoints.
	# The hull sweeps +/-0.9m in Z; these rocks stay within +/-0.31m
	# of the midpoint, leaving at least 0.29m of water on either side.
	var placements: Array[Vector2] = [Vector2(12, -1), Vector2(12, -13), Vector2(-12, -29), Vector2(-12, -41)]
	for index in placements.size():
		var z := placements[index].y
		var at := Vector3(CoursePath.center_x(z) + placements[index].x, 0, z)
		_begin()
		_ellipsoid(at + Vector3(0, -0.42, 0), Vector3(1.75, 0.48, 0.29), Color("85806a"), 16, 8, 0.05)
		_ellipsoid(at + Vector3(0.65, -0.40, 0), Vector3(0.72, 0.43, 0.27), Color("76805b"), 12, 7, 0.05)
		_show_solid(_finish(), _stone, "InterRowStone%d" % index)
		_begin()
		var bark := Color("594a32")
		_branch(at + Vector3(0, 0.04, 0), at + Vector3(0.15, 3.4, 0), 0.15, bark, 0.55)
		for root in [-1.0, 1.0]:
			_branch(at + Vector3(root * 0.65, 0.045, root * 0.10), at + Vector3(0, 0.55, 0), 0.065, bark, 1.5)
		for limb in 5:
			var angle := limb * 2.399 + index
			var end := at + Vector3(cos(angle) * 1.05, 3.65 + (limb % 2) * 0.5, sin(angle) * 0.85)
			_branch(at + Vector3(0.1, 2.8 + (limb % 2) * 0.2, 0), end, 0.09, bark)
		_show_solid(_finish(), _leaves, "InterRowTreeTrunk%d" % index)
		_begin()
		for limb in 5:
			var angle := limb * 2.399 + index
			var center := at + Vector3(cos(angle) * 1.05, 3.85 + (limb % 2) * 0.5, sin(angle) * 0.85)
			var color: Color = [Color("667d36"), Color("879440"), Color("4f713b")][limb % 3]
			_ellipsoid(center, Vector3(1.15, 0.65, 1.05), color, 10, 6, 0.16)
			_leaf_spray(center, Vector3(1.25, 0.72, 1.15), color, limb + index)
		_show(_finish(), _leaves, "InterRowTreeCrown%d" % index)


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
		var edge := 3.0 if side > 0 else -51.0
		for index in 24:
			var x := -39.0 + index * 3.2 + _rng.randf_range(-0.7, 0.7)
			var depth := _rng.randf_range(10.0, 21.0)
			var at := Vector3(x, 1.4 + (depth - 10.0) * 0.08, edge + side * depth)
			if x > 20.0:
				at.z = 24.0 + depth * 0.2 if side > 0 else -76.0 - depth * 0.2
			trees[index % 3].append(_placement(at, Vector3.ONE * _rng.randf_range(0.85, 1.25), index * 2.4))
		for index in 210:
			var x := _rng.randf_range(-37.0, 20.0)
			var depth := _rng.randf_range(5.5, 20.0)
			if absf(x) < 6.0 and depth < 10.0:
				continue
			var at := Vector3(x, maxf(0.08, (depth - 5.0) * 0.12), edge + side * depth)
			var size := _rng.randf_range(0.65, 1.4)
			grass.append(_placement(at, Vector3.ONE * size, index * 1.7))
			ferns.append(_placement(at + Vector3(0.45, 0, 0.3), Vector3.ONE * size, index * 2.3))
			if index % 3 == 0:
				bushes.append(_placement(at, Vector3.ONE * size, index * 1.4))
	for index in 17:
		var at := Vector3(-37.5 - _rng.randf_range(0.0, 6.0), 4.3, 6.0 - index * 4.0)
		trees[index % 3].append(_placement(at, Vector3.ONE * _rng.randf_range(0.9, 1.3), index * 1.5))
	for variant in 3:
		var placements: Array[Transform3D] = []
		for placement in trees[variant]:
			placements.append(placement)
		_scatter(_tree_mesh(variant), _leaves, placements, "BroadleafTrees%d" % variant)
	for side in [-1.0, 1.0]:
		for index in 12:
			var at := Vector3(side * (3.2 + (index % 4) * 0.65), 0.04, 6.3 + index / 4 * 0.55)
			ferns.append(_placement(at, Vector3.ONE * 0.65, index * 2.4))
			grass.append(_placement(at, Vector3.ONE * 0.9, index * 1.7))
		for index in 9:
			var at := Vector3(side * (5.5 + (index % 3) * 1.2), 0.08, -56.3 - index * 0.7)
			bushes.append(_placement(at, Vector3.ONE * 0.9, index * 1.7))
			ferns.append(_placement(at, Vector3.ONE, index * 1.1))
	_scatter(_bush_mesh(), _leaves, bushes, "LeafyUndergrowth")
	_scatter(_fern_mesh(), _leaves, ferns, "RiverFerns", false)
	_scatter(_grass_mesh(), _leaves, grass, "GoldenGrass", false)
	_build_flowers()

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
