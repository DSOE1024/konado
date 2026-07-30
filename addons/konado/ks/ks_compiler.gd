extends RefCounted
class_name KS_Compiler

## KS 编译器管线
## 串联 Lexer → Parser → Analyzer → Emitter 四个阶段

var _lexer: KS_Lexer
var _parser: KS_Parser
var _analyzer: KS_Analyzer
var _emitter: KS_Emitter

var _errors: Array[String] = []
var _warnings: Array[String] = []
var _diagnostics: Array[Dictionary] = []


func _init() -> void:
	_lexer = KS_Lexer.new()
	_parser = KS_Parser.new()
	_analyzer = KS_Analyzer.new()
	_emitter = KS_Emitter.new()


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
func compile_file(path: String) -> KND_Shot:
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
func compile_string(source: String, path: String = "") -> KND_Shot:
	_report_info(path, 0, "开始编译脚本文件")
	var analysis := analyze_string(source, path)
	if not bool(analysis.get("valid", false)):
		return null
	var ast: KS_AST.ScriptNode = analysis.get("ast")
	if ast == null:
		return null

	var shot: KND_Shot = _emitter.emit(ast, path)
	_report_info(path, 0, "编译完成 —— 文件：%s 对话数量：%d" % [path, shot.dialogues.size()])
	return shot


## 只执行词法、语法和语义分析，不生成运行时资源。
func validate_string(source: String, path: String = "") -> bool:
	return analyze_string(source, path).get("valid", false)


## 执行一次完整分析并返回可供编辑器复用的词法与语义结果。
##
## 编译、实时诊断、补全和导航应共享此结果，避免分别运行多套解析逻辑。
func analyze_string(source: String, path: String = "") -> Dictionary:
	_errors.clear()
	_warnings.clear()
	_diagnostics.clear()
	var tokens := _lexer.tokenize(source, path)
	_diagnostics.append_array(_lexer.get_diagnostics())
	if not _lexer.get_errors().is_empty():
		_errors.append_array(_lexer.get_errors())
		return _make_analysis_result(source, path, tokens, null)

	var ast := _parser.parse(tokens, path)
	_diagnostics.append_array(_parser.get_diagnostics())
	if ast == null:
		_errors.append_array(_parser.get_errors())
		return _make_analysis_result(source, path, tokens, null)

	var analysis_valid := _analyzer.analyze(ast, path)
	_diagnostics.append_array(_analyzer.get_diagnostics())
	if not analysis_valid:
		_errors.append_array(_analyzer.get_errors())
		_warnings.append_array(_analyzer.get_warnings())
		return _make_analysis_result(source, path, tokens, ast)
	_warnings.append_array(_analyzer.get_warnings())
	return _make_analysis_result(source, path, tokens, ast)


func _make_analysis_result(
	source: String,
	path: String,
	tokens: Array[KS_Token],
	ast: KS_AST.ScriptNode,
) -> Dictionary:
	return {
		"valid": _errors.is_empty() and ast != null,
		"path": path,
		"source": source,
		"source_hash": source.hash(),
		"tokens": tokens,
		"ast": ast,
		"errors": _errors.duplicate(),
		"warnings": _warnings.duplicate(),
		"diagnostics": _diagnostics.duplicate(true),
	}


## 编译单行 → KND_Dialogue（跳过语义分析阶段）
func compile_line(line: String, line_number: int, path: String = "") -> KND_Dialogue:
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

	# 直接发射（跳过语义分析，单行模式无上下文）
	return _emitter.emit_single(node)


func _report_error(path: String, line: int, msg: String) -> void:
	var err := "错误：%s [行：%d] %s" % [path, line, msg]
	_errors.append(err)
	var description := KS_DiagnosticMessages.describe(msg, "zh_CN")
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
