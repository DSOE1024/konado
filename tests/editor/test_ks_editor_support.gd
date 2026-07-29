extends SceneTree

var _failures := 0
var _test_paths := [
	"user://konado_editor_support_a.ks",
	"user://konado_editor_support_b.ks",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_language_catalog()
	_test_imported_resource_type()
	_test_source_line_numbers()
	_test_diagnostic_service()
	_test_highlighter_cache()
	_test_highlighter_lexical_boundaries()
	await _test_editor_document_workflow()
	_cleanup_test_files()
	if _failures == 0:
		print("PASS: KonadoScript editor support tests")
	quit(_failures)


func _test_imported_resource_type() -> void:
	var path := "res://sample/demo/demo_01.ks"
	_expect(ResourceLoader.load(path) is KND_Shot, "imported KonadoScript files load as KND_Shot")


func _test_language_catalog() -> void:
	_expect(
		KS_LanguageCatalog.validate_catalog().is_empty(),
		"editor catalog contains only parser-supported keywords",
	)
	_expect(
		not KS_LanguageCatalog.ROOT_KEYWORDS.has("shot_id"), "obsolete shot_id is not suggested"
	)
	_expect(not KS_LanguageCatalog.ROOT_KEYWORDS.has("start"), "obsolete start is not suggested")
	_expect(
		KS_LanguageCatalog.get_context_completions("play").has("sfx"),
		"audio completion uses the supported sfx keyword",
	)
	_expect(
		KS_LanguageCatalog.get_context_completions("actor").has("motion"),
		"actor motion is included in completion metadata",
	)
	_expect(
		(
			KS_LanguageCatalog.get_background_effects().size()
			== KS_Emitter.BACKGROUND_EFFECTS_MAP.size()
		),
		"background effect completion uses the compiler source of truth",
	)
	var lexer := KS_Lexer.new()
	var parser := KS_Parser.new()
	lexer.console_output_enabled = false
	parser.console_output_enabled = false
	for snippet: Dictionary in KS_LanguageCatalog.SNIPPETS:
		var tokens := lexer.tokenize(snippet["snippet"], "editor-snippet-test.ks")
		_expect(
			parser.parse(tokens, "editor-snippet-test.ks") != null,
			"statement catalog snippet parses: %s" % snippet["label"],
		)


func _test_source_line_numbers() -> void:
	var compiler := KS_Compiler.new()
	compiler.set_console_output_enabled(false)
	var shot := compiler.compile_string("unknown_command", "line-number-test.ks")
	_expect(shot == null, "invalid first-line command is rejected")
	_expect(
		not compiler.get_errors().is_empty() and "[行：1]" in compiler.get_errors()[0],
		"first source line is reported as line 1",
	)


func _test_diagnostic_service() -> void:
	var diagnostics := KS_EditorDiagnostics.new()
	var results := diagnostics.analyze("actor move missing 2", "diagnostic-test.ks")
	_expect(not results.is_empty(), "semantic warnings are exposed to the editor")
	if not results.is_empty():
		_expect(results[0]["severity"] == "warning", "diagnostic severity is preserved")
		_expect(results[0]["line"] == 1, "diagnostic line is structured")

	results = diagnostics.analyze("background room unknown_effect", "diagnostic-test.ks")
	_expect(
		results.size() == 1 and "unknown_effect" in results[0]["message"],
		"emission constraints are exposed by live diagnostics",
	)


func _test_highlighter_cache() -> void:
	var highlighter := KND_KsHighlighter.new()
	var first_count := highlighter.get_compiled_rule_count()
	var second_count := highlighter.get_compiled_rule_count()
	_expect(first_count > 0, "syntax highlighter compiles rules")
	_expect(first_count == second_count, "syntax highlighter reuses compiled rules")


func _test_highlighter_lexical_boundaries() -> void:
	var highlighter := KND_KsHighlighter.new()
	var line := '"Kona" "C# and \\"#\\" stay text" # actual comment'
	var highlighting := highlighter._highlight_line_text(line, Color.WHITE)
	var string_hash := line.find("#")
	var comment_hash := line.rfind("#")
	_expect(
		_color_at(highlighting, string_hash, Color.WHITE) == KND_KsHighlighter.STRING_COLOR,
		"comment markers inside strings retain string highlighting",
	)
	_expect(
		_color_at(highlighting, comment_hash, Color.WHITE) == KND_KsHighlighter.COMMENT_COLOR,
		"comment markers outside strings begin comment highlighting",
	)
	var unterminated_line := '"unfinished # still string'
	var unterminated_highlighting := highlighter._highlight_line_text(
		unterminated_line, Color.WHITE
	)
	_expect(
		(
			_color_at(unterminated_highlighting, unterminated_line.find("#"), Color.WHITE)
			== KND_KsHighlighter.STRING_COLOR
		),
		"unterminated strings do not leak comment highlighting",
	)


func _test_editor_document_workflow() -> void:
	_write_test_file(_test_paths[0], 'branch first\n"Kona" "First"\n')
	_write_test_file(_test_paths[1], 'branch second\n"Kona" "Second"\n')
	for path: String in _test_paths:
		KS_EditorDraftStore.remove(path)

	var editor_scene := load("res://addons/konado/editor/ks_editor/ks_editor.tscn") as PackedScene
	var editor := editor_scene.instantiate() as KsEditorWindow
	get_root().add_child(editor)
	editor._initialize_editor()
	await process_frame

	editor.edit(_test_paths[0])
	await process_frame
	var code_edit := editor.get_node("%CodeEdit") as CodeEdit
	var tabs := editor.get_node("%DocumentTabs") as TabBar
	code_edit.text += "# unsaved\n"
	await process_frame
	editor.edit(_test_paths[1])
	await process_frame
	_expect(tabs.tab_count == 2, "opening another script creates a second document tab")
	_write_test_file(_test_paths[1], 'branch second\n"Kona" "Changed externally"\n')
	editor._check_external_changes()
	await process_frame
	_expect("Changed externally" in code_edit.text, "clean documents reload external changes")
	tabs.current_tab = 0
	await process_frame
	_expect("# unsaved" in code_edit.text, "switching tabs preserves unsaved content")

	code_edit.text = "branch first\njump_branch first\n"
	editor.get_node("%FindText").text = "first"
	editor.get_node("%ReplaceText").text = "renamed"
	editor._replace_all()
	await process_frame
	_expect(
		code_edit.text.count("renamed") == 2,
		"find and replace updates every match in the current document",
	)

	code_edit.text = "unknown_command"
	await create_timer(0.5).timeout
	var diagnostics_tree := editor.get_node("%DiagnosticsTree") as Tree
	_expect(
		diagnostics_tree.get_root() != null and diagnostics_tree.get_root().get_child_count() > 0,
		"debounced diagnostics are rendered in the editor",
	)

	editor.prepare_for_shutdown()
	_expect(
		FileAccess.file_exists(KS_EditorDraftStore.get_draft_path(_test_paths[0])),
		"unsaved documents receive a recovery draft",
	)
	await _test_draft_recovery_decisions(editor)
	editor.queue_free()
	await process_frame


func _test_draft_recovery_decisions(editor: KsEditorWindow) -> void:
	var disk_content := 'branch first\n"Kona" "First"\n'
	var dirty_document := KS_EditorDocument.new(_test_paths[0], disk_content)
	dirty_document.update_content(disk_content + "# recovered content\n")
	_expect(KS_EditorDraftStore.save(dirty_document) == OK, "recovery test draft can be saved")

	var disk_document := KS_EditorDocument.new(_test_paths[0], disk_content)
	var draft := KS_EditorDraftStore.load_for_path(_test_paths[0], disk_content)
	var dialog := editor._create_draft_recovery_dialog(disk_document, draft)
	editor.add_child(dialog)
	await process_frame
	_expect(dialog != null, "draft recovery dialog is displayed")
	dialog.canceled.emit()
	await process_frame
	_expect(
		FileAccess.file_exists(KS_EditorDraftStore.get_draft_path(_test_paths[0])),
		"closing draft recovery keeps the recovery draft",
	)

	dialog = editor._create_draft_recovery_dialog(disk_document, draft)
	editor.add_child(dialog)
	dialog.confirmed.emit()
	await process_frame
	_expect(
		disk_document.content == dirty_document.content,
		"recovering a draft restores its content",
	)
	_expect(
		FileAccess.file_exists(KS_EditorDraftStore.get_draft_path(_test_paths[0])),
		"recovering keeps the draft until the restored content is saved or discarded",
	)

	dialog = editor._create_draft_recovery_dialog(disk_document, draft)
	editor.add_child(dialog)
	await process_frame
	_expect(dialog != null, "draft recovery can be offered again after postponing")
	dialog.custom_action.emit(&"discard_draft")
	await process_frame
	_expect(
		not FileAccess.file_exists(KS_EditorDraftStore.get_draft_path(_test_paths[0])),
		"only the explicit discard action removes a recovery draft",
	)


func _color_at(highlighting: Dictionary, column: int, default_color: Color) -> Color:
	var color := default_color
	var transitions: Array = highlighting.keys()
	transitions.sort()
	for transition: int in transitions:
		if transition > column:
			break
		color = highlighting[transition]["color"]
	return color


func _write_test_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "test file can be created: %s" % path)
		return
	file.store_string(content)
	file.close()


func _cleanup_test_files() -> void:
	for path: String in _test_paths:
		KS_EditorDraftStore.remove(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: %s" % message)
