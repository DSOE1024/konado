extends RefCounted
class_name KS_Analyzer

## KS 语义分析器。
## 演员生命周期使用控制流状态分析：must 表示所有可达路径都存在，
## may 表示至少一条可达路径存在，分支之间不会再互相污染状态。

var console_output_enabled := true
var _errors: Array[String] = []
var _warnings: Array[String] = []
var _diagnostics: Array[Dictionary] = []
var _branch_ids: Array[String] = []
var _branch_nodes: Dictionary = {}
var _dep_characters: Array[String] = []
var _visited_states: Dictionary = {}
var _visited_branches: Dictionary = {}
var _path := ""


func get_errors() -> Array[String]:
	return _errors


func get_warnings() -> Array[String]:
	return _warnings


func get_diagnostics() -> Array[Dictionary]:
	return _diagnostics


func get_dep_characters() -> Array[String]:
	return _dep_characters


func analyze(script: KS_AST.ScriptNode, path: String = "") -> bool:
	_errors.clear()
	_warnings.clear()
	_diagnostics.clear()
	_branch_ids.clear()
	_branch_nodes.clear()
	_dep_characters.clear()
	_visited_states.clear()
	_visited_branches.clear()
	_path = path

	_collect_metadata(script.statements, false)
	_walk(script.statements, _empty_state(), "主线")

	# 不可达分支仍要做局部语义检查，避免死代码藏住资源或演员错误。
	for branch_id in _branch_ids:
		if not _visited_branches.has(branch_id):
			_walk_branch(branch_id, _empty_state())
	return _errors.is_empty()


func _collect_metadata(statements: Array, inside_branch: bool) -> void:
	for statement in statements:
		if statement is KS_AST.ActorNode and statement.action == "show":
			if not _dep_characters.has(statement.actor_name):
				_dep_characters.append(statement.actor_name)
		elif statement is KS_AST.BranchNode:
			if inside_branch:
				_error(statement.line, "branch 内不能嵌套 branch")
				continue
			if _branch_nodes.has(statement.branch_id):
				_error(statement.line, "branch 标签 '%s' 重复" % statement.branch_id)
				continue
			_branch_ids.append(statement.branch_id)
			_branch_nodes[statement.branch_id] = statement
			_collect_metadata(statement.body, true)
		elif statement is KS_AST.IfElseNode:
			_collect_metadata(statement.if_body, inside_branch)
			_collect_metadata(statement.else_body, inside_branch)


func _empty_state() -> Dictionary:
	return {"must": [], "may": []}


func _copy_state(state: Dictionary) -> Dictionary:
	return {"must": state["must"].duplicate(), "may": state["may"].duplicate()}


func _state_key(branch_id: String, state: Dictionary) -> String:
	var must: Array = state["must"].duplicate()
	var may: Array = state["may"].duplicate()
	must.sort()
	may.sort()
	return "%s|%s|%s" % [branch_id, ",".join(must), ",".join(may)]


## 返回当前语句列表是否仍可顺序执行；state 会就地更新。
func _walk(statements: Array, state: Dictionary, context: String) -> bool:
	for statement in statements:
		if statement is KS_AST.BranchNode:
			continue
		if statement is KS_AST.ActorNode:
			_apply_actor(statement, state)
		elif statement is KS_AST.BackgroundNode:
			_validate_background(statement)
		elif statement is KS_AST.ChoiceGroupNode:
			if statement.options.is_empty():
				_error(statement.line, "选项行没有有效的选项")
			for option in statement.options:
				if not _branch_nodes.has(option.branch_target):
					_error(
						statement.line,
						"跳转标签 '%s' 不存在（当前可选标签：%s）" % [option.branch_target, str(_branch_ids)]
					)
				else:
					_walk_branch(option.branch_target, _copy_state(state))
			return false
		elif statement is KS_AST.JumpBranchNode:
			if not _branch_nodes.has(statement.target_branch):
				_warning(statement.line, "jump_branch 目标分支 '%s' 未找到" % statement.target_branch)
			else:
				_walk_branch(statement.target_branch, _copy_state(state))
			return false
		elif statement is KS_AST.IfElseNode:
			if not _walk_if_else(statement, state, context):
				return false
		elif statement is KS_AST.SignalNode and statement.signal_content.is_empty():
			_error(statement.line, "信号指令内容为空")
		elif statement is KS_AST.AchievementNode and statement.target_id.is_empty():
			_error(statement.line, "achievement 目标ID为空")
		elif statement is KS_AST.JumpNode:
			_validate_script_jump(statement)
			return false
		elif statement is KS_AST.EndNode:
			return false
	return true


func _validate_background(node: KS_AST.BackgroundNode) -> void:
	if not node.effect.is_empty() and not KS_Emitter.BACKGROUND_EFFECTS_MAP.has(node.effect):
		_warning(node.line, "目标效果 '%s' 未找到" % node.effect)


func _validate_script_jump(node: KS_AST.JumpNode) -> void:
	if not FileAccess.file_exists(node.target_path):
		_warning(node.line, "jump 目标剧本 '%s' 不存在" % node.target_path)


func _walk_branch(branch_id: String, state: Dictionary) -> void:
	var state_key := _state_key(branch_id, state)
	if _visited_states.has(state_key):
		return
	_visited_states[state_key] = true
	_visited_branches[branch_id] = true
	var branch: KS_AST.BranchNode = _branch_nodes[branch_id]
	_walk(branch.body, state, "分支 '%s'" % branch_id)


func _walk_if_else(node: KS_AST.IfElseNode, state: Dictionary, context: String) -> bool:
	var if_state := _copy_state(state)
	var else_state := _copy_state(state)
	var if_continues := _walk(node.if_body, if_state, "%s/if块" % context)
	var else_continues := true
	if not node.else_body.is_empty():
		else_continues = _walk(node.else_body, else_state, "%s/else块" % context)

	if not if_continues and not else_continues:
		return false
	if if_continues and not else_continues:
		state["must"] = if_state["must"]
		state["may"] = if_state["may"]
	elif else_continues and not if_continues:
		state["must"] = else_state["must"]
		state["may"] = else_state["may"]
	else:
		state["must"] = _intersection(if_state["must"], else_state["must"])
		state["may"] = _union(if_state["may"], else_state["may"])
	return true


func _apply_actor(node: KS_AST.ActorNode, state: Dictionary) -> void:
	var must: Array = state["must"]
	var may: Array = state["may"]
	match node.action:
		"show":
			if not must.has(node.actor_name):
				must.append(node.actor_name)
			if not may.has(node.actor_name):
				may.append(node.actor_name)
		"exit":
			_validate_actor_exists(node, must, may, "移除")
			must.erase(node.actor_name)
			may.erase(node.actor_name)
		"change":
			_validate_actor_exists(node, must, may, "改变")
		"move":
			_validate_actor_exists(node, must, may, "移动")
		"motion":
			_validate_actor_exists(node, must, may, "播放舞台动作")


func _validate_actor_exists(
	node: KS_AST.ActorNode, must: Array, may: Array, action: String
) -> void:
	if must.has(node.actor_name):
		return
	if may.has(node.actor_name):
		_warning(node.line, "角色 '%s' 在部分路径上不存在，无法安全%s" % [node.actor_name, action])
	else:
		_warning(node.line, "角色 '%s' 不存在，无法%s" % [node.actor_name, action])


func _intersection(left: Array, right: Array) -> Array:
	var result: Array = []
	for value in left:
		if right.has(value):
			result.append(value)
	return result


func _union(left: Array, right: Array) -> Array:
	var result := left.duplicate()
	for value in right:
		if not result.has(value):
			result.append(value)
	return result


func _error(line_num: int, message: String) -> void:
	var error := "错误：%s [行：%d] %s" % [_path, line_num, message]
	if _errors.has(error):
		return
	_errors.append(error)
	_append_diagnostic("error", line_num, message)
	if console_output_enabled:
		push_error(error)


func _warning(line_num: int, message: String) -> void:
	var warning := "警告：%s [行：%d] %s" % [_path, line_num, message]
	if _warnings.has(warning):
		return
	_warnings.append(warning)
	_append_diagnostic("warning", line_num, message)
	if console_output_enabled:
		push_warning(warning)


func _append_diagnostic(severity: String, line_num: int, message: String) -> void:
	var description := KS_DiagnosticMessages.describe(message, "zh_CN")
	(
		_diagnostics
		. append(
			{
				"severity": severity,
				"stage": "analyzer",
				"path": _path,
				"line": maxi(1, line_num),
				"column": 1,
				"end_line": maxi(1, line_num),
				"end_column": 2,
				"code": description["code"],
				"arguments": description["arguments"],
				"raw_message": message,
			}
		)
	)
