extends Node3D
## Visual animation only: the character collision and platform motion stay separate.

const MODEL: PackedScene = preload("res://assets/characters/hobbit.glb")
var _phase := 0.0
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _torso: Node3D


func _ready() -> void:
	var model := MODEL.instantiate() as Node3D
	add_child(model)
	_left_leg = model.find_child("LegLeft", true, false)
	_right_leg = model.find_child("LegRight", true, false)
	_left_arm = model.find_child("ArmLeft", true, false)
	_right_arm = model.find_child("ArmRight", true, false)
	_torso = model.find_child("Torso", true, false)


func _physics_process(delta: float) -> void:
	var player := get_parent() as CharacterBody3D
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var walking := clampf(speed / player.move_speed, 0, 1) if player.is_on_floor() else 0.0
	_phase += speed * delta * 2.9
	var stride := sin(_phase) * 0.55 * walking
	var blend := 1.0 - exp(-18.0 * delta)
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, stride, blend)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -stride, blend)
	var air_pose := 0.0 if player.is_on_floor() else -0.7
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -stride + air_pose, blend)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, stride + air_pose, blend)
	_torso.position.y = absf(sin(_phase)) * 0.025 * walking
	_torso.rotation.z = sin(_phase) * 0.035 * walking
