extends Node3D
## Scenic home, local origin at ground level; face points toward +Z.
const Art = preload("res://scripts/art_materials.gd")
var _stone: Material
var _wood: Material
var _grass: Material
var _plaster: ShaderMaterial


func _ready() -> void:
	name = "HillsideHome"
	_stone = Art.painted(2, 0.33, Color("c6b99c"))
	_wood = Art.painted(1, 0.35, Color("bfa179"))
	_grass = Art.painted(0, 0.35, Color("b2c789"))
	_plaster = _architectural(Color("8d7952"))
	_build_shell()
	_build_front()
	_build_garden()


func _architectural(tint: Color, kind: int = 0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/architecture.gdshader")
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("surface_kind", kind)
	material.set_shader_parameter("atlas", preload("res://assets/art/woodland-atlas-v1.png"))
	return material


func _build_facade() -> void:
	# A single filled arch, wholly inside the planted roof; no spherical plaster cap.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 32:
		var a := float(segment) / 32.0 * PI
		var b := float(segment + 1) / 32.0 * PI
		for point in [Vector3(0, 0.12, 1.82), Vector3(cos(b) * 3.94, 0.22 + sin(b) * 3.52, 1.82), Vector3(cos(a) * 3.94, 0.22 + sin(a) * 3.52, 1.82)]:
			surface.set_normal(Vector3.FORWARD * -1)
			surface.add_vertex(point)
	_mesh(surface.commit(), Vector3.ZERO, _plaster)


func _mesh(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	instance.position = at
	return instance


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(box, at, material)


func _sphere(radius: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.height = 2.0
	sphere.radius = 1.0
	sphere.radial_segments = 20
	sphere.rings = 10
	var instance := _mesh(sphere, at, material)
	instance.scale = radius
	return instance


func _disc(radius: float, depth: float, at: Vector3, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = depth
	cylinder.radial_segments = 32
	var instance := _mesh(cylinder, at, material)
	instance.rotation.x = PI / 2.0
	return instance


func _ring(radius: float, thickness: float, at: Vector3, material: Material) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius - thickness
	ring.outer_radius = radius + thickness
	ring.rings = 24
	ring.ring_segments = 8
	var instance := _mesh(ring, at, material)
	instance.rotation.x = PI / 2.0


func _build_shell() -> void:
	# A smooth barrel vault joins the facade to a broad planted earth roof.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for slice in 6:
		for segment in 24:
			var vertices: Array[Vector3] = []
			for corner in [Vector2(segment, slice), Vector2(segment + 1, slice), Vector2(segment + 1, slice + 1), Vector2(segment, slice + 1)]:
				var angle: float = corner.x / 24.0 * PI
				var z: float = -3.0 + corner.y / 6.0 * 5.15
				vertices.append(Vector3(cos(angle) * 4.1, 0.25 + sin(angle) * (3.7 + 0.2 * cos(z)), z))
			for index in [0, 2, 1, 0, 3, 2]:
				var vertex: Vector3 = vertices[index]
				surface.set_normal(Vector3(vertex.x / (4.1 * 4.1), (vertex.y - 0.25) / (3.7 * 3.7), 0).normalized())
				surface.add_vertex(vertices[index])
	_mesh(surface.commit(), Vector3.ZERO, _grass)
	# Plaster front with rounded shoulders, sitting under the roof's arch.
	_build_facade()
	for side in [-1.0, 1.0]:
		_sphere(Vector3(1.45, 1.35, 2.4), Vector3(side * 3.4, 0.4, -0.3), _grass)
		for stone in 7:
			_sphere(Vector3(0.36, 0.25, 0.25), Vector3(side * (1.3 + stone * 0.45), 0.25, 2.0), _stone)
	# Squat irregular chimney and cap.
	_box(Vector3(0.75, 2.0, 0.7), Vector3(1.85, 3.6, -1.5), _stone)
	_box(Vector3(0.95, 0.18, 0.9), Vector3(1.85, 4.65, -1.5), _stone)
	_box(Vector3(0.55, 0.035, 0.50), Vector3(1.85, 4.75, -1.5), _wood)


func _build_front() -> void:
	var door := _architectural(Color("284b37"), 1)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("976d2e")
	glow.emission_enabled = true
	glow.emission = Color("c28733")
	glow.emission_energy_multiplier = 0.12
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("d4b259")
	brass.metallic = 0.6
	brass.roughness = 0.4
	_disc(1.08, 0.16, Vector3(0, 1.13, 2.0), _wood)
	_disc(0.93, 0.12, Vector3(0, 1.13, 2.12), door)
	_ring(1.02, 0.10, Vector3(0, 1.13, 2.23), _wood)
	for index in range(-3, 4):
		var x := index * 0.23
		var height := sqrt(0.90 * 0.90 - x * x) * 2.0
		_box(Vector3(0.018, height, 0.016), Vector3(x, 1.13, 2.19), _wood)
	_sphere(Vector3.ONE * 0.09, Vector3(0.35, 1.13, 2.29), brass)
	for side in [-1.0, 1.0]:
		var center := Vector3(side * 2.12, 1.72, 1.92)
		_disc(0.52, 0.12, center, glow)
		_ring(0.53, 0.095, center + Vector3(0, 0, 0.1), _wood)
		_box(Vector3(0.055, 0.92, 0.06), center + Vector3(0, 0, 0.12), _wood)
		_box(Vector3(0.92, 0.055, 0.06), center + Vector3(0, 0, 0.12), _wood)
		_box(Vector3(1.3, 0.14, 0.5), center + Vector3(0, -0.61, 0.1), _wood)
		_box(Vector3(0.16, 2.5, 0.18), Vector3(side * 3.05, 1.25, 1.96), _wood)
	# Exposed curved eave frame follows the planted roof.
	for index in 18:
		var a := (index + 0.5) / 18.0 * PI
		var at := Vector3(cos(a) * 3.96, 0.3 + sin(a) * 3.68, 2.20)
		var beam := _box(Vector3(0.75, 0.19, 0.23), at, _wood)
		beam.rotation.z = a - PI / 2.0
	_box(Vector3(2.4, 0.12, 1.0), Vector3(0, 0.06, 2.8), _stone)


func _build_garden() -> void:
	for index in 4:
		var stone := _sphere(Vector3(0.48, 0.07, 0.30), Vector3(sin(index * 1.8) * 0.18, 0.05, 2.2 + index * 0.30), _stone)
		stone.rotation.y = index * 1.7
	for side in [-1.0, 1.0]:
		for index in 4:
			_box(Vector3(0.12, 0.7, 0.13), Vector3(side * (4.3 + index * 0.55), 0.35, 2.2), _wood)
		_box(Vector3(2.2, 0.1, 0.13), Vector3(side * 5.12, 0.52, 2.2), _wood)
		_box(Vector3(2.2, 0.1, 0.13), Vector3(side * 5.12, 0.25, 2.2), _wood)
