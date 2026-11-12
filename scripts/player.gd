extends CharacterBody3D

signal respawned
signal jumped
signal landed(at: Vector3)
signal fell_into_water(at: Vector3)

@export var move_speed: float = 4.8
@export var acceleration: float = 32.0
@export var jump_speed: float = 7.5
@export var gravity: float = 20.0
@export var fall_reset_height: float = -1.0
@export var camera: Camera3D

var spawn_position: Vector3 = Vector3(0, 0.05, 4.5)
var _coyote_time: float = 0.0
var _jump_buffer: float = 0.0
var _jump_blocked: bool = false
var _airborne_time := 0.0
var _respawn_timer := 0.0
@onready var visual: Node3D = $Visual


func _physics_process(delta: float) -> void:
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			respawn()
		return
	var was_grounded := is_on_floor()
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var right := Vector3.RIGHT
	var back := Vector3.BACK
	if is_instance_valid(camera):
		right = camera.global_basis.x
		back = camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		right = right.normalized()
		back = back.normalized()
	var direction := right * input_vector.x + back * input_vector.y
	velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)

	_coyote_time = 0.10 if is_on_floor() else maxf(0.0, _coyote_time - delta)
	if not Input.is_action_pressed("jump"):
		_jump_blocked = false
	_jump_buffer = 0.12 if Input.is_action_just_pressed("jump") and not _jump_blocked else maxf(0.0, _jump_buffer - delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _jump_buffer > 0.0 and _coyote_time > 0.0:
		velocity.y = jump_speed
		_coyote_time = 0.0
		_jump_buffer = 0.0
		jumped.emit()
	move_and_slide()
	if is_on_floor():
		if not was_grounded and _airborne_time > 0.12:
			landed.emit(global_position)
		_airborne_time = 0.0
	else:
		_airborne_time += delta

	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-14.0 * delta))
	if global_position.y < fall_reset_height:
		fell_into_water.emit(global_position)
		_respawn_timer = 0.42
		velocity = Vector3.ZERO
		visual.hide()
	elif absf(global_position.x) > 20.0 or Input.is_action_just_pressed("restart"):
		respawn()


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	_coyote_time = 0.0
	_jump_buffer = 0.0
	_airborne_time = 0.0
	_respawn_timer = 0.0
	visual.show()
	reset_physics_interpolation()
	respawned.emit()


func set_checkpoint(at: Vector3) -> void:
	spawn_position = at


func suppress_menu_jump() -> void:
	# A / Cross also confirms menu buttons; resuming must not start a jump.
	_jump_buffer = 0.0
	_jump_blocked = true
