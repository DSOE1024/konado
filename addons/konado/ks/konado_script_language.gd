@tool
extends ScriptLanguageExtension
class_name KND_KonadoScriptLanguage

## Godot Script Editor bridge for KonadoScript.
##
## This object is intentionally not registered as a runtime scripting language:
## KonadoScript is compiled to KND_Shot resources by the resource loader. KND_Shot
## returns this bridge while it is edited so Godot can provide its native script
## workspace, validation, outline, and completion UI.

const CARET_MARKER := "\uFFFF"
const COMPLETION_COLOR := Color(0.85, 0.72, 1.0)
const POSITION_VALUES := ["1", "2", "3", "4", "5"]
const COMPARISON_OPERATORS := ["==", "!=", ">", "<", ">=", "<="]
const BOOLEAN_VALUES := ["true", "false"]

var _diagnostics := KS_Diagnostics.new()
var _project_index := KS_ProjectIndex.shared()


func _get_name() -> String:
	return "KonadoScript"


func _get_type() -> String:
	return "KonadoScript"


func _get_extension() -> String:
	return "ks"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["ks"])


func _get_reserved_words() -> PackedStringArray:
	var keywords := PackedStringArray()
	for keyword: String in KS_Token.KEYWORDS:
		keywords.append(keyword)
	return keywords


func _is_control_flow_keyword(keyword: String) -> bool:
	return keyword in ["if", "else", "endif", "choice", "branch", "jump", "jump_branch"]


func _get_comment_delimiters() -> PackedStringArray:
	return PackedStringArray(["#"])


func _get_doc_comment_delimiters() -> PackedStringArray:
	return PackedStringArray()


func _get_string_delimiters() -> PackedStringArray:
	return PackedStringArray(['" "'])


func _get_built_in_templates(_object: StringName) -> Array[Dictionary]:
	return []


func _is_using_templates() -> bool:
	return false


func _supports_builtin_mode() -> bool:
	return false


func _supports_documentation() -> bool:
	return false


func _can_inherit_from_file() -> bool:
	return false


func _can_make_function() -> bool:
	return false


func _overrides_external_editor() -> bool:
	return false


func _validate(
	code: String,
	path: String,
	validate_functions: bool,
	validate_errors: bool,
	validate_warnings: bool,
	validate_safe_lines: bool,
) -> Dictionary:
	var result := {"valid": true}
	var diagnostics := _diagnostics.analyze(code, path, KS_EditorLocale.get_editor_locale())
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	for diagnostic: Dictionary in diagnostics:
		var line := int(diagnostic["line"])
		var column := int(diagnostic["column"])
		if diagnostic["severity"] == "error":
			(
				errors
				. append(
					{
						"path": path,
						"line": line,
						"column": column,
						"message": diagnostic["message"],
					}
				)
			)
		else:
			(
				warnings
				. append(
					{
						"start_line": line,
						"end_line": line,
						"code": 0,
						"string_code": "konado",
						"message": diagnostic["message"],
					}
				)
			)

	if validate_functions:
		result["functions"] = _collect_outline(code)
	if validate_errors:
		result["errors"] = errors
	if validate_warnings:
		result["warnings"] = warnings
	if validate_safe_lines:
		result["safe_lines"] = PackedInt32Array()
	result["valid"] = errors.is_empty()
	return result


func _find_function(function: String, code: String) -> int:
	for outline_entry: String in _collect_outline(code):
		if outline_entry.get_slice(":", 0) == function:
			return maxi(0, outline_entry.get_slice(":", 1).to_int() - 1)
	return -1


func _complete_code(code: String, _path: String, _owner: Object) -> Dictionary:
	var caret := code.find(CARET_MARKER)
	if caret < 0:
		return _empty_completion()
	var line_start := code.rfind("\n", caret - 1) + 1
	var line_prefix := code.substr(line_start, caret - line_start)
	var source := code.replace(CARET_MARKER, "")
	var options: Array[Dictionary] = []
	for candidate: Dictionary in _get_completion_candidates(source, line_prefix):
		(
			options
			. append(
				{
					"kind": candidate.get("kind", CodeEdit.CodeCompletionKind.KIND_KEYWORD),
					"display": candidate["text"],
					"insert_text": candidate["insert_text"],
					"font_color": COMPLETION_COLOR,
					"icon": null,
					"default_value": null,
					"location": CodeEdit.CodeCompletionLocation.LOCATION_LOCAL,
				}
			)
		)
	return {
		"result": OK,
		"options": options,
		"force": false,
		"call_hint": _get_call_hint(line_prefix),
	}


func _lookup_code(code: String, symbol: String, path: String, _owner: Object) -> Dictionary:
	var reference := _get_reference_at_caret(code)
	var source := code.replace(CARET_MARKER, "")
	var reference_kind := String(reference.get("kind", ""))
	var reference_name := String(reference.get("name", symbol))
	var lookup := {}
	# Godot treats the complete quoted dialogue as the native lookup token. Returning
	# a successful lookup for an interpolated variable would therefore underline the
	# whole string. The semantic-link overlay owns these exact inner-string spans.
	if bool(reference.get("inside_string", false)):
		return _empty_lookup()
	match reference_kind:
		"scripts":
			lookup = _lookup_script(reference_name)
		"branches", "variables", "signals":
			lookup = _lookup_local(source, reference_kind, reference_name, path)
	if not lookup.is_empty():
		return lookup
	# Commands have documentation but no source declaration. Project resources are
	# opened by the semantic-link controller because ScriptLanguage lookup can only
	# navigate to script lines and would incorrectly reuse the current `.ks` path.
	if not reference.is_empty():
		return _empty_lookup()
	var location := KS_SymbolIndex.find_branch_definition(source, symbol)
	if location < 0:
		return _empty_lookup()
	return {
		"result": OK,
		"type": LookupResultType.LOOKUP_RESULT_LOCAL_CONSTANT,
		"description":
		(
			KS_EditorLocale
			. text(
				"Branch declared on line %d." % location,
				"分支声明位于第 %d 行。" % location,
			)
		),
		"doc_type": "KonadoScript branch",
		"value": symbol,
		"script_path": path,
		"location": location,
	}


func _lookup_script(script_target: String) -> Dictionary:
	if script_target.is_empty() or not FileAccess.file_exists(script_target):
		return {}
	var target_script := ResourceLoader.load(script_target, "Script") as Script
	if target_script == null:
		return {}
	return {
		"result": OK,
		"type": LookupResultType.LOOKUP_RESULT_SCRIPT_LOCATION,
		"description":
		(
			KS_EditorLocale
			. text(
				"Open KonadoScript: %s" % script_target,
				"打开 KonadoScript：%s" % script_target,
			)
		),
		"doc_type": "KonadoScript file",
		"value": script_target,
		"script": target_script,
		"script_path": script_target,
		"location": 1,
	}


func _lookup_local(source: String, kind: String, name: String, path: String) -> Dictionary:
	var location := KS_SymbolIndex.find_local_definition(source, kind, name)
	if location < 0:
		return {}
	return {
		"result": OK,
		"type": LookupResultType.LOOKUP_RESULT_LOCAL_CONSTANT,
		"description":
		(
			KS_EditorLocale
			. text(
				(
					"%s '%s' is declared on line %d."
					% [kind.trim_suffix("s").capitalize(), name, location]
				),
				"%s“%s”声明于第 %d 行。" % [_local_kind_label(kind), name, location],
			)
		),
		"doc_type": "KonadoScript %s" % kind.trim_suffix("s"),
		"value": name,
		"script_path": path,
		"location": location,
	}


func _get_reference_at_caret(code: String) -> Dictionary:
	var caret := code.find(CARET_MARKER)
	if caret < 0:
		return {}
	var line_start := code.rfind("\n", caret - 1) + 1
	var line_end := code.find("\n", caret)
	if line_end < 0:
		line_end = code.length()
	var marked_line := code.substr(line_start, line_end - line_start)
	var caret_column := marked_line.find(CARET_MARKER)
	var line := marked_line.replace(CARET_MARKER, "")
	return KS_SymbolIndex.get_semantic_reference_at(line, caret_column)


func _local_kind_label(kind: String) -> String:
	return {"branches": "分支", "variables": "变量", "signals": "信号"}.get(kind, kind)


func _empty_lookup() -> Dictionary:
	return {"result": ERR_UNAVAILABLE, "type": LookupResultType.LOOKUP_RESULT_SCRIPT_LOCATION}


func _auto_indent_code(code: String, from_line: int, to_line: int) -> String:
	var lines := code.split("\n")
	if lines.is_empty():
		return code
	var first_line := clampi(from_line, 0, lines.size() - 1)
	var last_line := clampi(to_line, first_line, lines.size() - 1)
	var indent_unit := _detect_indent_unit(lines)
	var depth := 0
	for line_index: int in lines.size():
		var content := _strip_line_comment(String(lines[line_index])).strip_edges()
		var closes_before := content == "endif" or content == "else:" or content == "}"
		if closes_before:
			depth = maxi(0, depth - 1)
		if line_index >= first_line and line_index <= last_line:
			var raw_line := String(lines[line_index])
			var trimmed := raw_line.strip_edges(true, false)
			lines[line_index] = indent_unit.repeat(depth) + trimmed
		if content.begins_with("if ") and content.ends_with(":"):
			depth += 1
		elif content == "else:":
			depth += 1
		elif content.begins_with("screentext") and content.ends_with("{"):
			depth += 1
	return "\n".join(lines)


func _reload_scripts(_scripts: Array, _soft_reload: bool) -> void:
	pass


func _reload_tool_script(_script: Script, _soft_reload: bool) -> void:
	pass


func _get_public_functions() -> Array[Dictionary]:
	return []


func _get_public_constants() -> Dictionary:
	return {}


func _get_public_annotations() -> Array[Dictionary]:
	return []


func _get_global_class_name(_path: String) -> Dictionary:
	return {"name": ""}


func _collect_outline(source: String) -> PackedStringArray:
	var outline := PackedStringArray()
	var definitions := KS_SymbolIndex.get_branch_definitions(source)
	for branch_name: String in definitions:
		outline.append("%s:%d" % [branch_name, definitions[branch_name]])
	return outline


func _get_completion_candidates(source: String, line_prefix: String) -> Array[Dictionary]:
	var stripped := line_prefix.strip_edges()
	var ends_with_space := line_prefix.ends_with(" ") or line_prefix.ends_with("\t")
	var token_spans := KS_SymbolIndex.get_line_tokens(line_prefix)
	var tokens := PackedStringArray()
	for token_span: Dictionary in token_spans:
		tokens.append(String(token_span["text"]))
	var candidates: Array[Dictionary] = []
	if tokens.is_empty():
		candidates = _make_candidates(KS_LanguageCatalog.ROOT_KEYWORDS, "")
	elif bool(token_spans[0].get("quoted", false)):
		if tokens.size() >= 2 and bool(token_spans[1].get("quoted", false)):
			var voice_partial := ""
			if not ends_with_space and tokens.size() >= 3:
				voice_partial = tokens[-1]
			candidates = _make_candidates(_project_index.get_values("voices"), voice_partial)
	else:
		var root_keyword := tokens[0]
		var partial := "" if ends_with_space else tokens[-1]
		var argument_index := tokens.size() if ends_with_space else tokens.size() - 1
		var context_values := KS_LanguageCatalog.get_context_completions(root_keyword)
		if stripped.is_empty():
			candidates = _make_candidates(KS_LanguageCatalog.ROOT_KEYWORDS, "")
		elif tokens.size() == 1 and not ends_with_space:
			candidates = _make_candidates(KS_LanguageCatalog.ROOT_KEYWORDS, root_keyword)
			(
				candidates
				. append_array(
					(
						KS_LanguageCatalog
						. get_snippet_completions(
							root_keyword,
							KS_EditorLocale.get_editor_locale(),
						)
					)
				)
			)
		elif not context_values.is_empty() and argument_index == 1:
			candidates = _make_candidates(context_values, partial)
		elif root_keyword == "background" and argument_index == 1:
			candidates = _make_candidates(_project_index.get_values("backgrounds"), partial)
		elif root_keyword == "background" and argument_index == 2:
			candidates = _make_candidates(KS_LanguageCatalog.get_background_effects(), partial)
		elif root_keyword == "jump_branch" and argument_index == 1:
			candidates = _make_candidates(_get_branch_names(source), partial)
		elif root_keyword == "choice" and "->" in tokens:
			candidates = _make_candidates(_get_branch_names(source), partial)
		elif root_keyword == "jump" and argument_index == 1:
			candidates = _make_candidates(
				_project_index.get_values("scripts"),
				partial,
				CodeEdit.CodeCompletionKind.KIND_FILE_PATH,
			)
		elif root_keyword == "play" and argument_index == 2 and tokens.size() >= 2:
			var audio_kind := String(tokens[1])
			if audio_kind in ["bgm", "sfx"]:
				var resource_kind := "bgms" if audio_kind == "bgm" else "sfx"
				candidates = _make_candidates(_project_index.get_values(resource_kind), partial)
		elif root_keyword == "actor" and tokens.size() >= 2:
			var actor_action := String(tokens[1])
			if argument_index == 2:
				candidates = _make_candidates(
					_merge_values(
						_project_index.get_values("actors"),
						_collect_matches(
							source,
							"(?m)^\\s*actor\\s+show\\s+([\\p{L}_][\\p{L}\\p{N}_-]*)",
						),
					),
					partial,
				)
			elif actor_action in ["show", "change"] and argument_index == 3:
				candidates = _make_candidates(
					_project_index.get_actor_scoped_values(String(tokens[2]), "states"),
					partial,
				)
			elif actor_action == "show" and argument_index == 4:
				candidates = _make_candidates(PackedStringArray(["at"]), partial)
			elif actor_action == "show" and argument_index == 5:
				candidates = _make_candidates(POSITION_VALUES, partial)
			elif actor_action == "move" and argument_index == 3:
				candidates = _make_candidates(POSITION_VALUES, partial)
			elif actor_action == "motion" and argument_index == 3:
				candidates = _make_candidates(
					_project_index.get_actor_scoped_values(String(tokens[2]), "motions"),
					partial,
				)
		elif root_keyword in ["set", "add", "sub", "mul", "div", "if"] and argument_index == 1:
			candidates = _make_candidates(
				_collect_matches(
					source,
					"(?m)((?:%|\\$)[\\p{L}_][\\p{L}\\p{N}_]*)",
				),
				partial,
			)
		elif root_keyword == "if" and argument_index == 2:
			candidates = _make_candidates(COMPARISON_OPERATORS, partial)
		elif root_keyword == "achievement" and tokens.size() >= 2:
			if String(tokens[1]) == "set_flag" and argument_index == 3:
				candidates = _make_candidates(BOOLEAN_VALUES, partial)
		elif root_keyword == "waitsignal" and argument_index == 1:
			candidates = _make_candidates(
				_collect_local_symbol_names(source, "signals"),
				partial,
			)
		elif root_keyword in ["cam", "asyncam"] and tokens.size() >= 2:
			var camera_action := String(tokens[1])
			if camera_action == "move" and argument_index == 2:
				candidates = _make_candidates(_project_index.get_values("cameras"), partial)
			elif (
				(camera_action == "move" and argument_index == 3)
				or (camera_action == "reset" and argument_index == 2)
			):
				candidates = _make_candidates(KS_LanguageCatalog.CAMERA_TRANSITIONS, partial)
	return candidates


func _make_candidates(
	values: Variant,
	partial: String,
	kind: CodeEdit.CodeCompletionKind = CodeEdit.CodeCompletionKind.KIND_KEYWORD,
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var normalized_partial := partial.to_lower()
	for value: String in values:
		if (
			not normalized_partial.is_empty()
			and not value.to_lower().begins_with(normalized_partial)
		):
			continue
		candidates.append({"text": value, "insert_text": value, "kind": kind})
	return candidates


func _get_branch_names(source: String) -> PackedStringArray:
	var names := PackedStringArray(KS_SymbolIndex.get_branch_definitions(source).keys())
	names.sort()
	return names


func _merge_values(first: PackedStringArray, second: PackedStringArray) -> PackedStringArray:
	var merged := first.duplicate()
	for value: String in second:
		if not merged.has(value):
			merged.append(value)
	merged.sort()
	return merged


func _collect_matches(source: String, pattern: String) -> PackedStringArray:
	var values := PackedStringArray()
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return values
	for match_result: RegExMatch in regex.search_all(source):
		var value := match_result.get_string(1)
		if not values.has(value):
			values.append(value)
	values.sort()
	return values


func _collect_local_symbol_names(source: String, kind: String) -> PackedStringArray:
	var values := PackedStringArray()
	for reference: Dictionary in KS_SymbolIndex.get_semantic_references(source):
		if reference.get("kind") != kind:
			continue
		var value := String(reference.get("name", ""))
		if not value.is_empty() and not values.has(value):
			values.append(value)
	values.sort()
	return values


func _empty_completion() -> Dictionary:
	return {
		"result": OK,
		"options": [],
		"force": false,
		"call_hint": "",
	}


func _get_call_hint(line_prefix: String) -> String:
	var tokens := line_prefix.strip_edges().replace("\t", " ").split(" ", false)
	if tokens.is_empty():
		return ""
	var command := String(tokens[0])
	if tokens.size() >= 2:
		var contextual_command := "%s %s" % [tokens[0], tokens[1]]
		if not KS_LanguageCatalog.get_signature(contextual_command).is_empty():
			command = contextual_command
	var signature := KS_LanguageCatalog.get_signature(command)
	if signature.is_empty():
		return ""
	var root_command := String(tokens[0])
	var description := (
		KS_LanguageCatalog
		. get_command_description(
			root_command,
			KS_EditorLocale.get_editor_locale(),
		)
	)
	return signature if description.is_empty() else "%s\n%s" % [signature, description]


func _detect_indent_unit(lines: PackedStringArray) -> String:
	var minimum_spaces := 0
	for line: String in lines:
		if line.begins_with("\t"):
			return "\t"
		var spaces := line.length() - line.strip_edges(true, false).length()
		if spaces > 0 and (minimum_spaces == 0 or spaces < minimum_spaces):
			minimum_spaces = spaces
	if minimum_spaces > 0:
		return " ".repeat(minimum_spaces)
	if Engine.is_editor_hint():
		var settings := EditorInterface.get_editor_settings()
		if settings != null:
			var indent_type := int(settings.get_setting("text_editor/behavior/indent/type"))
			var indent_size := int(settings.get_setting("text_editor/behavior/indent/size"))
			return "\t" if indent_type == 0 else " ".repeat(maxi(1, indent_size))
	return "    "


func _strip_line_comment(line: String) -> String:
	var inside_string := false
	var escaped := false
	for column: int in line.length():
		var character := line.substr(column, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and inside_string:
			escaped = true
		elif character == '"':
			inside_string = not inside_string
		elif character == "#" and not inside_string:
			return line.left(column)
	return line
