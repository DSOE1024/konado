@tool
extends RefCounted
class_name KS_SymbolIndex

## Structural symbol utilities shared by language lookup and editor refactoring.

const IDENTIFIER_PATTERN := "[\\p{L}_][\\p{L}\\p{N}_-]*"

static var _definition_regex: RegEx
static var _jump_regex: RegEx
static var _choice_regex: RegEx
static var _script_jump_regex: RegEx
static var _variable_regex: RegEx


static func get_branch_definitions(source: String) -> Dictionary:
	_ensure_regexes()
	var definitions := {}
	var lines := source.split("\n")
	for index: int in lines.size():
		var match_result := _definition_regex.search(lines[index])
		if match_result == null:
			continue
		var symbol := match_result.get_string(1)
		if not definitions.has(symbol):
			definitions[symbol] = index + 1
	return definitions


static func get_branch_references(source: String) -> Array[Dictionary]:
	_ensure_regexes()
	var references: Array[Dictionary] = []
	var lines := source.split("\n")
	for index: int in lines.size():
		var line := String(lines[index])
		_append_match(references, _definition_regex.search(line), index + 1, "definition")
		_append_match(references, _jump_regex.search(line), index + 1, "reference")
		_append_match(references, _choice_regex.search(line), index + 1, "reference")
	return references


static func find_branch_definition(source: String, symbol: String) -> int:
	return int(get_branch_definitions(source).get(symbol, -1))


static func find_script_jump_at_caret(code: String, caret_marker: String) -> String:
	var caret := code.find(caret_marker)
	if caret < 0:
		return ""
	_ensure_regexes()
	var line_start := code.rfind("\n", caret - 1) + 1
	var line_end := code.find("\n", caret)
	if line_end < 0:
		line_end = code.length()
	var marked_line := code.substr(line_start, line_end - line_start)
	var caret_column := marked_line.find(caret_marker)
	var line := marked_line.replace(caret_marker, "")
	return String(find_script_jump_span(line, caret_column).get("path", ""))


static func find_script_jump_span(line: String, column: int) -> Dictionary:
	_ensure_regexes()
	var match_result := _script_jump_regex.search(line)
	if match_result == null:
		return {}
	var target_start := match_result.get_start(1)
	var target_end := match_result.get_end(1)
	if column < target_start or column >= target_end:
		return {}
	return {
		"kind": "scripts",
		"name": match_result.get_string(1),
		"path": match_result.get_string(1),
		"line": 0,
		"start": target_start,
		"end": target_end,
	}


static func get_semantic_reference_at(
	line: String,
	column: int,
	screentext_content: bool = false,
) -> Dictionary:
	var reference := find_script_jump_span(line, column)
	if not reference.is_empty():
		return reference
	var references := get_line_semantic_references(line, screentext_content)
	for candidate: Dictionary in references:
		if column >= int(candidate["start"]) and column < int(candidate["end"]):
			return candidate
	return {}


static func get_line_semantic_references(
	line: String,
	screentext_content: bool = false,
) -> Array[Dictionary]:
	var tokens := _tokenize_line_spans(line)
	var references: Array[Dictionary] = []
	if tokens.is_empty():
		return references
	var first := String(tokens[0]["text"])
	if bool(tokens[0]["quoted"]):
		if screentext_content:
			return _get_string_variable_references(line, tokens[0])
		_append_quoted_token_reference(references, tokens[0], "actors", "reference")
		if tokens.size() >= 3:
			_append_quoted_token_reference(references, tokens[2], "voices", "reference")
		references.append_array(_get_dialogue_variable_references(line, tokens))
		return references
	if KS_LanguageCatalog.ROOT_KEYWORDS.has(first):
		_append_token_reference(references, tokens[0], "commands", "definition")
	match first:
		"background":
			_append_argument_reference(references, tokens, 1, "backgrounds")
			_append_argument_reference(references, tokens, 2, "effects")
		"actor":
			if tokens.size() >= 3:
				var action := String(tokens[1]["text"])
				_append_argument_reference(references, tokens, 2, "actors")
				if action in ["show", "change"]:
					_append_argument_reference(
						references,
						tokens,
						3,
						"states",
						String(tokens[2]["text"]),
					)
				elif action == "motion":
					_append_argument_reference(
						references,
						tokens,
						3,
						"motions",
						String(tokens[2]["text"]),
					)
		"play":
			if tokens.size() >= 3:
				var kind := "bgms" if String(tokens[1]["text"]) == "bgm" else "sfx"
				_append_argument_reference(references, tokens, 2, kind)
		"cam", "asyncam":
			if tokens.size() >= 3 and String(tokens[1]["text"]) == "move":
				_append_argument_reference(references, tokens, 2, "cameras")
		"branch":
			_append_argument_reference(references, tokens, 1, "branches", "", "definition")
		"jump_branch":
			_append_argument_reference(references, tokens, 1, "branches")
		"choice":
			for index: int in tokens.size():
				if String(tokens[index]["text"]) == "->":
					_append_argument_reference(references, tokens, index + 1, "branches")
					break
		"set":
			_append_argument_reference(references, tokens, 1, "variables", "", "definition")
		"add", "sub", "mul", "div", "if":
			_append_argument_reference(references, tokens, 1, "variables")
		"signal":
			_append_remaining_reference(references, tokens, 1, "signals", "definition")
		"waitsignal":
			_append_argument_reference(references, tokens, 1, "signals")
		"achievement":
			_append_argument_reference(references, tokens, 2, "achievements")
	for token: Dictionary in tokens:
		var text := String(token["text"])
		if not text.begins_with("%") and not text.begins_with("$"):
			continue
		var already_indexed := false
		for existing: Dictionary in references:
			if existing["start"] == token["start"] and existing["end"] == token["end"]:
				already_indexed = true
				break
		if not already_indexed:
			_append_token_reference(references, token, "variables", "reference")
	return references


static func get_line_tokens(line: String) -> Array[Dictionary]:
	return _tokenize_line_spans(line)


static func get_dialogue_variable_references(line: String) -> Array[Dictionary]:
	return _get_dialogue_variable_references(line, _tokenize_line_spans(line))


static func get_semantic_references(source: String) -> Array[Dictionary]:
	var references: Array[Dictionary] = []
	var lines := source.split("\n")
	var inside_screentext := false
	for line_index: int in lines.size():
		var line := String(lines[line_index])
		for reference: Dictionary in get_line_semantic_references(line, inside_screentext):
			reference["line"] = line_index + 1
			reference["column"] = int(reference["start"]) + 1
			references.append(reference)
		if inside_screentext:
			if _is_screentext_close_line(line):
				inside_screentext = false
		elif _is_screentext_open_line(line):
			inside_screentext = true
	return references


static func is_screentext_content_line(source: String, target_line: int) -> bool:
	if target_line < 0:
		return false
	var lines := source.split("\n")
	var inside_screentext := false
	for line_index: int in mini(target_line + 1, lines.size()):
		var line := String(lines[line_index])
		if line_index == target_line:
			return inside_screentext
		if inside_screentext:
			if _is_screentext_close_line(line):
				inside_screentext = false
		elif _is_screentext_open_line(line):
			inside_screentext = true
	return false


static func get_local_symbol_references(
	source: String,
	kind: String,
	name: String,
) -> Array[Dictionary]:
	var references: Array[Dictionary] = []
	for reference: Dictionary in get_semantic_references(source):
		if reference.get("kind") == kind and reference.get("name") == name:
			references.append(reference)
	return references


static func find_local_definition(source: String, kind: String, name: String) -> int:
	for reference: Dictionary in get_local_symbol_references(source, kind, name):
		if reference.get("role") == "definition":
			return int(reference["line"])
	return -1


static func rename_branch(source: String, old_name: String, new_name: String) -> String:
	if (
		old_name == new_name
		or not is_valid_identifier(old_name)
		or not is_valid_identifier(new_name)
	):
		return source
	var updated_lines := PackedStringArray()
	for line: String in source.split("\n"):
		updated_lines.append(_rename_line(line, old_name, new_name))
	return "\n".join(updated_lines)


static func rename_local_symbol(
	source: String,
	kind: String,
	old_name: String,
	new_name: String,
) -> String:
	if old_name == new_name or not is_valid_local_symbol(kind, new_name):
		return source
	if kind == "branches":
		return rename_branch(source, old_name, new_name)
	var references := get_local_symbol_references(source, kind, old_name)
	references.reverse()
	var updated := source
	var line_offsets := PackedInt32Array([0])
	for index: int in source.length():
		if source[index] == "\n":
			line_offsets.append(index + 1)
	for reference: Dictionary in references:
		var line_index := int(reference["line"]) - 1
		if line_index < 0 or line_index >= line_offsets.size():
			continue
		var start := line_offsets[line_index] + int(reference["start"])
		var end := line_offsets[line_index] + int(reference["end"])
		updated = updated.left(start) + new_name + updated.substr(end)
	return updated


static func is_valid_identifier(symbol: String) -> bool:
	var regex := RegEx.new()
	if regex.compile("^%s$" % IDENTIFIER_PATTERN) != OK:
		return false
	return regex.search(symbol) != null


static func is_valid_local_symbol(kind: String, symbol: String) -> bool:
	if kind == "variables":
		if symbol.length() < 2 or symbol.left(1) not in ["%", "$"]:
			return false
		return is_valid_identifier(symbol.substr(1))
	return is_valid_identifier(symbol)


static func _tokenize_line_spans(line: String) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	var column := 0
	while column < line.length():
		var character := line.substr(column, 1)
		if character in [" ", "\t"]:
			column += 1
			continue
		if character == "#":
			break
		if character == '"':
			var string_start := column
			column += 1
			var value := ""
			var escaped := false
			while column < line.length():
				character = line.substr(column, 1)
				if escaped:
					value += character
					escaped = false
					column += 1
					continue
				if character == "\\":
					escaped = true
					column += 1
					continue
				if character == '"':
					column += 1
					break
				value += character
				column += 1
			(
				tokens
				. append(
					{
						"text": value,
						"start": string_start + 1,
						"end": maxi(string_start + 1, column - 1),
						"quoted_start": string_start,
						"quoted_end": column,
						"quoted": true,
					}
				)
			)
			continue
		var token_start := column
		if character == "-" and column + 1 < line.length() and line[column + 1] == ">":
			column += 2
		else:
			while column < line.length():
				character = line.substr(column, 1)
				if character in [" ", "\t", "#"]:
					break
				column += 1
		(
			tokens
			. append(
				{
					"text": line.substr(token_start, column - token_start),
					"start": token_start,
					"end": column,
					"quoted": false,
				}
			)
		)
	return tokens


static func _append_argument_reference(
	references: Array[Dictionary],
	tokens: Array[Dictionary],
	index: int,
	kind: String,
	scope_name: String = "",
	role: String = "reference",
) -> void:
	if index < 0 or index >= tokens.size():
		return
	_append_token_reference(references, tokens[index], kind, role, scope_name)


static func _append_token_reference(
	references: Array[Dictionary],
	token: Dictionary,
	kind: String,
	role: String,
	scope_name: String = "",
) -> void:
	var name := String(token.get("text", ""))
	if name.is_empty():
		return
	var reference := {
		"kind": kind,
		"name": name,
		"role": role,
		"start": int(token["start"]),
		"end": int(token["end"]),
	}
	if not scope_name.is_empty():
		reference["scope_name"] = scope_name
	references.append(reference)


static func _append_quoted_token_reference(
	references: Array[Dictionary],
	token: Dictionary,
	kind: String,
	role: String,
) -> void:
	var quoted_token := token.duplicate()
	quoted_token["start"] = token.get("quoted_start", token["start"])
	quoted_token["end"] = token.get("quoted_end", token["end"])
	_append_token_reference(references, quoted_token, kind, role)


static func _get_dialogue_variable_references(
	line: String,
	tokens: Array[Dictionary],
) -> Array[Dictionary]:
	if tokens.size() < 2 or not bool(tokens[0]["quoted"]) or not bool(tokens[1]["quoted"]):
		return []
	return _get_string_variable_references(line, tokens[1])


static func _get_string_variable_references(
	line: String,
	token: Dictionary,
) -> Array[Dictionary]:
	var references: Array[Dictionary] = []
	_ensure_regexes()
	var content_start := int(token["start"])
	var content_end := int(token["end"])
	for match_result: RegExMatch in _variable_regex.search_all(line, content_start, content_end):
		var variable_token := {
			"text": match_result.get_string(),
			"start": match_result.get_start(),
			"end": match_result.get_end(),
		}
		_append_token_reference(references, variable_token, "variables", "reference")
		references[-1]["inside_string"] = true
	return references


static func _is_screentext_open_line(line: String) -> bool:
	var tokens := _tokenize_line_spans(line)
	return (
		tokens.size() >= 2
		and tokens[0].get("text") == "screentext"
		and tokens[1].get("text") == "{"
	)


static func _is_screentext_close_line(line: String) -> bool:
	var tokens := _tokenize_line_spans(line)
	return tokens.size() == 1 and tokens[0].get("text") == "}"


static func _append_remaining_reference(
	references: Array[Dictionary],
	tokens: Array[Dictionary],
	start_index: int,
	kind: String,
	role: String,
) -> void:
	if start_index < 0 or start_index >= tokens.size():
		return
	var name_parts := PackedStringArray()
	for index: int in range(start_index, tokens.size()):
		name_parts.append(String(tokens[index]["text"]))
	var token := {
		"text": " ".join(name_parts),
		"start": tokens[start_index]["start"],
		"end": tokens[-1]["end"],
	}
	_append_token_reference(references, token, kind, role)


static func _rename_line(line: String, old_name: String, new_name: String) -> String:
	_ensure_regexes()
	for regex: RegEx in [_definition_regex, _jump_regex, _choice_regex]:
		var match_result := regex.search(line)
		if match_result == null or match_result.get_string(1) != old_name:
			continue
		var start := match_result.get_start(1)
		var end := match_result.get_end(1)
		return line.left(start) + new_name + line.substr(end)
	return line


static func _append_match(
	references: Array[Dictionary],
	match_result: RegExMatch,
	line: int,
	kind: String,
) -> void:
	if match_result == null:
		return
	(
		references
		. append(
			{
				"symbol": match_result.get_string(1),
				"line": line,
				"column": match_result.get_start(1) + 1,
				"kind": kind,
			}
		)
	)


static func _ensure_regexes() -> void:
	if _definition_regex != null:
		return
	_definition_regex = RegEx.new()
	_jump_regex = RegEx.new()
	_choice_regex = RegEx.new()
	_script_jump_regex = RegEx.new()
	_variable_regex = RegEx.new()
	var identifier_end := "(?![\\p{L}\\p{N}_-])"
	_definition_regex.compile("^\\s*branch\\s+(%s)%s" % [IDENTIFIER_PATTERN, identifier_end])
	_jump_regex.compile("^\\s*jump_branch\\s+(%s)%s" % [IDENTIFIER_PATTERN, identifier_end])
	_choice_regex.compile(
		"^\\s*choice\\s+.+?\\s*->\\s*(%s)%s" % [IDENTIFIER_PATTERN, identifier_end]
	)
	_script_jump_regex.compile("^\\s*jump\\s+(res://[^\\s#]+\\.ks)\\s*(?:#.*)?$")
	_variable_regex.compile("(%|\\$)[\\p{L}_][\\p{L}\\p{N}_-]*")
