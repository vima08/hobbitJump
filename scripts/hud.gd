extends CanvasLayer

var _status: Label
var _controls: Label
var _note: Label
var _pause_panel: PanelContainer
var _victory_panel: PanelContainer
var _victory_details: Label
var _resume: Button
var _victory_restart: Button
var _goal_reached := false
var _checkpoint_reached := false
var _elapsed_seconds := 0.0
var _returns := 0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.position = Vector2(20, 16)
	margin.custom_minimum_size.x = 420
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	margin.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(0.76))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Хоббит: вниз по реке"
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 17)
	column.add_child(_status)
	_controls = Label.new()
	_controls.add_theme_font_size_override("font_size", 15)
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls.custom_minimum_size.x = 400
	column.add_child(_controls)
	_note = Label.new()
	_note.text = "Течение вправо → · скорости рядов различаются."
	_note.add_theme_font_size_override("font_size", 14)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)

	_pause_panel = _center_panel(root)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 16)
	_pause_panel.add_child(menu)
	var heading := _label("Пауза", 30)
	menu.add_child(heading)
	_resume = _button("Продолжить")
	menu.add_child(_resume)
	_resume.pressed.connect(func() -> void: _set_paused(false))
	var restart := _button("Начать заново")
	menu.add_child(restart)
	restart.pressed.connect(restart_run)
	menu.add_child(_label("Esc / Start — продолжить\nR / Y / Triangle — начать заново", 15))
	_link_focus(_resume, restart)
	_link_focus(restart, _resume)
	_pause_panel.hide()

	_victory_panel = _center_panel(root)
	var victory := VBoxContainer.new()
	victory.add_theme_constant_override("separation", 18)
	_victory_panel.add_child(victory)
	victory.add_child(_label("Другой берег!", 30))
	victory.add_child(_label("Хоббит благополучно завершил переправу.", 18))
	_victory_details = _label("", 21)
	victory.add_child(_victory_details)
	_victory_restart = _button("Начать заново")
	victory.add_child(_victory_restart)
	_victory_restart.pressed.connect(restart_run)
	_link_focus(_victory_restart, _victory_restart)
	victory.add_child(_label("Enter / A / Cross — выбрать\nR / Y / Triangle — начать заново", 15))
	_victory_panel.hide()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	get_parent().get_node("Player").respawned.connect(_on_respawned)
	_update_controls()
	_update_status()


func _process(delta: float) -> void:
	if not get_tree().paused and not _goal_reached:
		_elapsed_seconds += delta
		_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if not _goal_reached:
			_set_paused(not get_tree().paused)
	elif event.is_action_pressed("restart") and get_tree().paused:
		get_viewport().set_input_as_handled()
		restart_run()


func _set_paused(value: bool) -> void:
	if _goal_reached:
		get_tree().paused = true
		_pause_panel.hide()
		_victory_panel.show()
		_victory_restart.grab_focus()
		return
	get_tree().paused = value
	_pause_panel.visible = value
	_victory_panel.hide()
	if value:
		_resume.grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		get_parent().get_node("Player").suppress_menu_jump()


func show_checkpoint() -> void:
	if _goal_reached:
		return
	_checkpoint_reached = true
	_note.text = "Контрольный причал достигнут. Теперь возвращаемся сюда."
	_update_status()


func show_goal() -> void:
	if _goal_reached:
		return
	_goal_reached = true
	_status.text = "Вы добрались до другого берега!"
	_controls.hide()
	_note.hide()
	_victory_details.text = "Время: %s\nВозвраты на причал: %d" % [_format_time(), _returns]
	_set_paused(true)


func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_respawned() -> void:
	if not _goal_reached:
		_returns += 1
		_update_status()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_controls()


func _update_controls() -> void:
	if Input.get_connected_joypads().is_empty():
		_controls.text = "Стрелки / WASD — движение · Пробел — прыжок\nR — на причал · Esc — пауза"
	else:
		_controls.text = "Стик / крестовина — движение · A / Cross — прыжок\nY / Triangle — на причал · Start — пауза"


func _update_status() -> void:
	if not _goal_reached:
		var target := "Доберитесь до контрольного причала."
		if _checkpoint_reached:
			target = "Доберитесь до финишного причала."
		_status.text = "%s\nВремя: %s · Возвраты: %d" % [target, _format_time(), _returns]


func _format_time() -> String:
	var total := int(_elapsed_seconds)
	return "%02d:%02d" % [int(total / 60.0), total % 60]


func _center_panel(root: Control) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(0.97))
	center.add_child(panel)
	return panel


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 21)
	return button


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label


func _link_focus(button: Button, other: Button) -> void:
	button.focus_neighbor_top = button.get_path_to(other)
	button.focus_neighbor_bottom = button.get_path_to(other)
	button.focus_neighbor_left = button.get_path_to(other)
	button.focus_neighbor_right = button.get_path_to(other)


func _panel_style(opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.09, 0.075, opacity)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
