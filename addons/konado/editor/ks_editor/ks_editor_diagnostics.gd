extends RefCounted
class_name KS_EditorDiagnostics

var _location_regex := RegEx.new()


func _init() -> void:
	_location_regex.compile("\\[行：(\\d+)(?:, 列：(\\d+))?\\]\\s*(.*)$")


func analyze(source: String, path: String) -> Array[Dictionary]:
	var compiler := KS_Compiler.new()
	compiler.set_console_output_enabled(false)
	compiler.validate_string(source, path)

	var diagnostics: Array[Dictionary] = []
	for error: String in compiler.get_errors():
		diagnostics.append(_parse_message(error, "error"))
	for warning: String in compiler.get_warnings():
		diagnostics.append(_parse_message(warning, "warning"))
	diagnostics.sort_custom(_sort_diagnostics)
	return diagnostics


func _parse_message(message: String, severity: String) -> Dictionary:
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
	result["message"] = match_result.get_string(3)
	return result


func _sort_diagnostics(left: Dictionary, right: Dictionary) -> bool:
	if left["line"] == right["line"]:
		return left["column"] < right["column"]
	return left["line"] < right["line"]
