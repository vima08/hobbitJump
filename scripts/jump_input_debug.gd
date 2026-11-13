extends CanvasLayer
## Opt-in physical-input probe: launch with -- --debug-jump-input.
var player: CharacterBody3D
var _label: Label
var _jump_presses := 0
var _jumps := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	var panel := PanelContainer.new()
	panel.position = Vector2(630, 18)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_label)
	player.jump_input_trace.connect(_log)
	player.jumped.connect(func():
		_jumps += 1
		_log("jump_started")
	)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code not in [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_Z]:
			return
		if event.pressed and code == KEY_Z:
			_jump_presses += 1
		_log("key", {"code": code, "pressed": event.pressed})

func _process(_delta: float) -> void:
	_label.text = "Диагностика прыжка (синтетический ввод ≠ клавиатура)\n↑ %s  → %s  Z %s\nНажатий Z: %d · Прыжков: %d\nОпора: %s · Блокировка меню: %s\nКойот: %.3f · Буфер: %.3f" % [
		Input.is_physical_key_pressed(KEY_UP), Input.is_physical_key_pressed(KEY_RIGHT),
		Input.is_physical_key_pressed(KEY_Z),
		_jump_presses, _jumps, player.is_on_floor(),
		player._jump_blocked, player._coyote_time, player._jump_buffer]

func _log(kind: String, extra: Dictionary = {}) -> void:
	var data := {"kind": kind, "time_us": Time.get_ticks_usec(), "physics_frame": Engine.get_physics_frames(),
		"floor": player.is_on_floor(), "coyote": player._coyote_time, "buffer": player._jump_buffer,
		"blocked": player._jump_blocked, "jump_held": Input.is_action_pressed("jump"),
		"pending": player._jump_request_pending, "event_received": player._jump_event_received,
		"support": str(player.support_body.name) if is_instance_valid(player.support_body) else "none"}
	data.merge(extra)
	print("JUMP_INPUT ", JSON.stringify(data))
