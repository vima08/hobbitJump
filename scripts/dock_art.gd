extends Node3D
## Decorative deck only. The physical platform owns its unchanged box collider.
@export var size := Vector3(16.0, 0.6, 5.0)
var _surface: SurfaceTool


func _ready() -> void:
	name = "JointedTimberDeck"
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var random := RandomNumberGenerator.new()
	random.seed = 52719 + int(size.x * 100 + size.z * 7)
	var rows := maxi(1, int(ceil(size.z / 0.34)))
	var row_width := size.z / rows
	var top := size.y * 0.5
	var thickness := minf(size.y * 0.42, 0.16)
	for row in rows:
		var z := -size.z * 0.5 + (row + 0.5) * row_width
		var x := -size.x * 0.5
		while x < size.x * 0.5 - 0.02:
			var length := minf(random.randf_range(1.7, 3.25), size.x * 0.5 - x)
			var color := Color("80603d").lerp(Color("ad8959"), random.randf_range(0.0, 1.0))
			_box(Vector3(length - 0.018, thickness, row_width - 0.018), Vector3(x + length * 0.5, top - thickness * 0.5, z), color)
			# Paired dark nail heads at real board ends; all share one mesh surface.
			for end in [-1.0, 1.0]:
				if length > 0.2:
					for offset in [-0.075, 0.075]:
						if random.randf() > 0.2:
							_box(Vector3(0.022, 0.008, 0.022), Vector3(x + length * 0.5 + end * (length * 0.5 - 0.08), top + 0.003, z + offset), Color("373a32"))
			x += length
	# Underlying transverse beams and fascia remain below the collider's top.
	for x in [-size.x * 0.5 + 0.12, size.x * 0.5 - 0.12]:
		_box(Vector3(0.20, size.y * 0.62, size.z), Vector3(x, top - thickness - size.y * 0.31, 0), Color("675039"))
	for z in [-size.z * 0.5 + 0.09, size.z * 0.5 - 0.09]:
		_box(Vector3(size.x, size.y * 0.58, 0.16), Vector3(0, top - thickness - size.y * 0.29, z), Color("735338"))
		for x in [-size.x * 0.5 + 0.25, size.x * 0.5 - 0.25]:
			# Three visible turns of weathered binding around the edge beams.
			for turn in 3:
				_binding(Vector3(x + turn * 0.045, top - thickness - size.y * 0.24, z), Vector2(size.y * 0.27, 0.14))
	var instance := MeshInstance3D.new()
	instance.mesh = _surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/architecture.gdshader")
	material.set_shader_parameter("surface_kind", 1)
	material.set_shader_parameter("vertex_palette", true)
	material.set_shader_parameter("atlas", preload("res://assets/art/woodland-atlas-v1.png"))
	instance.material_override = material
	add_child(instance)
	_surface = null


func _box(dimensions: Vector3, center: Vector3, color: Color) -> void:
	var half := dimensions * 0.5
	for face in [
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP]]:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		for corner in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1)]:
			_surface.set_normal(normal)
			_surface.set_color(color.srgb_to_linear())
			var local: Vector3 = (normal + u * corner.x + v * corner.y) * half
			_surface.set_uv(Vector2(local.z * 0.7 + center.z * 1.21, local.x * 0.22 + center.x * 0.83))
			_surface.add_vertex(center + local)


func _binding(center: Vector3, radius: Vector2) -> void:
	for segment in 12:
		var a := TAU * segment / 12.0
		var b := TAU * (segment + 1) / 12.0
		var first := center + Vector3(0, sin(a) * radius.x, cos(a) * radius.y)
		var second := center + Vector3(0, sin(b) * radius.x, cos(b) * radius.y)
		var direction := second - first
		# Rope facets stay fixed, merged with the rest of the deck.
		var cross := Vector3(0, direction.z, -direction.y).normalized() * 0.014
		var side := Vector3(0.014, 0, 0)
		for corner in 4:
			var offsets := [side, cross, -side, -cross]
			var u: Vector3 = offsets[corner]
			var v: Vector3 = offsets[(corner + 1) % 4]
			for point in [first + u, second + u, second + v, first + u, second + v, first + v]:
				_surface.set_normal((u + v).normalized())
				_surface.set_color(Color("978261").srgb_to_linear())
				_surface.add_vertex(point)
