extends Node3D
## Bounded, lightweight feedback. No gameplay collision is added by effects.

const CLIPS := {
	"jump": preload("res://assets/audio/jump.wav"),
	"land": preload("res://assets/audio/land.wav"),
	"splash": preload("res://assets/audio/splash.wav"),
	"checkpoint": preload("res://assets/audio/checkpoint.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
}
const RIVER: AudioStreamWAV = preload("res://assets/audio/river.wav")
var _sounds: Dictionary = {}
var _river: AudioStreamPlayer
var _effects: Array[Dictionary] = []
var _shutting_down := false


func _ready() -> void:
	for clip in CLIPS:
		var sound := AudioStreamPlayer.new()
		sound.name = clip.capitalize() + "Sound"
		sound.stream = CLIPS[clip]
		sound.volume_db = -10 if clip != "land" else -16
		# The victory melody must finish after the game has frozen.
		if clip == "victory":
			sound.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(sound)
		_sounds[clip] = sound
	_river = AudioStreamPlayer.new()
	_river.name = "RiverAmbience"
	var loop := RIVER.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_river.stream = loop
	_river.volume_db = -12
	add_child(_river)
	_river.play()
	var player := get_parent().get_node("Player")
	player.jumped.connect(func() -> void: _play("jump"))
	player.landed.connect(_on_landed)
	player.fell_into_water.connect(_on_splash)
	var hud := get_parent().get_node("HUD")
	hud.checkpoint_celebrated.connect(func() -> void: _play("checkpoint"))
	hud.victory_celebrated.connect(func() -> void: _play("victory"))


func _exit_tree() -> void:
	# Release active WAV playbacks explicitly, including when exiting while paused.
	for sound in _sounds.values():
		sound.stop()
		sound.stream = null
	if is_instance_valid(_river):
		_river.stop()
		_river.stream = null


func prepare_shutdown() -> void:
	_shutting_down = true
	for sound in _sounds.values():
		sound.stop()
		sound.stream = null
	_river.stop()
	_river.stream = null
	# Godot's audio thread must consume stop commands before the engine exits.
	# Use wall time: fixed-fps simulation can advance timers faster than audio.
	var deadline := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _play(clip: String) -> void:
	if not _shutting_down:
		_sounds[clip].play()


func _on_landed(at: Vector3) -> void:
	_play("land")
	_ring(at + Vector3(0, 0.025, 0), Color("d3bf8d"), 0.26, 0.45)


func _on_splash(at: Vector3) -> void:
	_play("splash")
	_ring(Vector3(at.x, -0.69, at.z), Color("a9dde0"), 0.65, 1.2)
	_ring(Vector3(at.x, -0.68, at.z), Color("d4edef"), 0.45, 0.8)
	for index in range(10):
		var angle := float(index) * TAU / 10.0
		var drop := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.045
		mesh.height = 0.14
		mesh.radial_segments = 6
		mesh.rings = 3
		drop.mesh = mesh
		drop.material_override = _material(Color("c3e9e8"))
		add_child(drop)
		drop.global_position = Vector3(at.x, -0.67, at.z)
		_effects.append({"node": drop, "age": 0.0, "life": 0.55, "velocity": Vector3(cos(angle) * 1.2, 2.4, sin(angle) * 1.2), "radius": 0.0})


func _ring(at: Vector3, color: Color, life: float, radius: float) -> void:
	# Finite geometry, not transparent quads: no sorting artefacts over the water.
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.88
	mesh.outer_radius = 1.0
	mesh.rings = 20
	mesh.ring_segments = 4
	ring.mesh = mesh
	ring.material_override = _material(color)
	add_child(ring)
	ring.global_position = at
	ring.scale = Vector3(0.12, 0.035, 0.12)
	_effects.append({"node": ring, "age": 0.0, "life": life, "velocity": Vector3.ZERO, "radius": radius})


func _physics_process(delta: float) -> void:
	for index in range(_effects.size() - 1, -1, -1):
		var effect := _effects[index]
		effect.age += delta
		if effect.age >= effect.life:
			effect.node.queue_free()
			_effects.remove_at(index)
			continue
		var u: float = effect.age / effect.life
		if effect.radius > 0:
			var radius: float = lerpf(0.12, effect.radius, u)
			effect.node.scale = Vector3(radius, 0.035 * (1 - u), radius)
		else:
			effect.velocity.y -= delta * 9.0
			effect.node.position += effect.velocity * delta


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
