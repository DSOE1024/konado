@tool
extends EditorContextMenuPlugin
class_name KS_CodeContextMenu

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

var _active_symbol := ""
var _active_kind := "branches"
var _active_scope := ""
var _active_path := ""
var _active_code_edit: CodeEdit
var _project_index := KS_ProjectIndex.shared()
var _reference_dialog: AcceptDialog
var _reference_list: ItemList
var _reference_lines := PackedInt32Array()
var _reference_locations: Array[Dictionary] = []
var _rename_dialog: ConfirmationDialog
var _rename_input: LineEdit
var _rename_error: Label


func _popup_menu(paths: PackedStringArray) -> void:
	var code_edit := _resolve_code_edit(paths)
	if not _is_konado_editor(code_edit):
		return
	var line := code_edit.get_caret_line()
	var column := code_edit.get_caret_column()
	var reference := (
		KS_SymbolIndex
		. get_semantic_reference_at(
			code_edit.get_line(line),
			column,
			KS_SymbolIndex.is_screentext_content_line(code_edit.text, line),
		)
	)
	var kind := String(reference.get("kind", ""))
	if kind not in LOCAL_KINDS and kind not in RESOURCE_KINDS:
		return
	_active_symbol = String(reference.get("name", ""))
	_active_kind = kind
	_active_scope = String(reference.get("scope_name", ""))
	_active_code_edit = code_edit
	var current_script := EditorInterface.get_script_editor().get_current_script()
	_active_path = current_script.resource_path if current_script != null else ""
	add_context_menu_item(
		KS_EditorLocale.text("Go to Definition", "转到定义"),
		_go_to_definition,
	)
	add_context_menu_item(
		KS_EditorLocale.text("Find References", "查找引用"),
		_find_references,
	)
	if kind in LOCAL_KINDS:
		add_context_menu_item(
			KS_EditorLocale.text("Rename Symbol...", "重命名符号……"),
			_rename_symbol,
		)


func cleanup() -> void:
	for dialog: Window in [_reference_dialog, _rename_dialog]:
		if dialog != null and is_instance_valid(dialog):
			dialog.queue_free()
	_reference_dialog = null
	_rename_dialog = null
	_active_code_edit = null


func _go_to_definition(_context: Variant) -> void:
	if not _has_active_editor():
		return
	if _active_kind in LOCAL_KINDS:
		var line := (
			KS_SymbolIndex
			. find_local_definition(
				_active_code_edit.text,
				_active_kind,
				_active_symbol,
			)
		)
		if line >= 0:
			_focus_code_line(_active_code_edit, line, _active_symbol)
		return
	var targets: Array[Dictionary]
	if _active_kind in ["states", "motions"]:
		targets = (
			_project_index
			. get_actor_scoped_targets(
				_active_scope,
				_active_kind,
				_active_symbol,
			)
		)
	else:
		targets = _project_index.get_navigation_targets(_active_kind, _active_symbol)
	if not targets.is_empty():
		_open_resource_target(targets[0])


func _find_references(_context: Variant) -> void:
	if not _has_active_editor():
		return
	_ensure_reference_dialog()
	_reference_list.clear()
	_reference_lines.clear()
	_reference_locations.clear()
	if _active_kind in LOCAL_KINDS:
		_append_document_references(_active_path, _active_code_edit.text)
	else:
		for script_path: String in _project_index.get_values("scripts"):
			var source := (
				_active_code_edit.text if script_path == _active_path else _read_text(script_path)
			)
			_append_document_references(script_path, source)
	_reference_dialog.title = (
		KS_EditorLocale
		. text(
			"References to '%s'" % _active_symbol,
			"“%s”的引用" % _active_symbol,
		)
	)
	_reference_dialog.popup_centered()


func _append_document_references(path: String, source: String) -> void:
	var source_lines := source.split("\n")
	for reference: Dictionary in KS_SymbolIndex.get_semantic_references(source):
		if reference.get("kind") != _active_kind or reference.get("name") != _active_symbol:
			continue
		if (
			not _active_scope.is_empty()
			and reference.get("scope_name", _active_scope) != _active_scope
		):
			continue
		var line := int(reference["line"])
		var role := KS_EditorLocale.text("reference", "引用")
		if reference.get("role") == "definition":
			role = KS_EditorLocale.text("declaration", "声明")
		var source_line := String(source_lines[line - 1]).strip_edges()
		var display_path := (
			path if not path.is_empty() else KS_EditorLocale.text("Current file", "当前文件")
		)
		_reference_list.add_item("%s:%d  %s  %s" % [display_path, line, role, source_line])
		_reference_lines.append(line)
		(
			_reference_locations
			. append(
				{
					"path": path,
					"line": line,
					"column": int(reference.get("column", 1)),
				}
			)
		)


func _rename_symbol(_context: Variant) -> void:
	if not _has_active_editor() or _active_kind not in LOCAL_KINDS:
		return
	_ensure_rename_dialog()
	_rename_input.text = _active_symbol
	_rename_input.select_all()
	_validate_rename(_active_symbol)
	_rename_dialog.title = KS_EditorLocale.text("Rename Symbol", "重命名符号")
	_rename_dialog.popup_centered()
	_rename_input.grab_focus.call_deferred()


func _resolve_code_edit(paths: PackedStringArray) -> CodeEdit:
	if paths.is_empty():
		return null
	return Engine.get_main_loop().root.get_node_or_null(paths[0]) as CodeEdit


func _is_konado_editor(code_edit: CodeEdit) -> bool:
	if code_edit == null:
		return false
	var script := EditorInterface.get_script_editor().get_current_script()
	return script != null and script.resource_path.get_extension().to_lower() == "ks"


func _has_active_editor() -> bool:
	return (
		_active_code_edit != null
		and is_instance_valid(_active_code_edit)
		and not _active_symbol.is_empty()
	)


func _ensure_reference_dialog() -> void:
	if _reference_dialog != null:
		return
	_reference_dialog = AcceptDialog.new()
	_reference_dialog.ok_button_text = KS_EditorLocale.text("Close", "关闭")
	_reference_list = ItemList.new()
	_reference_list.custom_minimum_size = Vector2(760, 320)
	_reference_list.item_activated.connect(_go_to_reference)
	_reference_dialog.add_child(_reference_list)
	EditorInterface.get_base_control().add_child(_reference_dialog)


func _go_to_reference(index: int) -> void:
	if not _has_active_editor() or index < 0 or index >= _reference_locations.size():
		return
	var location := _reference_locations[index]
	var path := String(location.get("path", ""))
	if path.is_empty() or path == _active_path:
		_focus_code_line(
			_active_code_edit,
			int(location["line"]),
			_active_symbol,
		)
		_reference_dialog.hide()
		return
	var target := ResourceLoader.load(path, "Script") as Script
	if target == null:
		return
	EditorInterface.edit_script(target)
	await EditorInterface.get_base_control().get_tree().process_frame
	var editor := EditorInterface.get_script_editor().get_current_editor()
	var code_edit := editor.get_base_editor() as CodeEdit if editor != null else null
	if code_edit != null:
		_focus_code_line(code_edit, int(location["line"]), _active_symbol)
	_reference_dialog.hide()


func _focus_code_line(code_edit: CodeEdit, line_number: int, symbol: String) -> void:
	var line := clampi(line_number - 1, 0, code_edit.get_line_count() - 1)
	var column := code_edit.get_line(line).find(symbol)
	code_edit.set_caret_line(line)
	code_edit.set_caret_column(maxi(0, column))
	code_edit.center_viewport_to_caret()
	code_edit.grab_focus()


func _open_resource_target(target: Dictionary) -> void:
	var path := String(target.get("path", target.get("target_path", "")))
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	match path.get_extension().to_lower():
		"ks":
			var script := ResourceLoader.load(path, "Script") as Script
			if script != null:
				EditorInterface.edit_script(script)
		"tscn":
			EditorInterface.open_scene_from_path(path)
			_focus_open_scene_editor.call_deferred()
		_:
			var resource := ResourceLoader.load(path)
			if resource != null:
				EditorInterface.edit_resource(resource)


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


func _ensure_rename_dialog() -> void:
	if _rename_dialog != null:
		return
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.ok_button_text = KS_EditorLocale.text("Rename", "重命名")
	_rename_dialog.cancel_button_text = KS_EditorLocale.text("Cancel", "取消")
	var content := VBoxContainer.new()
	var prompt := Label.new()
	prompt.text = KS_EditorLocale.text("New symbol name:", "新符号名称：")
	_rename_input = LineEdit.new()
	_rename_input.custom_minimum_size.x = 420
	_rename_error = Label.new()
	_rename_error.modulate = Color(1.0, 0.4, 0.4)
	content.add_child(prompt)
	content.add_child(_rename_input)
	content.add_child(_rename_error)
	_rename_dialog.add_child(content)
	_rename_input.text_changed.connect(_validate_rename)
	_rename_input.text_submitted.connect(_submit_rename)
	_rename_dialog.confirmed.connect(_apply_rename)
	EditorInterface.get_base_control().add_child(_rename_dialog)


func _validate_rename(new_name: String) -> void:
	var message := ""
	if not KS_SymbolIndex.is_valid_local_symbol(_active_kind, new_name):
		message = (
			KS_EditorLocale
			. text(
				"Use a valid identifier; variables must retain a % or $ prefix.",
				"请输入有效标识符；变量必须保留 % 或 $ 前缀。",
			)
		)
	elif (
		new_name != _active_symbol
		and _has_active_editor()
		and (
			(
				KS_SymbolIndex
				. find_local_definition(
					_active_code_edit.text,
					_active_kind,
					new_name,
				)
			)
			>= 0
		)
	):
		message = KS_EditorLocale.text("This symbol already exists.", "已存在同名符号。")
	_rename_error.text = message
	_rename_dialog.get_ok_button().disabled = not message.is_empty() or new_name == _active_symbol


func _submit_rename(_new_name: String) -> void:
	if not _rename_dialog.get_ok_button().disabled:
		_apply_rename()
		_rename_dialog.hide()


func _apply_rename() -> void:
	if not _has_active_editor():
		return
	var new_name := _rename_input.text
	_validate_rename(new_name)
	if _rename_dialog.get_ok_button().disabled:
		return
	var updated := (
		KS_SymbolIndex
		. rename_local_symbol(
			_active_code_edit.text,
			_active_kind,
			_active_symbol,
			new_name,
		)
	)
	_active_code_edit.begin_complex_operation()
	_active_code_edit.select_all()
	_active_code_edit.insert_text_at_caret(updated)
	_active_code_edit.end_complex_operation()
	_active_symbol = new_name


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
