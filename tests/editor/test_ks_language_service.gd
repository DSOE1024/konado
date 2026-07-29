extends SceneTree

const CARET_MARKER := "\uFFFF"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if Engine.is_editor_hint():
		await EditorInterface.get_resource_filesystem().filesystem_changed
		while (
			EditorInterface.get_resource_filesystem().is_scanning()
			or EditorInterface.get_resource_filesystem().is_importing()
		):
			await process_frame
	_test_parser_strictness()
	_test_project_index()
	_test_semantic_navigation()
	await _test_link_geometry()
	_test_project_diagnostics()
	_test_project_scripts_compile()
	if _failures == 0:
		print("PASS: KonadoScript language service tests")
	quit(_failures)


func _test_parser_strictness() -> void:
	var lexer := KS_Lexer.new()
	lexer.console_output_enabled = false
	var tokens := lexer.tokenize("    branch opening-scene # inline comment", "strictness.ks")
	_expect(lexer.get_errors().is_empty(), "inline comments are ignored by the lexer")
	_expect(
		tokens.size() >= 3 and tokens[2].value == "opening-scene" and tokens[2].column == 12,
		"hyphenated identifiers retain their real indented source column",
	)
	var malformed_variable_tokens := lexer.tokenize("set % 1", "strictness.ks")
	_expect(
		not malformed_variable_tokens.is_empty(),
		"an isolated variable prefix is consumed without stalling live analysis",
	)
	var compiler := KS_Compiler.new()
	compiler.set_console_output_enabled(false)
	_expect(
		compiler.compile_string("branch opening-scene\n    end", "strictness.ks") != null,
		"refactorable branch names are accepted by the compiler",
	)
	_expect(
		compiler.compile_string("background bg_end fade unexpected", "strictness.ks") == null,
		"fixed-arity commands reject trailing arguments",
	)
	_expect(
		compiler.compile_string("cam move cam2 linear invalid", "strictness.ks") == null,
		"camera durations reject non-numeric values",
	)
	_expect(
		compiler.compile_string("asyncam move cam2 ease_in_out 1.0", "strictness.ks") != null,
		"documented ease-in-out camera transitions compile",
	)
	_expect(
		compiler.compile_string("achievement set_flag flag maybe", "strictness.ks") == null,
		"achievement booleans reject ambiguous values",
	)
	_expect(
		compiler.compile_string("set $score", "strictness.ks") == null,
		"variable operations require an explicit value",
	)
	_expect(
		compiler.compile_string("if $score == 1.5:\nendif", "strictness.ks") == null,
		"integer conditions reject silently truncated decimal values",
	)
	_expect(
		compiler.compile_string("jump user://story.ks", "strictness.ks") == null,
		"cross-script jumps require an exported res:// KonadoScript path",
	)
	_expect(
		compiler.compile_string("showtextbox\nhidetextbox\nend", "strictness.ks") != null,
		"optional text-box durations match the language signature",
	)
	var diagnostics := KS_Diagnostics.new()
	var recovered := (
		diagnostics
		. analyze(
			"endif_bad\nbackground bg_end fade unexpected\nactor move Kona invalid",
			"strictness.ks",
		)
	)
	_expect(
		(
			_has_diagnostic_line(recovered, 1)
			and _has_diagnostic_line(recovered, 2)
			and _has_diagnostic_line(recovered, 3)
		),
		"parser recovery reports independent errors from multiple lines in one pass",
	)
	var lexical_errors := diagnostics.analyze('"first\n"second', "strictness.ks")
	_expect(
		_has_diagnostic_line(lexical_errors, 1) and _has_diagnostic_line(lexical_errors, 2),
		"lexer recovery reports multiple malformed strings in one pass",
	)
	var indented_lexical_error := diagnostics.analyze('    "unfinished', "strictness.ks")
	_expect(
		indented_lexical_error.size() == 1 and indented_lexical_error[0].get("column") == 5,
		"lexical diagnostics preserve columns after indentation",
	)


func _test_project_index() -> void:
	var project_index := KS_ProjectIndex.shared()
	project_index.invalidate()
	var background := project_index.get_definition("backgrounds", "bg_end")
	_expect(
		(
			background.get("owner_path") == "res://sample/demo/bg_list.tres"
			and background.get("target_path") == "res://sample/demo/backgrounds/bg_end.tscn"
			and int(background.get("line", 0)) > 0
		),
		"background IDs map to their declaration and final scene",
	)
	var actor := project_index.get_definition("actors", "Kona")
	_expect(
		actor.get("target_path") == "res://sample/demo/sample_character.tscn",
		"actor IDs map to character scenes",
	)
	_expect(
		project_index.get_actor_scoped_values("Kona", "states").has("正常"),
		"state completion is scoped to the selected actor scene",
	)


func _test_semantic_navigation() -> void:
	var line := "background bg_end fade"
	var reference := KS_SymbolIndex.get_semantic_reference_at(line, line.find("bg_end") + 2)
	_expect(
		(
			reference.get("kind") == "backgrounds"
			and reference.get("name") == "bg_end"
			and reference.get("start") == line.find("bg_end")
			and reference.get("end") == line.find("bg_end") + "bg_end".length()
		),
		"semantic spans cover complete resource identifiers",
	)
	var link_controller := KS_JumpLinkOverlay.new()
	var native_lookup_editor := CodeEdit.new()
	native_lookup_editor.set_symbol_lookup_on_click_enabled(true)
	native_lookup_editor.set_symbol_tooltip_on_hover_enabled(true)
	native_lookup_editor.add_child(link_controller)
	link_controller.setup(native_lookup_editor)
	_expect(
		(
			not native_lookup_editor.is_symbol_lookup_on_click_enabled()
			and not native_lookup_editor.is_symbol_tooltip_on_hover_enabled()
			and link_controller.anchor_right == 1.0
			and link_controller.anchor_bottom == 1.0
		),
		"Konado semantic links use a full-size overlay and disable native word links",
	)
	var targets := link_controller.resolve_navigation_targets(reference, line)
	_expect(
		(
			targets.size() == 1
			and targets[0].get("path") == "res://sample/demo/backgrounds/bg_end.tscn"
		),
		"background navigation resolves the final scene",
	)
	var navigation_cases := [
		{
			"line": "actor show Kona 正常 at 1",
			"token": "Kona",
			"target": "res://sample/demo/sample_character.tscn",
		},
		{
			"line": "actor show Kona 正常 at 1",
			"token": "正常",
			"target": "res://sample/demo/sample_character.tscn",
		},
		{
			"line": "actor motion Kona jump",
			"token": "jump",
			"target": "res://addons/konado/template/default/character/actor_motion_layer.tscn",
		},
		{
			"line": "play bgm echo",
			"token": "echo",
			"target": "res://sample/demo/bgm/EchoesOfHome.mp3",
		},
		{
			"line": "cam move cam2",
			"token": "cam2",
			"target": "res://sample/demo/backgrounds/bg_para.tscn",
		},
	]
	for test_case: Dictionary in navigation_cases:
		var case_line := String(test_case["line"])
		var case_reference := (
			KS_SymbolIndex
			. get_semantic_reference_at(
				case_line,
				case_line.find(String(test_case["token"])),
			)
		)
		var case_targets := link_controller.resolve_navigation_targets(case_reference, case_line)
		_expect(
			not case_targets.is_empty() and case_targets[0].get("path") == test_case["target"],
			"semantic navigation resolves %s" % test_case["token"],
		)
	var dialogue_line := '"Kona" "回合=$score，奖励=%bonus"'
	var speaker_reference := KS_SymbolIndex.get_semantic_reference_at(dialogue_line, 1)
	var dialogue_variable := (
		KS_SymbolIndex
		. get_semantic_reference_at(
			dialogue_line,
			dialogue_line.find("$score") + 2,
		)
	)
	_expect(
		(
			speaker_reference.get("start") == 0
			and speaker_reference.get("end") == '"Kona"'.length()
			and dialogue_variable.get("kind") == "variables"
			and dialogue_variable.get("name") == "$score"
			and dialogue_variable.get("start") == dialogue_line.find("$score")
			and (dialogue_variable.get("end") == dialogue_line.find("$score") + "$score".length())
		),
		"quoted actor links include their quotes and dialogue variable links use exact spans",
	)
	var highlighter := KND_KsHighlighter.new()
	var highlighting := highlighter._highlight_line_text(dialogue_line, Color.WHITE)
	_expect(
		(
			(
				_color_at(highlighting, dialogue_line.find("$score"), Color.WHITE)
				== KND_KsHighlighter.VARIABLE_COLOR
			)
			and (
				_color_at(highlighting, dialogue_line.find("%bonus"), Color.WHITE)
				== KND_KsHighlighter.VARIABLE_COLOR
			)
		),
		"variables interpolated inside dialogue strings retain variable highlighting",
	)
	var local_source := "set $score 0\n%s" % dialogue_line
	var local_reference := (
		KS_SymbolIndex
		. get_semantic_reference_at(
			dialogue_line,
			dialogue_line.find("$score"),
		)
	)
	var local_targets := link_controller.resolve_navigation_targets(local_reference, local_source)
	_expect(
		local_targets.size() == 1 and local_targets[0].get("line") == 1,
		"local variable navigation resolves its declaration",
	)
	link_controller.cleanup()
	_expect(
		(
			native_lookup_editor.is_symbol_lookup_on_click_enabled()
			and native_lookup_editor.is_symbol_tooltip_on_hover_enabled()
		),
		"native link behavior is restored after leaving KonadoScript",
	)
	native_lookup_editor.free()
	var language := KND_KonadoScriptLanguage.new()
	var embedded_lookup := (
		language
		. _lookup_code(
			'set $score 0\n"Kona" "回合=$s%score"' % CARET_MARKER,
			"$score",
			"res://source.ks",
			null,
		)
	)
	_expect(
		embedded_lookup.get("result") == ERR_UNAVAILABLE,
		"dialogue variables defer to exact-span semantic links instead of native string lookup",
	)
	var lookup := (
		language
		. _lookup_code(
			"background bg_%send fade" % CARET_MARKER,
			"bg_end",
			"res://source.ks",
			null,
		)
	)
	_expect(
		lookup.get("result") == ERR_UNAVAILABLE,
		"project resources defer to the scene and resource navigation layer",
	)
	lookup = (
		language
		. _lookup_code(
			"jump_%sbranch final" % CARET_MARKER,
			"jump_branch",
			"res://source.ks",
			null,
		)
	)
	_expect(
		lookup.get("result") == ERR_UNAVAILABLE,
		"command keywords never masquerade as source declarations",
	)


func _test_project_diagnostics() -> void:
	var diagnostics := KS_Diagnostics.new()
	_expect(
		diagnostics.analyze("background bg_end fade", "semantic.ks").is_empty(),
		"valid indexed resources do not produce false diagnostics",
	)
	var missing := diagnostics.analyze("play sfx missing_effect", "semantic.ks", "en")
	_expect(
		(
			not missing.is_empty()
			and missing[0]["message"] == "Unknown sound effect: 'missing_effect'."
		),
		"unknown resource IDs are reported in the editor locale",
	)


func _test_project_scripts_compile() -> void:
	for path: String in KS_ProjectIndex.shared().get_values("scripts"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_expect(false, "indexed KonadoScript can be read: %s" % path)
			continue
		var compiler := KS_Compiler.new()
		compiler.set_console_output_enabled(false)
		var valid := compiler.validate_string(file.get_as_text(), path)
		_expect(
			valid,
			(
				"project KonadoScript passes the strict parser: %s (%s)"
				% [path, "; ".join(compiler.get_errors())]
			),
		)


func _test_link_geometry() -> void:
	var editor := CodeEdit.new()
	editor.size = Vector2(1000, 200)
	editor.text = "\tactor show Kona normal at 1"
	root.add_child(editor)
	var overlay := KS_JumpLinkOverlay.new()
	editor.add_child(overlay)
	overlay.setup(editor)
	await process_frame
	var token_start := editor.get_line(0).find("Kona")
	var boundary_rect := editor.get_rect_at_line_column(0, token_start)
	var character_rect := overlay._get_character_rect(0, token_start)
	_expect(
		boundary_rect.position.x >= 0 and character_rect.position.x == boundary_rect.end.x,
		"semantic underlines map caret boundaries to the following visible grapheme",
	)
	overlay.cleanup()
	editor.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _has_diagnostic_line(diagnostics: Array[Dictionary], line: int) -> bool:
	for diagnostic: Dictionary in diagnostics:
		if diagnostic.get("line") == line:
			return true
	return false


func _color_at(highlighting: Dictionary, column: int, default_color: Color) -> Color:
	var color := default_color
	for start_column: int in highlighting:
		if start_column > column:
			break
		color = highlighting[start_column]["color"]
	return color
