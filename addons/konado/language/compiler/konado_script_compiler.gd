extends RefCounted
class_name KonadoScriptCompiler

## KonadoScript 编译器管线
## 串联 Lexer → Parser → Analyzer → Emitter 四个阶段

var _lexer: KonadoScriptLexer
var _parser: KonadoScriptParser
var _analyzer: KonadoScriptSemanticAnalyzer
var _emitter: KonadoScriptProgramEmitter
var _graph_validator: KonadoScriptGraphValidator
var _program_analyzer: KonadoScriptProgramAnalyzer

var _errors: Array[String] = []
var _warnings: Array[String] = []
var _diagnostics: Array[Dictionary] = []


func _init() -> void:
	_lexer = KonadoScriptLexer.new()
	_parser = KonadoScriptParser.new()
	_analyzer = KonadoScriptSemanticAnalyzer.new()
	_emitter = KonadoScriptProgramEmitter.new()
	_graph_validator = KonadoScriptGraphValidator.new()
	_program_analyzer = KonadoScriptProgramAnalyzer.new()


func set_console_output_enabled(enabled: bool) -> void:
	_lexer.console_output_enabled = enabled
	_parser.console_output_enabled = enabled
	_analyzer.console_output_enabled = enabled
	_emitter.console_output_enabled = enabled


## 获取编译错误
func get_errors() -> Array[String]:
	return _errors


## 获取编译警告
func get_warnings() -> Array[String]:
	return _warnings


## 获取结构化编译诊断，供编辑器精确定位和本地化。
func get_diagnostics() -> Array[Dictionary]:
	return _diagnostics


## 编译 ks 文件
func compile_file(path: String) -> KonadoShot:
	_errors.clear()
	_warnings.clear()
	_diagnostics.clear()

	if not FileAccess.file_exists(path):
		_report_error(path, 0, "文件不存在，无法打开脚本文件")
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_report_error(path, 0, "无法打开脚本文件")
		return null

	var source := file.get_as_text()
	file.close()

	return compile_string(source, path)


## 编译源代码字符串
func compile_string(source: String, path: String = "") -> KonadoShot:
	_report_info(path, 0, "开始编译脚本文件")
	var analysis := analyze_string(source, path, false)
	if not bool(analysis.get("valid", false)):
		_analyzer.release_syntax_tree()
		return null
	var ast: KonadoScriptSyntaxTree.ScriptNode = analysis.get("ast")
	if ast == null:
		_analyzer.release_syntax_tree()
		return null

	var shot := KonadoShot.new()
	shot.source_path = path
	shot.dependent_characters = _analyzer.get_dependent_characters()
	shot.dependencies = _analyzer.get_dependencies()
	var program := _emitter.emit(
		ast, path, String(analysis.get("source_sha256", "")), shot.dependencies
	)
	var program_valid := _validate_emitted_program(program, path)
	_emitter.release_compilation_state()
	_analyzer.release_syntax_tree()
	if not program_valid:
		return null
	shot.install_program(program)
	var instruction_count := program.instruction_count()
	_report_info(path, 0, "编译完成 —— 文件：%s 指令数量：%d" % [path, instruction_count])
	return shot


func _validate_emitted_program(program: KonadoProgram, path: String) -> bool:
	var valid := true
	if not _emitter.get_errors().is_empty():
		for error: String in _emitter.get_errors():
			_report_error(path, _extract_line(error), error)
		valid = false
	elif program == null or not program.seal():
		_report_error(path, 1, "编译器生成了结构无效的 Program IR")
		valid = false
	elif not _graph_validator.validate_program(program):
		for error: String in _graph_validator.get_errors():
			_report_error(path, _extract_line(error), error)
		valid = false
	elif not _program_analyzer.analyze(program):
		for error: String in _program_analyzer.get_errors():
			_report_error(path, _extract_line(error), error)
		valid = false
	for warning: String in _program_analyzer.get_warnings():
		if not _warnings.has(warning):
			_warnings.append(warning)
	return valid


## 只执行词法、语法和语义分析，不生成运行时资源。
func validate_string(source: String, path: String = "") -> bool:
	var valid := bool(analyze_string(source, path, false).get("valid", false))
	_analyzer.release_syntax_tree()
	return valid


## 执行一次完整分析并返回可供编辑器复用的词法与语义结果。
##
## 编译、实时诊断、补全和导航应共享此结果，避免分别运行多套解析逻辑。
func analyze_string(source: String, path: String = "", retain_editor_data := true) -> Dictionary:
	_errors.clear()
	_warnings.clear()
	_diagnostics.clear()
	var normalized := (
		KonadoScriptSourceNormalizer.normalize_with_map(source)
		if retain_editor_data
		else {"text": KonadoScriptSourceNormalizer.normalize(source)}
	)
	var normalized_source := String(normalized["text"])
	var tokens := _lexer.tokenize(normalized_source, path)
	_diagnostics.append_array(_lexer.get_diagnostics())
	if not _lexer.get_errors().is_empty():
		_errors.append_array(_lexer.get_errors())
		return _make_analysis_result(
			normalized_source, path, tokens, null, normalized, retain_editor_data
		)

	var ast := _parser.parse(tokens, path)
	_diagnostics.append_array(_parser.get_diagnostics())
	if ast == null:
		_errors.append_array(_parser.get_errors())
		return _make_analysis_result(
			normalized_source, path, tokens, null, normalized, retain_editor_data
		)

	var analysis_valid := _analyzer.analyze(ast, path)
	_diagnostics.append_array(_analyzer.get_diagnostics())
	if not analysis_valid:
		_errors.append_array(_analyzer.get_errors())
		_warnings.append_array(_analyzer.get_warnings())
		return _make_analysis_result(
			normalized_source, path, tokens, ast, normalized, retain_editor_data
		)
	_warnings.append_array(_analyzer.get_warnings())
	return _make_analysis_result(
		normalized_source, path, tokens, ast, normalized, retain_editor_data
	)


func _make_analysis_result(
	source: String,
	path: String,
	tokens: Variant,
	ast: KonadoScriptSyntaxTree.ScriptNode,
	normalization: Dictionary,
	retain_editor_data: bool,
) -> Dictionary:
	var result := {
		"valid": _errors.is_empty() and ast != null,
		"path": path,
		"source": source if retain_editor_data else "",
		"source_sha256": source.sha256_text(),
		"normalized_to_raw":
		(
			normalization.get("normalized_to_raw", PackedInt32Array())
			if retain_editor_data
			else PackedInt32Array()
		),
		"tokens": tokens if retain_editor_data else [],
		"ast": ast,
		"errors": _errors.duplicate(),
		"warnings": _warnings.duplicate(),
		"diagnostics": _diagnostics.duplicate(true),
	}
	if not retain_editor_data:
		_parser.release_token_stream()
	return result


## 编译单行 → 经过同一 Schema 验证的 Program 指令视图。
##
## 单行预览没有完整项目上下文，但仍执行参数 Schema 校验，确保它
## 不会生成完整编译器会拒绝的指令。
func compile_line(line: String, line_number: int, path: String = "") -> KonadoInstruction:
	_errors.clear()
	_warnings.clear()
	_diagnostics.clear()

	var stripped := line.strip_edges()
	if stripped.is_empty():
		return null

	# 词法分析
	var tokens := _lexer.tokenize_line(stripped, line_number)
	_diagnostics.append_array(_lexer.get_diagnostics())
	if tokens.is_empty() and not _lexer.get_errors().is_empty():
		_errors.append_array(_lexer.get_errors())
		return null

	# 语法分析
	var node := _parser.parse_single_statement(tokens, path)
	_diagnostics.append_array(_parser.get_diagnostics())
	if node == null:
		_errors.append_array(_parser.get_errors())
		return null
	var parameter_errors := KonadoScriptParameterSchema.validate(node)
	if not parameter_errors.is_empty():
		for error: String in parameter_errors:
			_report_error(path, line_number, error)
		return null

	var program := _emitter.emit_single(node)
	if not _emitter.get_errors().is_empty() or not _graph_validator.validate_program(program):
		for error: String in _emitter.get_errors():
			_report_error(path, line_number, error)
		for error: String in _graph_validator.get_errors():
			_report_error(path, line_number, error)
		return null
	return program.instruction_at(program.entry_pc)


func _report_error(path: String, line: int, msg: String) -> void:
	var err := "错误：%s [行：%d] %s" % [path, line, msg]
	_errors.append(err)
	var description := KonadoScriptDiagnosticMessages.describe(msg, "zh_CN")
	(
		_diagnostics
		. append(
			{
				"severity": "error",
				"stage": "compiler",
				"path": path,
				"line": maxi(1, line),
				"column": 1,
				"end_line": maxi(1, line),
				"end_column": 2,
				"code": description["code"],
				"arguments": description["arguments"],
				"raw_message": msg,
			}
		)
	)
	if _lexer.console_output_enabled:
		push_error(err)


func _report_info(path: String, line: int, msg: String) -> void:
	if _lexer.console_output_enabled:
		print("信息：%s [行：%d] %s" % [path, line, msg])


func _extract_line(message: String) -> int:
	var pattern := RegEx.create_from_string("(?:行：|第 )(\\d+)")
	var result := pattern.search(message)
	return int(result.get_string(1)) if result != null else 1
