extends SceneTree
class Walker extends CharacterBody3D:
	var locomotion_velocity := Vector3.ZERO
	var support_body: Node3D
	var age := 0.0
	func _physics_process(delta: float) -> void:
		age += delta
		var old := global_position
		velocity = Vector3(0, -0.1, 3.0 if age > 0.5 and age < 2.5 else 0.0)
		move_and_slide()
		locomotion_velocity = (global_position - old) / delta
		locomotion_velocity.y = 0
var body: Walker
var age := 0
var max_error := 0.0
func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	shape.shape = box
	floor_body.position.y = -0.1
	floor_body.add_child(shape)
	world.add_child(floor_body)
	body = Walker.new()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.15
	capsule.radius = 0.2
	collider.shape = capsule
	collider.position.y = 0.575
	body.add_child(collider)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_script(load("res://scripts/hero_visual.gd"))
	body.add_child(visual)
	world.add_child(body)
func _physics_process(_delta: float) -> bool:
	age += 1
	if age > 2:
		var debug: Dictionary = body.get_node("Visual").gait_debug()
		for foot in debug.feet:
			if foot.stance:
				max_error = maxf(max_error, foot.contact_error)
		if age % 30 == 0:
			print("GAIT ", age, " ", debug)
	if age > 200:
		print("MAX_CONTACT_ERROR ", max_error)
		quit()
	return false
