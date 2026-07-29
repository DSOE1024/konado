extends RefCounted
class_name KS_Diagnostics

var _location_regex := RegEx.new()
var _project_index := KS_ProjectIndex.shared()


func _init() -> void:
	_location_regex.compile("\\[行：(\\d+)(?:, 列：(\\d+))?\\]\\s*(.*)$")


func analyze(source: String, path: String, locale: String = "") -> Array[Dictionary]:
	var compiler := KS_Compiler.new()
	compiler.set_console_output_enabled(false)
	compiler.validate_string(source, path)

	var diagnostics: Array[Dictionary] = []
	for error: String in compiler.get_errors():
		diagnostics.append(_parse_message(error, "error", locale))
	for warning: String in compiler.get_warnings():
		diagnostics.append(_parse_message(warning, "warning", locale))
	if compiler.get_errors().is_empty():
		_append_project_diagnostics(diagnostics, source, path, locale)
	diagnostics.sort_custom(_sort_diagnostics)
	return diagnostics


func _append_project_diagnostics(
	diagnostics: Array[Dictionary],
	source: String,
	path: String,
	locale: String,
) -> void:
	var seen := {}
	for reference: Dictionary in KS_SymbolIndex.get_semantic_references(source):
		var kind := String(reference.get("kind", ""))
		if (
			kind
			not in [
				"actors",
				"backgrounds",
				"bgms",
				"sfx",
				"voices",
				"states",
				"motions",
				"cameras",
			]
		):
			continue
		var name := String(reference.get("name", ""))
		var definitions: Array[Dictionary]
		if kind in ["states", "motions"]:
			definitions = (
				_project_index
				. get_actor_scoped_targets(
					String(reference.get("scope_name", "")),
					kind,
					name,
				)
			)
		else:
			definitions = _project_index.get_definitions(kind, name)
		var message := ""
		if definitions.is_empty():
			message = "未找到%s '%s'" % [_kind_label(kind), name]
		elif (
			kind in KS_ProjectIndex.DUPLICATE_GLOBAL_KINDS
			and _has_same_owner_duplicate(definitions)
		):
			message = "%s '%s' 存在 %d 个重复定义" % [_kind_label(kind), name, definitions.size()]
		else:
			for definition: Dictionary in definitions:
				var target_path := String(definition.get("target_path", ""))
				if (
					target_path.is_empty()
					and kind in ["actors", "backgrounds", "bgms", "sfx", "voices"]
				):
					message = "%s '%s' 未配置目标资源" % [_kind_label(kind), name]
					break
				if not target_path.is_empty() and not FileAccess.file_exists(target_path):
					message = (
						"%s '%s' 的目标资源不存在：%s"
						% [
							_kind_label(kind),
							name,
							target_path,
						]
					)
					break
		if message.is_empty():
			continue
		var line := int(reference.get("line", 1))
		var key := "%d:%s" % [line, message]
		if seen.has(key):
			continue
		seen[key] = true
		(
			diagnostics
			. append(
				{
					"severity": "warning",
					"line": line,
					"column": int(reference.get("column", 1)),
					"message": KS_DiagnosticMessages.localize(message, locale),
					"path": path,
				}
			)
		)


func _kind_label(kind: String) -> String:
	return (
		{
			"actors": "角色",
			"backgrounds": "背景",
			"bgms": "背景音乐",
			"sfx": "音效",
			"voices": "语音",
			"states": "角色状态",
			"motions": "演员动作",
			"cameras": "镜头配置",
		}
		. get(kind, kind)
	)


func _has_same_owner_duplicate(definitions: Array[Dictionary]) -> bool:
	var owners := {}
	for definition: Dictionary in definitions:
		var owner := String(definition.get("owner_path", ""))
		if owners.has(owner):
			return true
		owners[owner] = true
	return false


func _parse_message(message: String, severity: String, locale: String) -> Dictionary:
	var result := {
		"severity": severity,
		"line": 1,
		"column": 1,
		"message": message,
	}
	var match_result := _location_regex.search(message)
	if match_result == null:
		return result
	result["line"] = maxi(1, int(match_result.get_string(1)))
	if not match_result.get_string(2).is_empty():
		result["column"] = maxi(1, int(match_result.get_string(2)))
	result["message"] = KS_DiagnosticMessages.localize(match_result.get_string(3), locale)
	return result


func _sort_diagnostics(left: Dictionary, right: Dictionary) -> bool:
	if left["line"] == right["line"]:
		return left["column"] < right["column"]
	return left["line"] < right["line"]
