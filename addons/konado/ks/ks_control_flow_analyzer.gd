@tool
extends RefCounted
class_name KS_ControlFlowAnalyzer

## Reports local branch-control-flow problems for one semantic document.


static func analyze(document: KS_DocumentModel, locale: String = "") -> Array[Dictionary]:
	var incoming := {}
	var diagnostics: Array[Dictionary] = []
	var lines := document.source.split("\n")
	for line_index: int in lines.size():
		var tokens := KS_SymbolIndex.get_line_tokens(String(lines[line_index]))
		for target: String in _get_branch_targets(tokens):
			incoming[target] = int(incoming.get(target, 0)) + 1
			if document.branch_definitions.has(target):
				continue
			var reference := _find_branch_reference(document, line_index + 1, target, "reference")
			var column := int(reference.get("column", 1))
			(
				diagnostics
				. append(
					{
						"severity": "error",
						"line": line_index + 1,
						"column": column,
						"end_line": line_index + 1,
						"end_column": int(reference.get("end", column)) + 1,
						"path": document.path,
						"code": "missing_branch",
						"arguments": [target],
						"symbol": target,
						"actions": [],
						"message":
						(
							KS_EditorLocale
							. text(
								"Branch '%s' does not exist." % target,
								"分支“%s”不存在。" % target,
								locale,
							)
						),
					}
				)
			)
	for branch_name: String in document.branch_definitions:
		if incoming.has(branch_name):
			continue
		var definition_line := int(document.branch_definitions[branch_name])
		var reference := _find_branch_reference(
			document, definition_line, branch_name, "definition"
		)
		var column := int(reference.get("column", 1))
		(
			diagnostics
			. append(
				{
					"severity": "warning",
					"line": definition_line,
					"column": column,
					"end_line": definition_line,
					"end_column": int(reference.get("end", column)) + 1,
					"path": document.path,
					"code": "unreachable_branch",
					"arguments": [branch_name],
					"symbol": branch_name,
					"actions": [],
					"message":
					(
						KS_EditorLocale
						. text(
							"Branch '%s' is not referenced." % branch_name,
							"分支“%s”未被引用。" % branch_name,
							locale,
						)
					),
				}
			)
		)
	return diagnostics


static func _find_branch_reference(
	document: KS_DocumentModel,
	line: int,
	name: String,
	role: String,
) -> Dictionary:
	for reference: Dictionary in document.references:
		if (
			reference.get("kind") == "branches"
			and reference.get("name") == name
			and reference.get("role") == role
			and int(reference.get("line", 0)) == line
		):
			return reference
	return {}


static func _get_branch_targets(tokens: Array[Dictionary]) -> PackedStringArray:
	if tokens.is_empty():
		return PackedStringArray()
	var command := String(tokens[0].get("text", ""))
	if command == "jump_branch" and tokens.size() >= 2:
		return PackedStringArray([String(tokens[1].get("text", ""))])
	if command != "choice":
		return PackedStringArray()
	for token_index: int in tokens.size() - 1:
		if String(tokens[token_index].get("text", "")) == "->":
			return PackedStringArray([String(tokens[token_index + 1].get("text", ""))])
	return PackedStringArray()
