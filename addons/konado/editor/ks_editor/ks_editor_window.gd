@tool
extends Panel
class_name KsEditorWindow

const DIAGNOSTIC_DELAY := 0.35
const DRAFT_DELAY := 0.8
const EXTERNAL_CHECK_INTERVAL := 2.0
const ERROR_COLOR := Color(1.0, 0.28, 0.28)
const WARNING_COLOR := Color(1.0, 0.72, 0.2)
const DIAGNOSTICS_COLLAPSED_HEIGHT := 40.0
const DIAGNOSTICS_EXPANDED_HEIGHT := 170.0

var _documents: Array[KS_EditorDocument] = []
var _current_index := -1
var _loading_document := false
var _diagnostic_timer: Timer
var _draft_timer: Timer
var _external_timer: Timer
var _diagnostics := KS_EditorDiagnostics.new()
var _diagnostic_gutter := -1
var _marked_diagnostic_lines: Array[int] = []
var _symbol_lines: Array[int] = []
var _chinese := false
var _initialized := false

@onready var code_editor: KonadoCodeEdit = %CodeEdit
@onready var new_button: Button = $dock/MarginContainer/BoxContainer/New
@onready var open_button: Button = $dock/MarginContainer/BoxContainer/Open
@onready var save_button: Button = $dock/MarginContainer/BoxContainer/Save
@onready var file_label: Label = $dock/MarginContainer/BoxContainer/FilePath
@onready var close_button: Button = $dock/MarginContainer/BoxContainer/Close
@onready var document_tabs: TabBar = %DocumentTabs
@onready var symbol_picker: OptionButton = %SymbolPicker
@onready var find_replace_bar: HBoxContainer = %FindReplaceBar
@onready var find_text: LineEdit = %FindText
@onready var replace_text: LineEdit = %ReplaceText
@onready var match_case: CheckBox = %MatchCase
@onready var diagnostics_panel: VBoxContainer = %DiagnosticsPanel
@onready var diagnostics_summary: Label = %DiagnosticsSummary
@onready var diagnostics_tree: Tree = %DiagnosticsTree


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_initialize_editor()


func _initialize_editor() -> void:
	if _initialized:
		return
	_initialized = true
	_chinese = KS_LanguageCatalog.is_chinese_locale()
	_connect_controls()
	_setup_timers()
	_setup_diagnostic_gutter()
	_localize_interface()
	_reset_empty_state()


func _connect_controls() -> void:
	new_button.pressed.connect(_on_new_button_pressed)
	open_button.pressed.connect(_on_open_button_pressed)
	save_button.pressed.connect(save_file)
	close_button.pressed.connect(close_file)
	code_editor.text_changed.connect(_on_text_changed)
	code_editor.save_requested.connect(save_file)
	code_editor.close_requested.connect(close_file)
	code_editor.find_requested.connect(_show_find)
	code_editor.goto_line_requested.connect(_show_goto_line_dialog)
	document_tabs.tab_changed.connect(_on_tab_changed)
	document_tabs.tab_close_pressed.connect(_request_close_document)
	symbol_picker.item_selected.connect(_on_symbol_selected)
	%FindPrevious.pressed.connect(func() -> void: _find(false))
	%FindNext.pressed.connect(func() -> void: _find(true))
	%ReplaceOne.pressed.connect(_replace_one)
	%ReplaceAll.pressed.connect(_replace_all)
	%CloseFind.pressed.connect(_hide_find)
	find_text.text_submitted.connect(func(_value: String) -> void: _find(true))
	diagnostics_tree.item_activated.connect(_on_diagnostic_activated)


func _setup_timers() -> void:
	_diagnostic_timer = _make_timer(DIAGNOSTIC_DELAY, true, _run_diagnostics)
	_draft_timer = _make_timer(DRAFT_DELAY, true, _save_current_draft)
	_external_timer = _make_timer(EXTERNAL_CHECK_INTERVAL, false, _check_external_changes)
	_external_timer.start()


func _make_timer(wait_time: float, one_shot: bool, callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = one_shot
	timer.timeout.connect(callback)
	add_child(timer)
	return timer


func _setup_diagnostic_gutter() -> void:
	code_editor.add_gutter(-1)
	_diagnostic_gutter = code_editor.get_gutter_count() - 1
	code_editor.set_gutter_name(_diagnostic_gutter, "konado_diagnostics")
	code_editor.set_gutter_type(_diagnostic_gutter, TextEdit.GUTTER_TYPE_STRING)
	code_editor.set_gutter_width(_diagnostic_gutter, 14)
	code_editor.set_gutter_draw(_diagnostic_gutter, true)
	code_editor.set_gutter_clickable(_diagnostic_gutter, true)
	code_editor.gutter_clicked.connect(_on_gutter_clicked)


func _localize_interface() -> void:
	new_button.text = _ui("新建", "New")
	open_button.text = _ui("打开", "Open")
	save_button.text = _ui("保存", "Save")
	close_button.text = _ui("关闭当前文件", "Close")
	%DocsLinkButton.text = _ui("在线文档", "Documentation")
	find_text.placeholder_text = _ui("查找", "Find")
	replace_text.placeholder_text = _ui("替换", "Replace")
	match_case.text = _ui("区分大小写", "Match case")
	%FindPrevious.text = _ui("上一个", "Previous")
	%FindNext.text = _ui("下一个", "Next")
	%ReplaceOne.text = _ui("替换", "Replace")
	%ReplaceAll.text = _ui("全部替换", "Replace all")
	var severity_title := _ui("级别", "Severity")
	var line_title := _ui("行", "Line")
	diagnostics_tree.set_column_title(0, severity_title)
	diagnostics_tree.set_column_title(1, line_title)
	diagnostics_tree.set_column_title(2, _ui("问题", "Problem"))
	diagnostics_tree.set_column_expand(0, false)
	(
		diagnostics_tree
		. set_column_custom_minimum_width(
			0,
			_diagnostic_column_width(
				PackedStringArray([severity_title, _ui("错误", "Error"), _ui("警告", "Warning")])
			),
		)
	)
	diagnostics_tree.set_column_expand(1, false)
	(
		diagnostics_tree
		. set_column_custom_minimum_width(
			1,
			_diagnostic_column_width(PackedStringArray([line_title, "0000"])),
		)
	)


func _diagnostic_column_width(labels: PackedStringArray) -> int:
	var font := diagnostics_tree.get_theme_font("font")
	var font_size := maxi(
		diagnostics_tree.get_theme_font_size("font_size"),
		diagnostics_tree.get_theme_font_size("title_button_font_size"),
	)
	var text_width := 0.0
	for label: String in labels:
		text_width = maxf(
			text_width,
			font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
		)
	var content_padding := (
		diagnostics_tree.get_theme_constant("item_margin")
		+ diagnostics_tree.get_theme_constant("inner_item_margin_left")
		+ diagnostics_tree.get_theme_constant("inner_item_margin_right")
		+ 8
	)
	return ceili(text_width) + content_padding


func _ui(chinese_text: String, english_text: String) -> String:
	return chinese_text if _chinese else english_text


func edit(path: String) -> void:
	var normalized_path := ProjectSettings.localize_path(path).simplify_path()
	var existing_index := _find_document_index(normalized_path)
	if existing_index >= 0:
		_switch_document(existing_index)
		return

	var content_result := _read_file(normalized_path)
	if not content_result["ok"]:
		push_error(_ui("无法打开文件：%s", "Unable to open file: %s") % normalized_path)
		return

	var document := KS_EditorDocument.new(normalized_path, content_result["content"])
	_documents.append(document)
	document_tabs.add_tab(normalized_path.get_file())
	document_tabs.set_tab_metadata(_documents.size() - 1, normalized_path)
	document_tabs.visible = true
	_switch_document(_documents.size() - 1)
	_offer_draft_recovery(document)


func _find_document_index(path: String) -> int:
	for index: int in range(_documents.size()):
		if _documents[index].path == path:
			return index
	return -1


func _switch_document(index: int) -> void:
	if index < 0 or index >= _documents.size():
		return
	_capture_current_document()
	_current_index = index
	var document := _documents[index]
	_loading_document = true
	code_editor.text = document.content
	code_editor.editable = true
	code_editor.mouse_filter = Control.MOUSE_FILTER_STOP
	code_editor.set_caret_line(clampi(document.caret_line, 0, code_editor.get_line_count() - 1))
	code_editor.set_caret_column(maxi(0, document.caret_column))
	document_tabs.current_tab = index
	_loading_document = false
	_update_document_chrome()
	_refresh_symbols()
	_schedule_diagnostics()
	_check_document_external_change(document)
	code_editor.grab_focus()


func _capture_current_document() -> void:
	var document := _get_current_document()
	if document == null or _loading_document:
		return
	document.update_content(code_editor.text)
	document.caret_line = code_editor.get_caret_line()
	document.caret_column = code_editor.get_caret_column()


func _get_current_document() -> KS_EditorDocument:
	if _current_index < 0 or _current_index >= _documents.size():
		return null
	return _documents[_current_index]


func _on_tab_changed(tab: int) -> void:
	if not _loading_document:
		_switch_document(tab)


func _on_text_changed() -> void:
	if _loading_document:
		return
	var document := _get_current_document()
	if document == null:
		return
	document.update_content(code_editor.text)
	_update_document_chrome()
	_refresh_symbols()
	_schedule_diagnostics()
	_draft_timer.start()


func _update_document_chrome() -> void:
	var document := _get_current_document()
	if document == null:
		_reset_empty_state()
		return
	var marker := " *" if document.dirty else ""
	file_label.text = "%s%s" % [document.path.get_file(), marker]
	file_label.tooltip_text = document.path
	document_tabs.set_tab_title(_current_index, document.path.get_file() + marker)
	save_button.disabled = not document.dirty
	save_button.tooltip_text = (
		_ui("保存更改", "Save changes") if document.dirty else _ui("无更改", "No changes")
	)
	close_button.disabled = false


func save_file() -> bool:
	var document := _get_current_document()
	if document == null:
		return false
	_capture_current_document()
	if document.disk_metadata_changed():
		_check_document_external_change(document)
		return false

	var save_error := _write_file_atomically(document.path, document.content)
	if save_error != OK:
		push_error(_ui("无法保存文件：%s", "Unable to save file: %s") % document.path)
		return false
	document.mark_saved(document.content)
	KS_EditorDraftStore.remove(document.path)
	_update_document_chrome()
	EditorInterface.get_resource_filesystem().reimport_files([document.path])
	_schedule_diagnostics()
	return true


func _write_file_atomically(path: String, content: String) -> Error:
	var temporary_path := path + ".konado.tmp"
	var backup_path := path + ".konado.bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error

	var global_path := ProjectSettings.globalize_path(path)
	var global_temporary_path := ProjectSettings.globalize_path(temporary_path)
	var global_backup_path := ProjectSettings.globalize_path(backup_path)
	var replace_error := DirAccess.rename_absolute(global_temporary_path, global_path)
	if replace_error == OK:
		return OK
	if not FileAccess.file_exists(path):
		return replace_error
	return _replace_file_via_backup(
		backup_path, global_path, global_temporary_path, global_backup_path
	)


func _replace_file_via_backup(
	backup_path: String,
	global_path: String,
	global_temporary_path: String,
	global_backup_path: String,
) -> Error:
	if FileAccess.file_exists(backup_path):
		var cleanup_error := DirAccess.remove_absolute(global_backup_path)
		if cleanup_error != OK:
			return cleanup_error
	var backup_error := DirAccess.rename_absolute(global_path, global_backup_path)
	if backup_error != OK:
		return backup_error
	var replace_error := DirAccess.rename_absolute(global_temporary_path, global_path)
	if replace_error != OK:
		DirAccess.rename_absolute(global_backup_path, global_path)
		return replace_error
	DirAccess.remove_absolute(global_backup_path)
	return OK


func close_file() -> void:
	if _current_index >= 0:
		_request_close_document(_current_index)


func _request_close_document(index: int) -> void:
	if index < 0 or index >= _documents.size():
		return
	_capture_current_document()
	var document := _documents[index]
	if not document.dirty:
		_close_document(index, true)
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = _ui("未保存的更改", "Unsaved changes")
	dialog.dialog_text = (
		_ui("文件“%s”包含未保存的更改。", 'File "%s" has unsaved changes.') % document.path.get_file()
	)
	dialog.get_ok_button().text = _ui("保存", "Save")
	dialog.get_cancel_button().text = _ui("取消", "Cancel")
	dialog.add_button(_ui("不保存", "Discard"), true, "discard")
	EditorInterface.get_base_control().add_child(dialog)
	dialog.confirmed.connect(
		func() -> void:
			_switch_document(index)
			if save_file():
				_close_document(index, true)
			dialog.queue_free()
	)
	dialog.custom_action.connect(
		func(action: StringName) -> void:
			if action == &"discard":
				_close_document(index, true)
				dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(460, 150))


func _close_document(index: int, remove_draft: bool) -> void:
	if index < 0 or index >= _documents.size():
		return
	var path := _documents[index].path
	if remove_draft:
		KS_EditorDraftStore.remove(path)
	_documents.remove_at(index)
	document_tabs.remove_tab(index)
	if _documents.is_empty():
		_current_index = -1
		_reset_empty_state()
		return
	_switch_document(mini(index, _documents.size() - 1))


func _reset_empty_state() -> void:
	_loading_document = true
	code_editor.text = ""
	code_editor.editable = false
	code_editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_document = false
	document_tabs.visible = false
	file_label.text = _ui("未打开文件", "No file open")
	file_label.tooltip_text = ""
	save_button.disabled = true
	close_button.disabled = true
	symbol_picker.clear()
	symbol_picker.add_item(_ui("无符号", "No symbols"))
	symbol_picker.disabled = true
	_clear_diagnostics()
	_set_diagnostics_expanded(false)
	diagnostics_summary.text = _ui("未执行检查", "Not checked")


func get_current_content() -> String:
	return code_editor.text


func has_unsaved_changes() -> bool:
	var document := _get_current_document()
	return document != null and document.dirty


func prepare_for_shutdown() -> void:
	_capture_current_document()
	for document: KS_EditorDocument in _documents:
		if document.dirty:
			KS_EditorDraftStore.save(document)


func _save_current_draft() -> void:
	_capture_current_document()
	var document := _get_current_document()
	if document != null and document.dirty:
		var error := KS_EditorDraftStore.save(document)
		if error != OK:
			push_warning(_ui("无法保存 KonadoScript 恢复草稿。", "Unable to save recovery draft."))


func _offer_draft_recovery(document: KS_EditorDocument) -> void:
	var draft := KS_EditorDraftStore.load_for_path(document.path, document.saved_content)
	if draft.is_empty():
		return
	if draft.get("content", "") == document.saved_content:
		KS_EditorDraftStore.remove(document.path)
		return

	var dialog := _create_draft_recovery_dialog(document, draft)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(520, 180))


func _create_draft_recovery_dialog(
	document: KS_EditorDocument, draft: Dictionary
) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.name = "DraftRecoveryDialog"
	dialog.title = _ui("恢复草稿", "Recover draft")
	dialog.dialog_text = (
		_ui("检测到“%s”的未保存草稿。是否恢复？", 'An unsaved draft was found for "%s". Recover it?')
		% document.path.get_file()
	)
	if draft.get("base_changed", false):
		dialog.dialog_text += _ui(
			"\n磁盘文件在草稿产生后发生过变化，请恢复后仔细核对。",
			"\nThe file changed after the draft was created. Review recovered content carefully."
		)
	dialog.get_ok_button().text = _ui("恢复", "Recover")
	dialog.get_cancel_button().text = _ui("稍后处理", "Keep for later")
	dialog.add_button(_ui("丢弃草稿", "Discard draft"), true, "discard_draft")
	dialog.confirmed.connect(
		func() -> void:
			document.update_content(draft["content"])
			if _get_current_document() == document:
				_loading_document = true
				code_editor.text = document.content
				_loading_document = false
				_update_document_chrome()
				_refresh_symbols()
				_schedule_diagnostics()
			dialog.queue_free()
	)
	dialog.custom_action.connect(
		func(action: StringName) -> void:
			if action != &"discard_draft":
				return
			var remove_error := KS_EditorDraftStore.remove(document.path)
			if remove_error != OK:
				push_warning(
					_ui(
						"无法删除 KonadoScript 恢复草稿。",
						"Unable to remove the KonadoScript recovery draft.",
					)
				)
			dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	return dialog


func _check_external_changes() -> void:
	for document: KS_EditorDocument in _documents:
		if document.disk_metadata_changed():
			_check_document_external_change(document)


func _check_document_external_change(document: KS_EditorDocument) -> void:
	if not document.disk_metadata_changed() or document.external_prompt_open:
		return
	if not document.dirty:
		_reload_document_from_disk(document)
		return
	if document != _get_current_document():
		return

	document.external_prompt_open = true
	var dialog := ConfirmationDialog.new()
	dialog.title = _ui("文件已在外部修改", "File changed externally")
	dialog.dialog_text = (
		_ui(
			"“%s”已在其他程序中修改。重新载入会丢弃当前未保存内容。",
			'"%s" was changed by another program. Reloading discards unsaved changes.'
		)
		% document.path.get_file()
	)
	dialog.get_ok_button().text = _ui("重新载入", "Reload")
	dialog.get_cancel_button().text = _ui("保留当前内容", "Keep current")
	EditorInterface.get_base_control().add_child(dialog)
	dialog.confirmed.connect(
		func() -> void:
			document.external_prompt_open = false
			_reload_document_from_disk(document)
			dialog.queue_free()
	)
	dialog.canceled.connect(
		func() -> void:
			document.external_prompt_open = false
			document.refresh_disk_metadata()
			dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(540, 180))


func _reload_document_from_disk(document: KS_EditorDocument) -> void:
	var result := _read_file(document.path)
	if not result["ok"]:
		push_warning(_ui("外部文件已被删除：%s", "External file was deleted: %s") % document.path)
		document.saved_content = ""
		document.dirty = not document.content.is_empty()
		document.refresh_disk_metadata()
		if document == _get_current_document():
			_update_document_chrome()
		return
	document.mark_saved(result["content"])
	KS_EditorDraftStore.remove(document.path)
	if document == _get_current_document():
		_loading_document = true
		code_editor.text = document.content
		_loading_document = false
		_update_document_chrome()
		_refresh_symbols()
		_schedule_diagnostics()


func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "content": ""}
	var content := file.get_as_text()
	file.close()
	return {"ok": true, "content": content}


func _schedule_diagnostics() -> void:
	if _diagnostic_timer != null:
		_diagnostic_timer.start()


func _run_diagnostics() -> void:
	var document := _get_current_document()
	if document == null:
		return
	_capture_current_document()
	var results := _diagnostics.analyze(document.content, document.path)
	_render_diagnostics(results)


func _render_diagnostics(results: Array[Dictionary]) -> void:
	_clear_diagnostics()
	var root := diagnostics_tree.create_item()
	var error_count := 0
	var warning_count := 0
	var line_severity := {}

	for diagnostic: Dictionary in results:
		var severity: String = diagnostic["severity"]
		var color := ERROR_COLOR if severity == "error" else WARNING_COLOR
		if severity == "error":
			error_count += 1
		else:
			warning_count += 1

		var item := diagnostics_tree.create_item(root)
		item.set_text(0, _ui("错误", "Error") if severity == "error" else _ui("警告", "Warning"))
		item.set_text(1, str(diagnostic["line"]))
		item.set_text(2, diagnostic["message"])
		item.set_custom_color(0, color)
		item.set_metadata(0, diagnostic)

		var line_index: int = clampi(diagnostic["line"] - 1, 0, code_editor.get_line_count() - 1)
		if not line_severity.has(line_index) or severity == "error":
			line_severity[line_index] = severity

	for line_index: int in line_severity:
		var severity: String = line_severity[line_index]
		var color := ERROR_COLOR if severity == "error" else WARNING_COLOR
		code_editor.set_line_gutter_text(line_index, _diagnostic_gutter, "●")
		code_editor.set_line_gutter_item_color(line_index, _diagnostic_gutter, color)
		code_editor.set_line_background_color(line_index, Color(color, 0.12))
		_marked_diagnostic_lines.append(line_index)

	if results.is_empty():
		_set_diagnostics_expanded(false)
		diagnostics_summary.text = _ui("未发现问题", "No problems found")
	else:
		_set_diagnostics_expanded(true)
		diagnostics_summary.text = (
			_ui("%d 个错误，%d 个警告", "%d errors, %d warnings") % [error_count, warning_count]
		)


func _set_diagnostics_expanded(expanded: bool) -> void:
	diagnostics_tree.visible = expanded
	diagnostics_panel.custom_minimum_size.y = (
		DIAGNOSTICS_EXPANDED_HEIGHT if expanded else DIAGNOSTICS_COLLAPSED_HEIGHT
	)


func _clear_diagnostics() -> void:
	for line: int in _marked_diagnostic_lines:
		if line < code_editor.get_line_count():
			code_editor.set_line_gutter_text(line, _diagnostic_gutter, "")
			code_editor.set_line_background_color(line, Color.TRANSPARENT)
	_marked_diagnostic_lines.clear()
	diagnostics_tree.clear()


func _on_diagnostic_activated() -> void:
	var item := diagnostics_tree.get_selected()
	if item == null:
		return
	var diagnostic: Dictionary = item.get_metadata(0)
	_jump_to_line(diagnostic.get("line", 1), diagnostic.get("column", 1))


func _on_gutter_clicked(line: int, gutter: int) -> void:
	if gutter == _diagnostic_gutter and _marked_diagnostic_lines.has(line):
		_jump_to_line(line + 1, 1)


func _jump_to_line(line: int, column: int = 1) -> void:
	if _get_current_document() == null:
		return
	code_editor.set_caret_line(clampi(line - 1, 0, code_editor.get_line_count() - 1))
	code_editor.set_caret_column(maxi(0, column - 1))
	code_editor.center_viewport_to_caret()
	code_editor.grab_focus()


func _refresh_symbols() -> void:
	symbol_picker.clear()
	_symbol_lines.clear()
	var branch_regex := RegEx.new()
	branch_regex.compile("(?m)^\\s*branch\\s+([\\p{L}_][\\p{L}\\p{N}_-]*)")
	for match_result: RegExMatch in branch_regex.search_all(code_editor.text):
		_symbol_lines.append(code_editor.text.left(match_result.get_start()).count("\n") + 1)
		symbol_picker.add_item(match_result.get_string(1))

	if _symbol_lines.is_empty():
		symbol_picker.add_item(_ui("无分支", "No branches"))
		symbol_picker.disabled = true
	else:
		symbol_picker.disabled = false
		symbol_picker.select(-1)
		symbol_picker.tooltip_text = _ui("跳转到分支", "Jump to branch")


func _on_symbol_selected(index: int) -> void:
	if index >= 0 and index < _symbol_lines.size():
		_jump_to_line(_symbol_lines[index])
		symbol_picker.select(-1)


func _show_find(show_replace: bool) -> void:
	find_replace_bar.visible = true
	replace_text.visible = show_replace
	%ReplaceOne.visible = show_replace
	%ReplaceAll.visible = show_replace
	if code_editor.has_selection():
		find_text.text = code_editor.get_selected_text()
	find_text.grab_focus()
	find_text.select_all()


func _hide_find() -> void:
	find_replace_bar.visible = false
	code_editor.grab_focus()


func _find(forward: bool) -> bool:
	var needle := find_text.text
	if needle.is_empty() or _get_current_document() == null:
		return false
	var content := code_editor.text
	var start_offset := _caret_offset()
	if code_editor.has_selection():
		start_offset = (
			_position_offset(
				code_editor.get_selection_to_line(), code_editor.get_selection_to_column()
			)
			if forward
			else _position_offset(
				code_editor.get_selection_from_line(), code_editor.get_selection_from_column()
			)
		)

	var offset := -1
	if forward:
		offset = (
			content.find(needle, start_offset)
			if match_case.button_pressed
			else content.findn(needle, start_offset)
		)
		if offset < 0:
			offset = content.find(needle) if match_case.button_pressed else content.findn(needle)
	else:
		var reverse_start := maxi(0, start_offset - 1)
		offset = (
			content.rfind(needle, reverse_start)
			if match_case.button_pressed
			else content.rfindn(needle, reverse_start)
		)
		if offset < 0:
			offset = (
				content.rfind(needle) if match_case.button_pressed else content.rfindn(needle)
			)
	if offset < 0:
		return false
	_select_offsets(offset, offset + needle.length())
	return true


func _replace_one() -> void:
	var needle := find_text.text
	if needle.is_empty():
		return
	if code_editor.has_selection() and _strings_equal(code_editor.get_selected_text(), needle):
		code_editor.insert_text_at_caret(replace_text.text)
	_find(true)


func _replace_all() -> void:
	var needle := find_text.text
	if needle.is_empty() or _get_current_document() == null:
		return
	var source := code_editor.text
	var result := ""
	var cursor := 0
	var replacements := 0
	while cursor <= source.length():
		var match_offset := (
			source.find(needle, cursor)
			if match_case.button_pressed
			else source.findn(needle, cursor)
		)
		if match_offset < 0:
			result += source.substr(cursor)
			break
		result += source.substr(cursor, match_offset - cursor) + replace_text.text
		cursor = match_offset + needle.length()
		replacements += 1
	if replacements > 0:
		code_editor.begin_complex_operation()
		code_editor.text = result
		code_editor.end_complex_operation()


func _strings_equal(left: String, right: String) -> bool:
	return left == right if match_case.button_pressed else left.to_lower() == right.to_lower()


func _caret_offset() -> int:
	return _position_offset(code_editor.get_caret_line(), code_editor.get_caret_column())


func _position_offset(line: int, column: int) -> int:
	var offset := 0
	for line_index: int in range(mini(line, code_editor.get_line_count())):
		offset += code_editor.get_line(line_index).length() + 1
	return offset + column


func _select_offsets(from_offset: int, to_offset: int) -> void:
	var from_position := _offset_position(from_offset)
	var to_position := _offset_position(to_offset)
	code_editor.select(from_position.y, from_position.x, to_position.y, to_position.x)
	code_editor.set_caret_line(to_position.y)
	code_editor.set_caret_column(to_position.x)
	code_editor.center_viewport_to_caret()


func _offset_position(offset: int) -> Vector2i:
	var prefix := code_editor.text.left(clampi(offset, 0, code_editor.text.length()))
	var line := prefix.count("\n")
	var last_newline := prefix.rfind("\n")
	var column := prefix.length() if last_newline < 0 else prefix.length() - last_newline - 1
	return Vector2i(column, line)


func _show_goto_line_dialog() -> void:
	if _get_current_document() == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = _ui("跳转到行", "Go to line")
	var input := SpinBox.new()
	input.min_value = 1
	input.max_value = code_editor.get_line_count()
	input.value = code_editor.get_caret_line() + 1
	input.select_all_on_focus = true
	dialog.add_child(input)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.confirmed.connect(
		func() -> void:
			_jump_to_line(int(input.value))
			dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(320, 120))
	input.get_line_edit().grab_focus()


func _on_new_button_pressed() -> void:
	var file_dialog := EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = _ui("新建 KonadoScript", "New KonadoScript")
	file_dialog.add_filter("*.ks;KonadoScript")
	file_dialog.current_dir = "res://"
	EditorInterface.get_base_control().add_child(file_dialog)
	file_dialog.file_selected.connect(
		func(path: String) -> void:
			_create_file(path)
			file_dialog.queue_free()
	)
	file_dialog.canceled.connect(file_dialog.queue_free)
	file_dialog.popup_centered_ratio(0.75)


func _create_file(path: String) -> void:
	var normalized_path := path if path.get_extension() == "ks" else path + ".ks"
	if FileAccess.file_exists(normalized_path):
		var dialog := ConfirmationDialog.new()
		dialog.title = _ui("文件已存在", "File exists")
		dialog.dialog_text = (
			_ui("“%s”已存在，是否覆盖？", '"%s" already exists. Overwrite it?') % normalized_path.get_file()
		)
		EditorInterface.get_base_control().add_child(dialog)
		dialog.confirmed.connect(
			func() -> void:
				_write_empty_file(normalized_path)
				dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered(Vector2i(440, 140))
	else:
		_write_empty_file(normalized_path)


func _write_empty_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error(_ui("无法创建文件：%s", "Unable to create file: %s") % path)
		return
	file.close()
	EditorInterface.get_resource_filesystem().scan()
	edit(path)


func _on_open_button_pressed() -> void:
	var file_dialog := EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = _ui("打开 KonadoScript", "Open KonadoScript")
	file_dialog.add_filter("*.ks;KonadoScript")
	file_dialog.current_dir = "res://"
	EditorInterface.get_base_control().add_child(file_dialog)
	file_dialog.file_selected.connect(
		func(path: String) -> void:
			edit(path)
			file_dialog.queue_free()
	)
	file_dialog.canceled.connect(file_dialog.queue_free)
	file_dialog.popup_centered_ratio(0.75)
