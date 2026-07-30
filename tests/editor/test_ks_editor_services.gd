extends SceneTree


class DebugManager:
	extends Node

	var resume_count := 0

	func _process_next() -> void:
		resume_count += 1


var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if Engine.is_editor_hint():
		var filesystem := EditorInterface.get_resource_filesystem()
		while filesystem.is_scanning() or filesystem.is_importing():
			await process_frame
		await process_frame
	_test_document_cache()
	_test_atomic_file()
	_test_incremental_project_index()
	_test_formatter()
	_test_typed_completion()
	_test_control_flow_analysis()
	_test_localization_validation()
	_test_editor_localization()
	_test_quick_fixes()
	_test_code_edit_transaction()
	_test_adaptive_diagnostic_card()
	_test_refactor_plan()
	await _test_runtime_debugger_resume()
	_test_editor_plugin_contracts()
	if _failures == 0:
		print("PASS: KonadoScript editor service tests")
	await process_frame
	quit(_failures)


func _test_document_cache() -> void:
	var store := KS_DocumentStore.new()
	var first := store.update_buffer("res://tests/cache.ks", "branch intro\n\tend")
	var revision := first.revision
	var second := store.update_buffer("res://tests/cache.ks", "branch intro\n\tend")
	_expect(first == second, "document store reuses one semantic model per path")
	_expect(second.revision == revision, "identical source does not create a new revision")
	store.update_buffer("res://tests/cache.ks", "branch changed\n\tend")
	_expect(second.revision == revision + 1, "changed source advances the semantic revision")
	_expect(second.branch_definitions.has("changed"), "document model exposes compiler symbols")
	var empty := store.update_buffer("res://tests/empty.ks", "")
	_expect(empty.source.is_empty(), "empty unsaved buffers never fall back to stale disk content")


func _test_atomic_file() -> void:
	var path := "user://konado_atomic_file_test.ks"
	_expect(KS_AtomicFile.replace_text(path, "first") == OK, "atomic writer creates a new file")
	_expect(
		KS_AtomicFile.replace_text(path, "second") == OK, "atomic writer replaces an existing file"
	)
	var file := FileAccess.open(path, FileAccess.READ)
	_expect(
		file != null and file.get_as_text() == "second", "atomic writer preserves complete content"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_incremental_project_index() -> void:
	var path := "res://tests/editor/fixtures/editor_refactor.ks"
	var store := KS_DocumentStore.shared()
	var original := store.get_document(path).source
	var index := KS_ProjectIndex.shared()
	index.get_values("scripts")
	var changed := store.update_buffer(path, original + "\nbranch unsaved_index_symbol\n\tend")
	index.update_document(changed)
	_expect(
		not index.get_definitions("branches", "unsaved_index_symbol").is_empty(),
		"incremental project index includes unsaved KonadoScript revisions",
	)
	var restored := store.update_buffer(path, original)
	index.update_document(restored)
	_expect(
		index.get_definitions("branches", "unsaved_index_symbol").is_empty(),
		"incremental project index removes symbols from superseded revisions",
	)


func _test_formatter() -> void:
	var source := (
		"if   %score   ==   1:\n"
		+ '  "Kona"   "spaces   inside"   # keep   comment\n'
		+ " else:   \n"
		+ "screentext   {\n"
		+ ' "full   text"\n'
		+ " }\n"
		+ "endif"
	)
	var formatted := KS_Formatter.format_document(source, "    ")
	_expect(
		'"Kona" "spaces   inside" # keep   comment' in formatted,
		"formatter normalizes syntax spacing without changing strings or comments",
	)
	_expect(
		"\nelse:\n    screentext {\n" in formatted,
		"formatter applies deterministic nested indentation",
	)
	_expect(
		KS_Formatter.format_document(formatted, "    ") == formatted,
		"formatter output is idempotent",
	)


func _test_typed_completion() -> void:
	var language := KND_KonadoScriptLanguage.new()
	var variables := language._get_completion_candidates("set %score 0", "set %")
	var variables_are_typed := not variables.is_empty()
	for item: Dictionary in variables:
		if item.get("kind") != CodeEdit.CodeCompletionKind.KIND_VARIABLE:
			variables_are_typed = false
			break
	_expect(
		variables_are_typed,
		"semantic completion assigns variable candidates their native Godot completion kind",
	)


func _test_control_flow_analysis() -> void:
	var document := KS_DocumentModel.new()
	(
		document
		. update(
			'choice "Start" -> used\nbranch used\n\tjump_branch missing\nbranch orphan\n\tend',
			"res://tests/story.ks",
		)
	)
	var diagnostics := KS_ControlFlowAnalyzer.analyze(document)
	_expect(
		diagnostics.any(
			func(item: Dictionary) -> bool: return item.get("code") == "missing_branch"
		),
		"control-flow analysis reports missing branches",
	)
	_expect(
		diagnostics.any(
			func(item: Dictionary) -> bool: return item.get("code") == "unreachable_branch"
		),
		"control-flow analysis reports unreferenced branches",
	)


func _test_localization_validation() -> void:
	var comparison := (
		KS_LocalizationValidator
		. compare(
			'"Kona" "Hello"\nchoice "Continue" -> next\nbranch next\n\tend',
			'"Kona" "你好"\nchoice "继续" -> next\nbranch next\n\tend',
		)
	)
	_expect(
		comparison["compatible"], "translated text may differ while structure remains compatible"
	)
	var broken := (
		KS_LocalizationValidator
		. compare(
			'choice "Continue" -> next\nbranch next\n\tend',
			'choice "继续" -> other\nbranch next\n\tend',
		)
	)
	_expect(not broken["compatible"], "localized branch target drift is reported")
	var inserted := (
		KS_LocalizationValidator
		. compare(
			'"Kona" "One"\n"Kona" "Two"\n"Kona" "Three"',
			'"Kona" "一"\n"Kona" "新增"\n"Kona" "二"\n"Kona" "三"',
		)
	)
	_expect(
		(
			(
				inserted["diagnostics"]
				. filter(func(item: Dictionary) -> bool: return item.get("code") == "locale_extra")
				. size()
			)
			== 1
		),
		"localization alignment isolates inserted rows instead of cascading later mismatches",
	)


func _test_editor_localization() -> void:
	_expect(
		KS_DiagnosticMessages.validate_catalog().is_empty(),
		"every static and dynamic diagnostic template has complete bilingual coverage",
	)
	_expect(
		KS_EditorLocale.resolve_locale("auto", "zh_CN", "en_US") == "zh_CN",
		"automatic editor language resolves through Godot's tool locale",
	)
	_expect(
		KS_EditorLocale.resolve_locale("en", "zh_CN", "zh_CN") == "en",
		"an explicitly configured editor language takes precedence",
	)
	var document := KS_DocumentModel.new()
	document.update('if %love == 0:\n\t"Kona" "Hello"\nendif1', "diagnostic-test.ks")
	var chinese_diagnostics := document.get_diagnostics("zh_CN")
	var chinese_fixes := KS_QuickFixService.get_fixes(document, "zh_CN")
	_expect(
		(
			not chinese_diagnostics.is_empty()
			and "无法识别的语法" in chinese_diagnostics[0]["message"]
			and "应为 endif" in chinese_diagnostics[0]["message"]
		),
		"diagnostic messages follow the Chinese editor locale",
	)
	_expect(
		not chinese_fixes.is_empty() and chinese_fixes[0]["title"] == "替换为“endif”",
		"diagnostic quick fixes follow the Chinese editor locale",
	)
	var compiler := KS_Compiler.new()
	compiler.set_console_output_enabled(false)
	var analysis := compiler.analyze_string("cam fly", "res://tests/diagnostic-test.ks")
	var records: Array = analysis.get("diagnostics", [])
	var english_diagnostics := (
		KS_Diagnostics
		. new()
		. analyze_result(
			"cam fly",
			"res://tests/diagnostic-test.ks",
			"en",
			analysis,
		)
	)
	_expect(
		(
			records.size() == 1
			and records[0].get("code") == "syntax.camera_action"
			and records[0].get("arguments") == ["fly"]
		),
		"compiler stages expose stable diagnostic codes and structured arguments",
	)
	_expect(
		(
			english_diagnostics.size() == 1
			and english_diagnostics[0]["message"].begins_with("Unknown cam action")
			and english_diagnostics[0]["end_column"] > english_diagnostics[0]["column"]
		),
		"structured editor diagnostics localize without parsing console strings and expose a range",
	)


func _test_quick_fixes() -> void:
	var document := KS_DocumentModel.new()
	document.update("if %score == 1: # keep\n\tendif_bad # explain", "res://tests/fixes.ks")
	var fixes := KS_QuickFixService.get_fixes(document)
	var normalize := {}
	for fix: Dictionary in fixes:
		if fix.get("code") == "normalize_endif":
			normalize = KS_QuickFixService.materialize_line_fix(document.source, fix)
			break
	_expect(not normalize.is_empty(), "quick fixes recognize malformed endif")
	if not normalize.is_empty():
		var fixed := KS_QuickFixService.apply_fix(document.source, normalize)
		_expect(
			fixed.ends_with("\tendif # explain"),
			"quick fix changes only the malformed token and preserves comments",
		)
		_expect(
			not fixes.any(func(fix: Dictionary) -> bool: return fix.get("code") == "append_endif"),
			"normalizing a malformed endif also balances its conditional block",
		)
	var stale_fix := (
		KS_QuickFixService
		. materialize_line_fix(
			document.source,
			{"line_edit": true, "line": 999, "replacement_line": ""},
		)
	)
	_expect(
		stale_fix.is_empty(),
		"stale quick fixes cannot address a line outside the current revision",
	)
	var fixed_all := KS_QuickFixService.apply_all_fixes(
		"if %score == 1\n\tendif_bad\n}", "res://tests/fixes.ks"
	)
	_expect(
		fixed_all == "if %score == 1:\n\tendif\n",
		"all safe quick fixes apply directly to one current editor revision",
	)
	var choice_document := KS_DocumentModel.new()
	choice_document.update('choice "Continue" next', "res://tests/fixes.ks")
	var choice_fix := KS_QuickFixService.get_fixes(choice_document, "en").filter(
		func(fix: Dictionary) -> bool: return fix.get("code") == "insert_choice_arrow"
	)
	_expect(
		(
			choice_fix.size() == 1
			and (
				(
					KS_QuickFixService
					. apply_fix(
						choice_document.source,
						(
							KS_QuickFixService
							. materialize_line_fix(
								choice_document.source,
								choice_fix[0],
							)
						),
					)
				)
				== 'choice "Continue" -> next'
			)
		),
		"quick fixes insert an unambiguous missing choice arrow",
	)
	var boolean_document := KS_DocumentModel.new()
	(
		boolean_document
		. update(
			'achievement set_flag "ending" maybe',
			"res://tests/fixes.ks",
		)
	)
	var boolean_diagnostic := boolean_document.get_diagnostics("en")[0]
	var boolean_fixes := KS_QuickFixService.get_fixes(boolean_document, "en").filter(
		func(fix: Dictionary) -> bool:
			return KS_QuickFixService.matches_diagnostic(fix, boolean_diagnostic)
	)
	_expect(
		(
			boolean_fixes.size() == 2
			and boolean_fixes.all(
				func(fix: Dictionary) -> bool: return not bool(fix.get("safe", true))
			)
		),
		"one diagnostic may offer multiple explicit alternatives without marking a choice as safe",
	)
	_expect(
		(
			(
				KS_QuickFixService
				. apply_all_fixes(
					boolean_document.source,
					boolean_document.path,
				)
			)
			== boolean_document.source
		),
		"apply-all never chooses between non-deterministic quick-fix alternatives",
	)
	var actor_document := KS_DocumentModel.new()
	actor_document.update("actor show Kona normal", "res://tests/fixes.ks")
	var actor_diagnostics := actor_document.get_diagnostics("en")
	var actor_fixes := (
		KS_QuickFixService
		. rank_fixes_for_diagnostic(
			KS_QuickFixService.get_fixes(actor_document, "en"),
			actor_diagnostics[0] if not actor_diagnostics.is_empty() else {},
		)
	)
	_expect(
		(
			actor_diagnostics.size() == 1
			and actor_diagnostics[0].get("code") == "syntax.actor_position"
			and actor_fixes.size() == KS_QuickFixService.MAX_CANDIDATES_PER_DIAGNOSTIC
			and actor_fixes.all(
				func(fix: Dictionary) -> bool: return not bool(fix.get("safe", true))
			)
		),
		"missing actor positions offer every valid position without choosing one as safe",
	)
	for position_index: int in actor_fixes.size():
		var actor_fix := (
			KS_QuickFixService
			. materialize_line_fix(
				actor_document.source,
				actor_fixes[position_index],
			)
		)
		_expect(
			(
				KS_QuickFixService.apply_fix(actor_document.source, actor_fix)
				== (
					"actor show Kona normal at %s"
					% KS_LanguageCatalog.LIKELY_POSITION_VALUES[position_index]
				)
			),
			"each actor position suggestion applies its distinct candidate",
		)
	_expect(
		(
			(
				KS_QuickFixService
				. apply_all_fixes(
					actor_document.source,
					actor_document.path,
				)
			)
			== actor_document.source
		),
		"apply-all does not guess an actor position",
	)
	var keyword_typo_document := KS_DocumentModel.new()
	(
		keyword_typo_document
		. update(
			"actor exit1 Kona\nend写错",
			"res://tests/fixes.ks",
		)
	)
	var keyword_typo_fixes := KS_QuickFixService.get_fixes(keyword_typo_document, "zh_CN")
	var actor_action_fix := keyword_typo_fixes.filter(
		func(fix: Dictionary) -> bool:
			return (
				fix.get("code") == "replace_context_keyword"
				and fix.get("replacement_line") == "actor exit Kona"
			)
	)
	var root_keyword_fix := keyword_typo_fixes.filter(
		func(fix: Dictionary) -> bool:
			return (
				fix.get("code") == "replace_root_keyword" and fix.get("replacement_line") == "end"
			)
	)
	_expect(
		(
			actor_action_fix.size() == 1
			and root_keyword_fix.size() == 1
			and not bool(actor_action_fix[0].get("safe", true))
			and not bool(root_keyword_fix[0].get("safe", true))
		),
		"likely root and contextual keyword typos offer explicit non-destructive corrections",
	)
	var ranked_candidates := (
		KS_QuickFixService
		. rank_fixes_for_diagnostic(
			[
				{"code": "low", "line": 1, "safe": false, "confidence": 0.2},
				{"code": "safe", "line": 1, "safe": true, "confidence": 0.1},
				{"code": "high", "line": 1, "safe": false, "confidence": 0.9},
				{"code": "medium", "line": 1, "safe": false, "confidence": 0.6},
			],
			{"line": 1, "code": "test"},
		)
	)
	_expect(
		(
			ranked_candidates.size() == 3
			and ranked_candidates[0].get("code") == "safe"
			and ranked_candidates[1].get("code") == "high"
			and ranked_candidates[2].get("code") == "medium"
		),
		"quick-fix candidates are capped at three with safe and likely edits first",
	)


func _test_code_edit_transaction() -> void:
	var code_edit := CodeEdit.new()
	root.add_child(code_edit)
	code_edit.text = "alpha\nbeta\ngamma"
	code_edit.select(0, 1, 0, 4)
	var second_caret := code_edit.add_caret(2, 2)
	_expect(second_caret >= 0, "native editor accepts a secondary caret for transaction testing")
	KS_CodeEditTransaction.replace_text(code_edit, "alpha!\nbeta\ngamma")
	_expect(
		(
			code_edit.get_caret_count() == 2
			and code_edit.has_selection(0)
			and code_edit.get_selection_from_column(0) == 1
			and code_edit.get_selection_to_column(0) == 4
			and code_edit.get_caret_line(1) == 2
			and code_edit.get_caret_column(1) == 2
		),
		"whole-document edits preserve native selections and multiple carets",
	)
	root.remove_child(code_edit)
	code_edit.free()


func _test_adaptive_diagnostic_card() -> void:
	var code_edit := CodeEdit.new()
	code_edit.size = Vector2(1000, 600)
	root.add_child(code_edit)
	var overlay := KS_JumpLinkOverlay.new()
	code_edit.add_child(overlay)
	overlay.setup(code_edit)
	overlay._ensure_diagnostic_panel()
	(
		overlay
		. _add_diagnostic_entry(
			{"message": "Short", "actions": [{"kind": "docs"}]},
			[],
			"",
		)
	)
	overlay._layout_diagnostic_content()
	var short_width: float = overlay._diagnostic_scroll.custom_minimum_size.x
	var short_wrap_mode: int = overlay._diagnostic_wrap_labels[0].autowrap_mode
	overlay._clear_diagnostic_content()
	(
		overlay
		. _add_diagnostic_entry(
			{
				"message":
				(
					(
						"This diagnostic is deliberately repeated until its real rendered width exceeds "
						+ "the available editor viewport. "
					)
					. repeat(12)
				)
			},
			[],
			"",
		)
	)
	overlay._layout_diagnostic_content()
	var long_width: float = overlay._diagnostic_scroll.custom_minimum_size.x
	var long_wrap_mode: int = overlay._diagnostic_wrap_labels[0].autowrap_mode
	_expect(
		(
			short_width >= 360.0
			and short_wrap_mode == TextServer.AUTOWRAP_OFF
			and long_width <= code_edit.size.x - 56.0
			and long_wrap_mode == TextServer.AUTOWRAP_WORD_SMART
		),
		"diagnostic cards keep fitting content on one line and wrap only at the editor boundary",
	)
	overlay.cleanup()
	code_edit.remove_child(overlay)
	overlay.free()
	root.remove_child(code_edit)
	code_edit.free()


func _test_refactor_plan() -> void:
	var path := "res://tests/editor/fixtures/editor_refactor.ks"
	var plan := (
		KS_RefactorService
		. create_rename_plan(
			"branches",
			"intro",
			"opening",
			PackedStringArray([path]),
		)
	)
	_expect(plan["valid"], "cross-file rename produces a previewable valid plan")
	_expect(
		plan["changes"][0]["after"].contains("branch opening"),
		"rename plan updates semantic declarations",
	)
	var resource_plan := (
		KS_RefactorService
		. create_project_resource_rename_plan(
			"backgrounds",
			"bg_end",
			"bg_end_preview",
		)
	)
	_expect(resource_plan["valid"], "project resource rename produces a validated preview")
	var includes_owner_resource := false
	for change: Dictionary in resource_plan["changes"]:
		if String(change["path"]).ends_with("bg_list.tres"):
			includes_owner_resource = true
			break
	_expect(
		includes_owner_resource,
		"project resource rename includes the owning resource declaration",
	)
	var stale_plan := resource_plan.duplicate(true)
	stale_plan["changes"][0]["before"] += "\n# changed after preview"
	_expect(
		not KS_RefactorService.validate_plan(stale_plan).is_empty(),
		"refactor validation rejects stale previews before writing any file",
	)


func _test_runtime_debugger_resume() -> void:
	var manager := DebugManager.new()
	root.add_child(manager)
	KS_RuntimeDebugger._current_key = "res://debug.ks:1:node"
	KS_RuntimeDebugger._paused = true
	KS_RuntimeDebugger._paused_manager = weakref(manager)
	KS_RuntimeDebugger._capture_message("continue", [])
	await process_frame
	_expect(manager.resume_count == 1, "debugger Continue resumes the suspended dialogue manager")
	KS_RuntimeDebugger._paused = true
	KS_RuntimeDebugger._paused_manager = weakref(manager)
	KS_RuntimeDebugger._capture_message("step", [])
	await process_frame
	_expect(
		manager.resume_count == 2 and KS_RuntimeDebugger._step_after_resume,
		"debugger Step resumes once and arms a pause for the following statement",
	)
	KS_RuntimeDebugger._paused = false
	KS_RuntimeDebugger._pause_next = false
	KS_RuntimeDebugger._step_after_resume = false
	KS_RuntimeDebugger._resume_key = ""
	root.remove_child(manager)
	manager.free()


func _test_editor_plugin_contracts() -> void:
	var integration_script := (
		load("res://addons/konado/editor/ks_editor/ks_script_editor_integration.gd") as GDScript
	)
	var context_menu_script := (
		load("res://addons/konado/editor/ks_editor/ks_code_context_menu.gd") as GDScript
	)
	var debugger_script := (
		load("res://addons/konado/editor/ks_editor/ks_debugger_plugin.gd") as GDScript
	)
	_expect(
		_script_has_methods(
			integration_script,
			PackedStringArray(["get_instruction_tree", "get_docs_button", "get_locale_selector"]),
		),
		"KonadoScript extends the current native Script workspace",
	)
	_expect(
		_script_has_methods(
			context_menu_script,
			PackedStringArray(["_apply_quick_fix", "_apply_all_quick_fixes"]),
		),
		"quick fixes operate on the active native CodeEdit",
	)
	_expect(
		_script_has_methods(
			debugger_script, PackedStringArray(["_has_capture", "_capture", "_setup_session"])
		),
		"debugger plugin implements Godot's debugger protocol contract",
	)


func _script_has_methods(script: GDScript, required: PackedStringArray) -> bool:
	if script == null:
		return false
	var available := PackedStringArray()
	for method: Dictionary in script.get_script_method_list():
		available.append(String(method.get("name", "")))
	for method_name: String in required:
		if method_name not in available:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: %s" % message)
