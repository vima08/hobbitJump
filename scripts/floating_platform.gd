extends AnimatableBody3D
## A continuous current. Recycling happens beyond the playable stretch of river.

enum Kind { LOG, BARREL }
const LOG_MODEL: PackedScene = preload("res://assets/third_party/kenney_survival/tree-log.glb")
const ArtMaterials = preload("res://scripts/art_materials.gd")
static var _visual_cache: Dictionary = {}
static var _solid_materials: Dictionary = {}

@export var kind: Kind = Kind.LOG
@export var drift_speed: float = 0.55
@export var river_half_length: float = 24.5
@export var lane_center_x: float = 0.0
@export_range(0, 2) var visual_variant: int = 0
var _restore_collision := false


func _ready() -> void:
	sync_to_physics = false
	# Move before CharacterBody3D so its platform velocity is current this tick.
	process_physics_priority = -10
	add_to_group("floating_platforms")
	_build_shape()
	visible = absf(position.x - lane_center_x) < 14.0


func _physics_process(delta: float) -> void:
	if _restore_collision:
		collision_layer = 1
		_restore_collision = false
	position.x += drift_speed * delta
	visible = absf(position.x - lane_center_x) < 14.0
	if position.x - lane_center_x > river_half_length:
		# No collision during recycling outside the playable area.
		collision_layer = 0
		position.x -= river_half_length * 2.0
		reset_physics_interpolation()
		_restore_collision = true


func _build_shape() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 0.6, 1.8) if kind == Kind.LOG else Vector3(2.6, 0.6, 1.8)
	collision.shape = shape
	add_child(collision)
	var cache_key := int(kind) * 3 + visual_variant
	if _visual_cache.has(cache_key):
		for batch in _visual_cache[cache_key]:
			_add_batch(batch.mesh, batch.material)
		return
	if kind == Kind.LOG:
		for z in [-0.57, 0.0, 0.57]:
			var log_body := LOG_MODEL.instantiate() as Node3D
			add_child(log_body)
			log_body.scale = Vector3(2.1, 2.1, 3.0 - (0.25 if visual_variant == 1 and z != 0.0 else 0.0))
			log_body.rotation.y = PI / 2.0
			log_body.position = Vector3(0, -0.06, z)
			_paint_log(log_body)
			_box(Vector3(2.95 - visual_variant * 0.08, 0.06, 0.18), Vector3(0.04 * visual_variant, 0.27, z), Color("ad7a50"))
		for x in [-1.0, 1.0]:
			_box(Vector3(0.12, 0.035, 1.7), Vector3(x, 0.305, 0), Color("bea878"))
	else:
		for x in [-0.65, 0.65]:
			_barrel(x)
		# A flat plank deck matches the deliberately forgiving box collider.
		for plank in range(5):
			_box(Vector3(2.6 - (0.08 if plank % 2 == visual_variant else 0.0), 0.12, 0.345), Vector3(0, 0.24, -0.72 + plank * 0.36), Color("b18050"))
	_batch_visuals()


func _add_batch(mesh: Mesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)


func _batch_visuals() -> void:
	var batches: Dictionary = {}
	var materials: Dictionary = {}
	# Each platform keeps one draw per material, not one per board/hoop/log.
	for node in find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for index in instance.mesh.get_surface_count():
			var material := instance.get_active_material(index)
			var key := material.get_instance_id()
			if not batches.has(key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[key] = surface
				materials[key] = material
			batches[key].append_from(instance.mesh, index, global_transform.affine_inverse() * instance.global_transform)
	for child in get_children():
		if not child is CollisionShape3D:
			child.free()
	var cache_key := int(kind) * 3 + visual_variant
	_visual_cache[cache_key] = []
	for key in batches:
		var mesh: ArrayMesh = batches[key].commit()
		_visual_cache[cache_key].append({"mesh": mesh, "material": materials[key]})
		_add_batch(mesh, materials[key])


func _paint_log(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = ArtMaterials.painted(5, 0.55, Color("9a9d87"))
	for child in node.get_children():
		_paint_log(child)


func _barrel(x: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [0.43, 0.51, 0.55, 0.51, 0.43]
	var depths := [-0.8, -0.57, 0.0, 0.57, 0.8]
	for ring in range(4):
		for side in range(16):
			var a := TAU * side / 16.0
			var b := TAU * (side + 1) / 16.0
			var vertices := [Vector3(cos(a)*radii[ring],sin(a)*radii[ring],depths[ring]), Vector3(cos(b)*radii[ring],sin(b)*radii[ring],depths[ring]), Vector3(cos(b)*radii[ring+1],sin(b)*radii[ring+1],depths[ring+1]), Vector3(cos(a)*radii[ring+1],sin(a)*radii[ring+1],depths[ring+1])]
			for index in [0, 2, 1, 0, 3, 2]:
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	var body := MeshInstance3D.new()
	body.mesh = surface.commit()
	body.material_override = ArtMaterials.painted(1, 0.6, Color("a5a68c"))
	add_child(body)
	body.position = Vector3(x, -0.25, 0)
	for z in [-0.57, 0.57]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.495
		hoop.outer_radius = 0.555
		hoop.rings = 16
		hoop.ring_segments = 6
		var band := _mesh(hoop, Color("4b5047"))
		band.rotation.x = PI / 2
		band.position = Vector3(x, -0.25, z)
	for z in [-0.801, 0.801]:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.43
		cap.bottom_radius = 0.43
		cap.height = 0.025
		cap.radial_segments = 16
		var end := _mesh(cap, Color.WHITE)
		end.material_override = ArtMaterials.painted(4, 0.9, Color("9e9e83"))
		end.rotation.x = PI / 2
		end.position = Vector3(x, -0.25, z)


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	if not _solid_materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		_solid_materials[color] = material
	instance.material_override = _solid_materials[color]
	add_child(instance)
	return instance


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(mesh, color)
	var pigment: Color = [Color("a1a18c"), Color("b3a08b"), Color("8c9d94")][visual_variant]
	instance.material_override = ArtMaterials.painted(1, 0.36 + visual_variant * 0.08, pigment)
	instance.position = at
