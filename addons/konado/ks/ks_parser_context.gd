extends RefCounted

## Shared token cursor and diagnostic context for the KS parser.
##
## Keeping stream traversal here lets KS_Parser focus on grammar rules while
## preserving a single source of truth for position tracking and error output.

var console_output_enabled := true
var _tokens: Array[KS_Token] = []
var _pos: int = 0
var _path: String = ""
var _errors: Array[String] = []


## 查看当前 Token（不消费）
func _peek() -> KS_Token:
	if _pos < _tokens.size():
		return _tokens[_pos]
	return KS_Token.new(KS_Token.Type.EOF, "", 0, 0)


## 消费并返回当前 Token
func _advance() -> KS_Token:
	var tok := _peek()
	if _pos < _tokens.size():
		_pos += 1
	return tok


## 检查当前 Token 类型
func _check(type: KS_Token.Type) -> bool:
	return _peek().type == type


## 期望指定类型的 Token，否则报错
func _expect(type: KS_Token.Type) -> KS_Token:
	if _check(type):
		return _advance()
	_error("期望 %s，实际为 %s" % [KS_Token.Type.keys()[type], str(_peek())])
	return null


## 期望任意值 Token（STRING_LITERAL / NUMBER_LITERAL / IDENTIFIER / VARIABLE_REF / 关键字）
func _expect_any_value() -> KS_Token:
	var tok := _peek()
	if tok.type == KS_Token.Type.NEWLINE or tok.type == KS_Token.Type.EOF:
		return null
	return _advance()


## 是否在行末（NEWLINE 或 EOF）
func _at_line_end() -> bool:
	var tok := _peek()
	return tok.type == KS_Token.Type.NEWLINE or tok.type == KS_Token.Type.EOF


## 跳过所有 NEWLINE
func _skip_newlines() -> void:
	while _pos < _tokens.size() and _tokens[_pos].type == KS_Token.Type.NEWLINE:
		_pos += 1


## 跳到下一行（消费到 NEWLINE 或 EOF）
func _skip_to_next_line() -> void:
	while _pos < _tokens.size():
		if _tokens[_pos].type == KS_Token.Type.NEWLINE:
			_pos += 1
			return
		if _tokens[_pos].type == KS_Token.Type.EOF:
			return
		_pos += 1


## 是否到达 Token 流末尾
func _at_end() -> bool:
	return _pos >= _tokens.size() or _peek().type == KS_Token.Type.EOF


## 检查当前行（可能跨 INDENT）是否以指定关键字开头
func _check_keyword_on_line(kw: KS_Token.Type) -> bool:
	var look := _pos
	if look < _tokens.size() and _tokens[look].type == KS_Token.Type.INDENT:
		look += 1
	return look < _tokens.size() and _tokens[look].type == kw


## 跳过到指定关键字之后（含行末 NEWLINE）
func _skip_past_keyword(kw: KS_Token.Type) -> void:
	if _check(KS_Token.Type.INDENT):
		_advance()
	if _check(kw):
		_advance()
	if _check(KS_Token.Type.COLON):
		_advance()
	_skip_to_next_line()


## 错误记录
func _error(msg: String) -> void:
	var line_num := _peek().line if _peek() else 0
	_error_at(line_num, msg)


## 在指定源码行记录错误，用于文件结尾处发现的未闭合结构。
func _error_at(line_num: int, msg: String) -> void:
	var err := "语法错误：%s [行：%d] %s" % [_path, line_num, msg]
	_errors.append(err)
	if console_output_enabled:
		push_error(err)
