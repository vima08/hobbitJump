extends AnimatableBody3D
## A continuous current. Recycling happens beyond the playable stretch of river.

enum Kind { LOG, BARREL }
const LOG_MODEL: PackedScene = preload("res://assets/third_party/kenney_survival/tree-log.glb")
const BARREL_MODEL: PackedScene = preload("res://assets/third_party/kenney_survival/barrel.glb")

@export var kind: Kind = Kind.LOG
@export var drift_speed: float = 0.55
@export var river_half_length: float = 24.5
var _restore_collision := false


func _ready() -> void:
	sync_to_physics = false
	# Move before CharacterBody3D so its platform velocity is current this tick.
	process_physics_priority = -10
	add_to_group("floating_platforms")
	_build_shape()


func _physics_process(delta: float) -> void:
	if _restore_collision:
		collision_layer = 1
		_restore_collision = false
	position.x += drift_speed * delta
	if position.x > river_half_length:
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
	if kind == Kind.LOG:
		for z in [-0.57, 0.0, 0.57]:
			var log_body := LOG_MODEL.instantiate() as Node3D
			add_child(log_body)
			log_body.scale = Vector3(2.1, 2.1, 3.0)
			log_body.rotation.y = PI / 2.0
			log_body.position = Vector3(0, -0.06, z)
			_box(Vector3(3, 0.06, 0.18), Vector3(0, 0.27, z), Color("ad7a50"))
		for x in [-1.0, 1.0]:
			_box(Vector3(0.12, 0.035, 1.7), Vector3(x, 0.305, 0), Color("bea878"))
	else:
		for x in [-0.65, 0.65]:
			var barrel := BARREL_MODEL.instantiate() as Node3D
			add_child(barrel)
			barrel.scale = Vector3(4.8, 4.65, 4.8)
			barrel.rotation.x = PI / 2.0
			barrel.position = Vector3(x, -0.25, -0.8)
		# A flat plank deck matches the deliberately forgiving box collider.
		_box(Vector3(2.6, 0.12, 1.8), Vector3(0, 0.24, 0), Color("b18050"))


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	add_child(instance)
	return instance


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(mesh, color).position = at
