@tool
extends Control
class_name KS_JumpLinkOverlay

## Semantic links and hover information for KonadoScript in Godot's native CodeEdit.
##
## ScriptLanguageExtension lookup is limited to Script resources and Godot treats
## path separators as word boundaries. This controller resolves complete semantic
## spans itself and can open scenes, resources, audio files, KonadoScript files or
## local declarations while leaving non-KonadoScript editors untouched.

const LOCAL_KINDS := ["branches", "variables", "signals"]
const RESOURCE_KINDS := [
	"actors",
	"backgrounds",
	"bgms",
	"sfx",
	"voices",
	"states",
	"motions",
	"cameras",
	"scripts",
]

var _code_edit: CodeEdit
var _project_index := KS_ProjectIndex.shared()
var _hover_span := {}
var _hover_reference := {}
var _original_tooltip := ""
var _original_cursor_shape := Control.CURSOR_IBEAM
var _original_symbol_lookup_enabled := false
var _original_symbol_tooltip_enabled := false
var _target_menu: PopupMenu
var _menu_targets: Array[Dictionary] = []


func setup(code_edit: CodeEdit) -> void:
	_code_edit = code_edit
	name = "KonadoJumpLinkOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_original_tooltip = _code_edit.tooltip_text
	_original_cursor_shape = _code_edit.mouse_default_cursor_shape
	_original_symbol_lookup_enabled = _code_edit.is_symbol_lookup_on_click_enabled()
	_original_symbol_tooltip_enabled = _code_edit.is_symbol_tooltip_on_hover_enabled()
	# Godot's native lookup works on lexical words instead of KonadoScript semantic
	# spans. It can underline a complete quoted dialogue or a single directory
	# inside a resource path, so semantic links are exclusively owned here.
	_code_edit.set_symbol_lookup_on_click_enabled(false)
	_code_edit.set_symbol_tooltip_on_hover_enabled(false)
	_code_edit.gui_input.connect(_on_code_edit_gui_input)
	_code_edit.mouse_exited.connect(_clear_reference)
	_code_edit.text_changed.connect(_on_text_changed)
	_code_edit.get_h_scroll_bar().value_changed.connect(_on_view_changed)
	_code_edit.get_v_scroll_bar().value_changed.connect(_on_view_changed)
	_code_edit.resized.connect(_on_view_changed)


func cleanup() -> void:
	if is_instance_valid(_target_menu):
		_target_menu.queue_free()
	_target_menu = null
	_menu_targets.clear()
	if not is_instance_valid(_code_edit):
		_code_edit = null
		return
	if _code_edit.gui_input.is_connected(_on_code_edit_gui_input):
		_code_edit.gui_input.disconnect(_on_code_edit_gui_input)
	if _code_edit.mouse_exited.is_connected(_clear_reference):
		_code_edit.mouse_exited.disconnect(_clear_reference)
	if _code_edit.text_changed.is_connected(_on_text_changed):
		_code_edit.text_changed.disconnect(_on_text_changed)
	if _code_edit.get_h_scroll_bar().value_changed.is_connected(_on_view_changed):
		_code_edit.get_h_scroll_bar().value_changed.disconnect(_on_view_changed)
	if _code_edit.get_v_scroll_bar().value_changed.is_connected(_on_view_changed):
		_code_edit.get_v_scroll_bar().value_changed.disconnect(_on_view_changed)
	if _code_edit.resized.is_connected(_on_view_changed):
		_code_edit.resized.disconnect(_on_view_changed)
	_code_edit.set_symbol_lookup_on_click_enabled(_original_symbol_lookup_enabled)
	_code_edit.set_symbol_tooltip_on_hover_enabled(_original_symbol_tooltip_enabled)
	_code_edit.tooltip_text = _original_tooltip
	_code_edit.mouse_default_cursor_shape = _original_cursor_shape
	_code_edit = null
	_hover_span.clear()
	_hover_reference.clear()


func get_hover_span() -> Dictionary:
	return _hover_span.duplicate(true)


func resolve_navigation_targets(reference: Dictionary, source: String) -> Array[Dictionary]:
	var kind := String(reference.get("kind", ""))
	var name := String(reference.get("name", ""))
	if kind in LOCAL_KINDS:
		var line := KS_SymbolIndex.find_local_definition(source, kind, name)
		if line < 0:
			return []
		return [
			{
				"kind": kind,
				"name": name,
				"line": line,
				"path": "",
			}
		]
	if kind == "scripts":
		if FileAccess.file_exists(name):
			return [{"kind": kind, "name": name, "line": 1, "path": name}]
		return []
	if kind not in RESOURCE_KINDS:
		return []
	var targets: Array[Dictionary]
	if kind in ["states", "motions"]:
		targets = (
			_project_index
			. get_actor_scoped_targets(
				String(reference.get("scope_name", "")),
				kind,
				name,
			)
		)
	else:
		targets = _project_index.get_navigation_targets(kind, name)
	var existing: Array[Dictionary] = []
	for target: Dictionary in targets:
		var target_path := String(target.get("path", ""))
		if not target_path.is_empty() and FileAccess.file_exists(target_path):
			existing.append(target)
	return existing


func get_reference_tooltip(reference: Dictionary) -> String:
	var kind := String(reference.get("kind", ""))
	var name := String(reference.get("name", ""))
	if kind == "commands":
		var signature := KS_LanguageCatalog.get_signature(name)
		var description := (
			KS_LanguageCatalog
			. get_command_description(
				name,
				KS_EditorLocale.get_editor_locale(),
			)
		)
		return signature if description.is_empty() else "%s\n%s" % [signature, description]
	if kind == "effects":
		return (
			KS_EditorLocale
			. text(
				"Background transition: %s" % name,
				"背景转场：%s" % name,
			)
		)
	var targets := resolve_navigation_targets(reference, _code_edit.text if _code_edit else "")
	if targets.is_empty():
		return (
			KS_EditorLocale
			. text(
				"Unresolved %s: %s" % [_kind_label(kind, false), name],
				"未解析的%s：%s" % [_kind_label(kind, true), name],
			)
		)
	if targets.size() == 1:
		var target := targets[0]
		var path := String(target.get("path", ""))
		if path.is_empty():
			return (
				KS_EditorLocale
				. text(
					(
						"%s '%s', declared on line %d"
						% [_kind_label(kind, false), name, int(target.get("line", 1))]
					),
					(
						"%s“%s”，声明于第 %d 行"
						% [_kind_label(kind, true), name, int(target.get("line", 1))]
					),
				)
			)
		return (
			KS_EditorLocale
			. text(
				"%s '%s'\n%s" % [_kind_label(kind, false), name, path],
				"%s“%s”\n%s" % [_kind_label(kind, true), name, path],
			)
		)
	return (
		KS_EditorLocale
		. text(
			(
				"%s '%s' has %d targets; Ctrl/Command-click to choose."
				% [_kind_label(kind, false), name, targets.size()]
			),
			(
				"%s“%s”有 %d 个目标；按住 Ctrl/Command 点击以选择。"
				% [_kind_label(kind, true), name, targets.size()]
			),
		)
	)


func _on_code_edit_gui_input(event: InputEvent) -> void:
	if not is_instance_valid(_code_edit):
		return
	if event is InputEventMouseMotion:
		_update_reference(event.position, event.is_command_or_control_pressed())
		return
	if event is InputEventKey and event.keycode in [KEY_CTRL, KEY_META]:
		_update_reference(
			_code_edit.get_local_mouse_position(),
			event.is_command_or_control_pressed(),
		)
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.is_command_or_control_pressed()
	):
		_update_reference(event.position, true)
		if _hover_span.is_empty():
			return
		var targets := resolve_navigation_targets(_hover_reference, _code_edit.text)
		if targets.is_empty():
			return
		_code_edit.accept_event()
		if targets.size() == 1:
			_open_target.call_deferred(targets[0])
		else:
			_show_target_menu.call_deferred(targets, event.global_position)


func _update_reference(mouse_position: Vector2, modifier_pressed: bool) -> void:
	var position := _code_edit.get_line_column_at_pos(mouse_position, false, false)
	if position.y < 0 or position.x < 0:
		_clear_reference()
		return
	var reference := (
		KS_SymbolIndex
		. get_semantic_reference_at(
			_code_edit.get_line(position.y),
			position.x,
			KS_SymbolIndex.is_screentext_content_line(_code_edit.text, position.y),
		)
	)
	if not reference.is_empty():
		reference["line"] = position.y
	_hover_reference = reference
	_code_edit.tooltip_text = (
		get_reference_tooltip(reference) if not reference.is_empty() else _original_tooltip
	)
	var span := {}
	if modifier_pressed and not resolve_navigation_targets(reference, _code_edit.text).is_empty():
		span = reference.duplicate(true)
	if span == _hover_span:
		return
	_hover_span = span
	_code_edit.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not span.is_empty() else _original_cursor_shape
	)
	queue_redraw()


func _clear_reference() -> void:
	_hover_reference.clear()
	if is_instance_valid(_code_edit):
		_code_edit.tooltip_text = _original_tooltip
		_code_edit.mouse_default_cursor_shape = _original_cursor_shape
	if _hover_span.is_empty():
		return
	_hover_span.clear()
	if is_instance_valid(_code_edit):
		queue_redraw()


func _on_text_changed() -> void:
	_clear_reference()


func _on_view_changed(_value: Variant = null) -> void:
	if not _hover_span.is_empty():
		queue_redraw()


func _show_target_menu(targets: Array[Dictionary], global_position: Vector2) -> void:
	_ensure_target_menu()
	_target_menu.clear()
	_menu_targets = targets
	for index: int in targets.size():
		var target := targets[index]
		var path := String(target.get("path", ""))
		var owner := String(target.get("owner_path", ""))
		var label := path if owner.is_empty() or owner == path else "%s  (%s)" % [path, owner]
		_target_menu.add_item(label, index)
	_target_menu.position = Vector2i(global_position)
	_target_menu.popup()


func _ensure_target_menu() -> void:
	if is_instance_valid(_target_menu):
		return
	_target_menu = PopupMenu.new()
	_target_menu.name = "KonadoNavigationTargets"
	_target_menu.id_pressed.connect(_on_target_selected)
	EditorInterface.get_base_control().add_child(_target_menu)


func _on_target_selected(index: int) -> void:
	if index < 0 or index >= _menu_targets.size():
		return
	_open_target(_menu_targets[index])


func _open_target(target: Dictionary) -> void:
	var path := String(target.get("path", ""))
	if path.is_empty():
		_go_to_local_line(int(target.get("line", 1)))
		return
	if not FileAccess.file_exists(path):
		push_error("Unable to open KonadoScript semantic target: %s" % path)
		return
	match path.get_extension().to_lower():
		"ks":
			var script := ResourceLoader.load(path, "Script") as Script
			if script != null:
				EditorInterface.edit_script(script, maxi(1, int(target.get("line", 1))))
				_schedule_filesystem_selection(path)
		"tscn":
			EditorInterface.open_scene_from_path(path)
			_focus_open_scene_editor.call_deferred()
		_:
			var resource := ResourceLoader.load(path)
			if resource != null:
				EditorInterface.edit_resource(resource)


func _schedule_filesystem_selection(
	path: String,
	navigator: Callable = Callable(),
) -> void:
	if not navigator.is_valid():
		var filesystem_dock := EditorInterface.get_file_system_dock()
		if filesystem_dock == null:
			return
		navigator = Callable(filesystem_dock, "navigate_to_path")
	navigator.call_deferred(path)


func _focus_open_scene_editor() -> void:
	var base_control := EditorInterface.get_base_control()
	if base_control != null and base_control.get_tree() != null:
		await base_control.get_tree().process_frame
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	var main_screen := "3D" if scene_root is Node3D else "2D"
	EditorInterface.set_main_screen_editor(main_screen)
	var selection := EditorInterface.get_selection()
	if selection != null:
		selection.clear()
		selection.add_node(scene_root)


func _go_to_local_line(line_number: int) -> void:
	if not is_instance_valid(_code_edit):
		return
	var line := clampi(line_number - 1, 0, _code_edit.get_line_count() - 1)
	_code_edit.set_caret_line(line)
	_code_edit.set_caret_column(0)
	_code_edit.center_viewport_to_caret()
	_code_edit.grab_focus()


func _kind_label(kind: String, chinese: bool) -> String:
	var labels := {
		"actors": ["actor", "角色"],
		"backgrounds": ["background", "背景"],
		"bgms": ["BGM", "背景音乐"],
		"sfx": ["sound effect", "音效"],
		"voices": ["voice", "语音"],
		"states": ["actor state", "角色状态"],
		"motions": ["actor motion", "演员动作"],
		"cameras": ["camera setup", "镜头配置"],
		"scripts": ["KonadoScript", "剧本"],
		"branches": ["branch", "分支"],
		"variables": ["variable", "变量"],
		"signals": ["signal", "信号"],
	}
	var label: Array = labels.get(kind, [kind, kind])
	return String(label[1] if chinese else label[0])


func _draw() -> void:
	if _hover_span.is_empty() or not is_instance_valid(_code_edit):
		return
	var line := int(_hover_span["line"])
	var start_column := int(_hover_span["start"])
	var end_column := int(_hover_span["end"])
	var color := _code_edit.get_theme_color("font_color")
	var font := _code_edit.get_theme_font("font")
	var font_size := _code_edit.get_theme_font_size("font_size")
	var line_spacing := _code_edit.get_theme_constant("line_spacing")
	var thickness := maxf(1.0, font.get_underline_thickness(font_size))
	var segment_start := Vector2.ZERO
	var segment_end := Vector2.ZERO
	var segment_y := -1.0
	for column: int in range(start_column, end_column):
		var rect := _get_character_rect(line, column)
		if rect.position.x < 0:
			continue
		var underline_y := (
			float(rect.position.y)
			+ float(line_spacing) / 2.0
			+ ceilf(font.get_ascent(font_size))
			+ ceilf(font.get_underline_position(font_size))
		)
		var character_start := minf(float(rect.position.x), float(rect.end.x))
		var character_end := maxf(float(rect.position.x), float(rect.end.x))
		var starts_new_segment := (
			segment_y < 0.0
			or not is_equal_approx(segment_y, underline_y)
			or character_start > segment_end.x + 1.0
			or character_end < segment_start.x - 1.0
		)
		if starts_new_segment:
			if segment_y >= 0.0:
				draw_line(segment_start, segment_end, color, thickness)
			segment_y = underline_y
			segment_start = Vector2(character_start, underline_y)
			segment_end = Vector2(character_end, underline_y)
		else:
			segment_start.x = minf(segment_start.x, character_start)
			segment_end.x = maxf(segment_end.x, character_end)
	if segment_y >= 0.0:
		draw_line(segment_start, segment_end, color, thickness)


func _get_character_rect(line: int, column: int) -> Rect2i:
	# TextEdit columns describe caret boundaries. At a boundary, Godot returns the
	# preceding grapheme, so the visible character at zero-based `column` is
	# represented by the boundary immediately after it.
	var line_length := _code_edit.get_line(line).length()
	if column < 0 or column >= line_length:
		return Rect2i(-1, -1, 0, 0)
	return _code_edit.get_rect_at_line_column(line, column + 1)
