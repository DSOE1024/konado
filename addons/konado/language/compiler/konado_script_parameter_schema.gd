extends RefCounted
class_name KonadoScriptParameterSchema

## Validates named parameters exclusively from KonadoScriptCommandRegistry.


static func validate(node: KonadoScriptSyntaxTree.ASTNode) -> Array[String]:
	var errors: Array[String] = []
	var command := KonadoScriptCommandRegistry.command_for_node(node)
	if command.is_empty() and node is KonadoScriptSyntaxTree.BranchNode:
		return errors
	if command.is_empty() or not KonadoScriptCommandRegistry.COMMANDS.has(command):
		errors.append("指令没有注册的语义契约")
		return errors
	var allowed := KonadoScriptCommandRegistry.parameters_for_node(node)
	for name: String in node.parameters:
		if not allowed.has(name):
			errors.append("参数 '%s' 不适用于当前指令" % name)
			continue
		_validate_value(name, node.parameters[name], allowed[name], errors)
	if node.parameters.has("speed") and node.parameters.has("interval"):
		errors.append("speed 与 interval 不能同时设置")
	if node is KonadoScriptSyntaxTree.CameraNode or node is KonadoScriptSyntaxTree.AsyncCamNode:
		if node.parameters.has("duration"):
			var positional: float = (
				node.tween_time if node.action in ["move", "reset"] else node.shake_time
			)
			if positional > 0.0:
				errors.append("镜头时长不能同时使用位置参数和 [duration=...] 设置")
	return errors


static func _validate_value(
	name: String, value: Variant, definition: Dictionary, errors: Array[String]
) -> void:
	match String(definition.get("type", "")):
		"number":
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
				errors.append("参数 '%s' 必须是数字" % name)
				return
			var number := float(value)
			if definition.has("min") and number < float(definition["min"]):
				errors.append("参数 '%s' 不能小于 %s" % [name, definition["min"]])
			if definition.has("min_exclusive") and number <= float(definition["min_exclusive"]):
				errors.append("参数 '%s' 必须大于 %s" % [name, definition["min_exclusive"]])
		"identifier":
			if typeof(value) != TYPE_STRING or not _is_konado_identifier(String(value)):
				errors.append("参数 '%s' 必须是有效标识符" % name)
		"boolean":
			if typeof(value) != TYPE_BOOL:
				errors.append("参数 '%s' 必须是 true 或 false" % name)
		"enum":
			if typeof(value) != TYPE_STRING or value not in definition.get("values", []):
				errors.append(
					(
						"参数 '%s' 必须是以下值之一：%s"
						% [name, ", ".join(PackedStringArray(definition.get("values", [])))]
					)
				)


static func _is_konado_identifier(value: String) -> bool:
	if value.is_empty() or not _is_identifier_start(value[0]):
		return false
	for index in range(1, value.length()):
		if not _is_identifier_character(value[index]):
			return false
	return true


static func _is_identifier_start(character: String) -> bool:
	var code := character.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 95 or code >= 0x80


static func _is_identifier_character(character: String) -> bool:
	var code := character.unicode_at(0)
	return _is_identifier_start(character) or (code >= 48 and code <= 57) or code == 45
