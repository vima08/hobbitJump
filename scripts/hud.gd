extends CanvasLayer

var _status: Label
var _controls: Label
var _pause_panel: PanelContainer
var _resume: Button
var _goal_reached := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title := Label.new()
	title.text = "ХОББИТ: ВНИЗ ПО РЕКЕ"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	_status = Label.new()
	_status.text = "Тренировочная переправа • доберитесь до флажка"
	column.add_child(_status)
	_controls = Label.new()
	_controls.add_theme_font_size_override("font_size", 16)
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_controls)
	var note := Label.new()
	note.text = "Прототип 01 • платформы пока неподвижны"
	note.add_theme_font_size_override("font_size", 16)
	column.add_child(note)
	for label in [title, _status, _controls, note]:
		label.add_theme_color_override("font_shadow_color", Color("203c37"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_panel = PanelContainer.new()
	center.add_child(_pause_panel)
	_pause_panel.custom_minimum_size = Vector2(350, 210)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 16)
	_pause_panel.add_child(menu)
	var heading := Label.new()
	heading.text = "Пауза"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	menu.add_child(heading)
	_resume = Button.new()
	_resume.text = "Продолжить"
	_resume.custom_minimum_size.y = 48
	menu.add_child(_resume)
	_resume.pressed.connect(func() -> void: _set_paused(false))
	var restart := Button.new()
	restart.text = "Начать заново"
	restart.custom_minimum_size.y = 48
	menu.add_child(restart)
	restart.pressed.connect(func() -> void:
		_set_paused(false)
		get_tree().reload_current_scene()
	)
	_resume.focus_neighbor_bottom = _resume.get_path_to(restart)
	_resume.focus_neighbor_top = _resume.get_path_to(restart)
	restart.focus_neighbor_bottom = restart.get_path_to(_resume)
	restart.focus_neighbor_top = restart.get_path_to(_resume)
	_pause_panel.hide()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	get_parent().get_node("Player").respawned.connect(_on_respawned)
	_update_controls()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	_pause_panel.visible = value
	if value:
		_resume.grab_focus()
	else:
		_resume.release_focus()
		get_parent().get_node("Player").suppress_menu_jump()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_controls()


func _update_controls() -> void:
	if Input.get_connected_joypads().is_empty():
		_controls.text = "WASD — движение  •  Пробел — прыжок  •  R — на старт  •  Esc — пауза\nГеймпад: левый стик / крестовина • нижняя кнопка — прыжок • Start — пауза"
	else:
		_controls.text = "Геймпад подключён • левый стик / крестовина — движение\nНижняя кнопка (A / Cross) — прыжок • верхняя (Y / Triangle) — на старт • Start — пауза"


func _on_respawned() -> void:
	_goal_reached = false
	_status.text = "Снова на причале. Доберитесь до флажка!"


func show_goal() -> void:
	if _goal_reached:
		return
	_goal_reached = true
	_status.text = "Переправа пройдена! R / верхняя кнопка — попробовать снова"
