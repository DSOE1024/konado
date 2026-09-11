extends Control

## Reusable dialogue backlog panel for the default Konado dialogue template.

signal closed
## 玩家点击了历史中的某一句；serial 为该条目对应的 VM 提交序号。
signal entry_activated(serial: int)

const HOVER_TINT := Color(1.25, 1.25, 1.25)

@export var entry_container: VBoxContainer
@export var empty_label: Label
@export var close_button: Button
@export var scroll_container: ScrollContainer

var _dialogue_manager: KonadoDialogueManager


func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close_panel)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


func set_dialogue_manager(value: KonadoDialogueManager) -> void:
	_dialogue_manager = value
	if is_node_ready():
		refresh()


func open_panel() -> void:
	refresh()
	visible = true
	_scroll_to_bottom.call_deferred()
	if close_button != null:
		close_button.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func refresh() -> void:
	if entry_container == null:
		return
	for child: Node in entry_container.get_children():
		entry_container.remove_child(child)
		child.queue_free()
	var entries: Array[Dictionary] = []
	if _dialogue_manager != null:
		entries = _dialogue_manager.dialogue_history.entries(0, true)
	if empty_label != null:
		empty_label.visible = entries.is_empty()
	for entry: Dictionary in entries:
		entry_container.add_child(_create_entry_row(entry))


func _create_entry_row(entry: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	match String(entry.get("kind", "dialogue")):
		"choice":
			_build_choice_row(row, entry)
		"screen_text":
			_build_screen_text_row(row, entry)
		_:
			_build_dialogue_row(row, entry)
	_wire_entry_activation(row, int(entry.get("serial", 0)))
	return row


## 整行可点击即“回退到这一句”：只有已提交（serial > 0）的条目可用，当前行与失效条目只作展示。
## 行内文本一律不拦截鼠标，点击由行容器统一处理。
func _wire_entry_activation(row: VBoxContainer, serial: int) -> void:
	row.set_meta("konado_entry_serial", serial)
	if serial <= 0 or _dialogue_manager == null:
		return
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_entry_gui_input.bind(serial))
	row.mouse_entered.connect(func() -> void: row.modulate = HOVER_TINT)
	row.mouse_exited.connect(func() -> void: row.modulate = Color.WHITE)


func _on_entry_gui_input(event: InputEvent, serial: int) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
			_activate_entry(serial)


## 面板只是入口：先确认可回退，再关闭面板并复用「上一句」的原子回退路径。
func _activate_entry(serial: int) -> void:
	if serial <= 0 or _dialogue_manager == null:
		return
	if not _dialogue_manager.timeline.can_rollback_to_entry(serial):
		return
	close_panel()
	if _dialogue_manager.timeline.rollback_to_entry(serial):
		entry_activated.emit(serial)


## 行内文本保持惰性：让整行的点击与悬停都由行容器处理。
func _make_inert(control: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


func _build_dialogue_row(row: VBoxContainer, entry: Dictionary) -> void:
	var speaker := String(entry.get("speaker", ""))
	if not speaker.is_empty():
		var speaker_label := Label.new()
		speaker_label.text = speaker
		speaker_label.add_theme_font_size_override("font_size", 20)
		row.add_child(_make_inert(speaker_label))
	var text_label := RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.text = String(entry.get("text", ""))
	text_label.add_theme_font_size_override("normal_font_size", 24)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_make_inert(text_label))


func _build_choice_row(row: VBoxContainer, entry: Dictionary) -> void:
	var selected := String(entry.get("text", ""))
	var options: Array = entry.get("options", [])
	for option: Variant in options:
		var option_text := String(option)
		var option_label := Label.new()
		option_label.add_theme_font_size_override("font_size", 22)
		option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if option_text == selected:
			option_label.text = "▶ " + option_text
			option_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		else:
			option_label.text = "· " + option_text
			option_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		row.add_child(_make_inert(option_label))
	if options.is_empty() and not selected.is_empty():
		var fallback := Label.new()
		fallback.text = "▶ " + selected
		fallback.add_theme_font_size_override("font_size", 22)
		row.add_child(_make_inert(fallback))


func _build_screen_text_row(row: VBoxContainer, entry: Dictionary) -> void:
	var lines: Array = entry.get("lines", [])
	if lines.is_empty():
		lines = Array(String(entry.get("text", "")).split("\n"))
	for line_value: Variant in lines:
		var line_label := RichTextLabel.new()
		line_label.bbcode_enabled = true
		line_label.fit_content = true
		line_label.scroll_active = false
		line_label.text = String(line_value)
		line_label.add_theme_font_size_override("normal_font_size", 24)
		line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(_make_inert(line_label))


func _scroll_to_bottom() -> void:
	if scroll_container == null:
		return
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
