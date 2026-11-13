extends CharacterBody3D

signal respawned
signal jumped
signal jump_input_trace(kind: String)
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
var _jump_request_pending := false
var _jump_event_received := false
var _debug_jump_input := false
var _airborne_time := 0.0
var _respawn_timer := 0.0
## Actual movement relative to the carrier, used by planted-foot animation.
var locomotion_velocity := Vector3.ZERO
var support_body: Node3D
var _support_transform := Transform3D.IDENTITY
@onready var visual: Node3D = $Visual


func _ready() -> void:
	if "--debug-jump-input" in OS.get_cmdline_user_args():
		_debug_jump_input = true
		var probe := preload("res://scripts/jump_input_debug.gd").new()
		probe.player = self
		add_child(probe)


func _input(event: InputEvent) -> void:
	if not event.is_action("jump"):
		return
	_jump_event_received = true
	if event.is_action_released("jump") and not Input.is_action_pressed("jump"):
		_jump_blocked = false
	elif event.is_action_pressed("jump") and not _jump_blocked and _respawn_timer <= 0.0:
		# Keep a fresh press even when release/repress occurs between physics ticks.
		_jump_request_pending = true
		_trace_jump("request_pending")
	elif event.is_action_pressed("jump"):
		_trace_jump("request_blocked_menu" if _jump_blocked else "request_blocked_respawn")


func _trace_jump(kind: String) -> void:
	if _debug_jump_input:
		jump_input_trace.emit(kind)


func _physics_process(delta: float) -> void:
	if _respawn_timer > 0.0:
		locomotion_velocity = Vector3.ZERO
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
	# Polling also supports Input.action_press() automation; a delivered event is
	# authoritative so releasing a menu-confirm key cannot replay its stale press.
	var jump_requested := _jump_request_pending or (not _jump_event_received and Input.is_action_just_pressed("jump") and not _jump_blocked)
	_jump_request_pending = false
	_jump_event_received = false
	var previous_buffer := _jump_buffer
	_jump_buffer = 0.12 if jump_requested else maxf(0.0, _jump_buffer - delta)
	if jump_requested:
		_trace_jump("buffer_queued")
	elif previous_buffer > 0.0 and _jump_buffer == 0.0:
		_trace_jump("buffer_expired")
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _jump_buffer > 0.0 and _coyote_time > 0.0:
		velocity.y = jump_speed
		_coyote_time = 0.0
		_jump_buffer = 0.0
		_trace_jump("buffer_consumed")
		jumped.emit()
	var before := global_position
	var carrier_delta := Vector3.ZERO
	if is_instance_valid(support_body):
		carrier_delta = support_body.global_transform * (_support_transform.affine_inverse() * before) - before
	move_and_slide()
	locomotion_velocity = (global_position - before - carrier_delta) / delta
	locomotion_velocity.y = 0.0
	support_body = null
	if is_on_floor():
		for index in get_slide_collision_count():
			var contact := get_slide_collision(index)
			if contact.get_normal().dot(up_direction) > 0.7:
				support_body = contact.get_collider() as Node3D
				break
	if is_instance_valid(support_body):
		_support_transform = support_body.global_transform
	if is_on_floor():
		if not was_grounded and _airborne_time > 0.12:
			landed.emit(global_position)
		_airborne_time = 0.0
	else:
		_airborne_time += delta

	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-14.0 * delta))
	# Past the visible crest, let the player and carrier fall into the gorge first.
	var water_height := -5.0 if global_position.x > 22.0 else fall_reset_height
	if global_position.y < water_height:
		fell_into_water.emit(global_position)
		_respawn_timer = 0.42
		velocity = Vector3.ZERO
		visual.hide()
	elif Input.is_action_just_pressed("restart"):
		respawn()


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	locomotion_velocity = Vector3.ZERO
	support_body = null
	_coyote_time = 0.0
	_jump_buffer = 0.0
	_jump_request_pending = false
	_jump_event_received = true
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
	_jump_request_pending = false
	_jump_event_received = true
