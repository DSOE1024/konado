@tool
extends RefCounted
class_name KS_DocumentModel

## Immutable-by-revision semantic snapshot for one KonadoScript document.
##
## A revision owns the compiler analysis, AST, token stream, semantic references,
## outline and diagnostics used by every editor feature. Updating with identical
## content is a no-op so completion, navigation and validation never parse the
## same revision independently.

const LOCALE_CATALOG_SCRIPT := preload("res://addons/konado/i18n/knd_locale_catalog.gd")
const LOCALIZED_SCRIPT_LOADER_SCRIPT := preload(
	"res://addons/konado/i18n/knd_localized_script_loader.gd"
)

var path := ""
var source := ""
var source_hash := 0
var revision := 0
var valid := false
var tokens: Array[KS_Token] = []
var ast: KS_AST.ScriptNode
var references: Array[Dictionary] = []
var branch_definitions := {}
var dependencies := PackedStringArray()

var _analysis := {}
var _diagnostics_by_locale := {}


func update(new_source: String, new_path: String = "") -> bool:
	var next_hash := new_source.hash()
	if new_source == source and (new_path.is_empty() or new_path == path):
		return false
	if not new_path.is_empty():
		path = new_path
	source = new_source
	source_hash = next_hash
	revision += 1

	var compiler := KS_Compiler.new()
	compiler.set_console_output_enabled(false)
	_analysis = compiler.analyze_string(source, path)
	valid = bool(_analysis.get("valid", false))
	tokens.assign(_analysis.get("tokens", []))
	ast = _analysis.get("ast")
	references = KS_SymbolIndex.get_semantic_references(source)
	branch_definitions = KS_SymbolIndex.get_branch_definitions(source)
	dependencies = _collect_dependencies()
	_diagnostics_by_locale.clear()
	return true


func get_analysis() -> Dictionary:
	return _analysis.duplicate(false)


func get_diagnostics(locale: String = "") -> Array[Dictionary]:
	var normalized_locale := (
		locale if not locale.is_empty() else KS_EditorLocale.get_editor_locale()
	)
	if not _diagnostics_by_locale.has(normalized_locale):
		var diagnostics := KS_Diagnostics.new().analyze_result(
			source, path, normalized_locale, _analysis
		)
		if valid:
			diagnostics.append_array(KS_ControlFlowAnalyzer.analyze(self, normalized_locale))
			diagnostics.append_array(_get_localization_diagnostics(normalized_locale))
		diagnostics.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				if left.get("line", 1) == right.get("line", 1):
					return int(left.get("column", 1)) < int(right.get("column", 1))
				return int(left.get("line", 1)) < int(right.get("line", 1))
		)
		_diagnostics_by_locale[normalized_locale] = diagnostics
	var result: Array[Dictionary] = []
	for diagnostic: Dictionary in _diagnostics_by_locale[normalized_locale]:
		result.append(diagnostic.duplicate(true))
	return result


func _get_localization_diagnostics(locale: String) -> Array[Dictionary]:
	if path.is_empty() or not FileAccess.file_exists(path):
		return []
	var loader := LOCALIZED_SCRIPT_LOADER_SCRIPT.new(LOCALE_CATALOG_SCRIPT.new())
	var default_path: String = loader.get_base_script_path(path)
	if default_path == path or not FileAccess.file_exists(default_path):
		return []
	var default_file := FileAccess.open(default_path, FileAccess.READ)
	if default_file == null:
		return []
	return (
		KS_LocalizationValidator
		. compare(
			default_file.get_as_text(),
			source,
			default_path,
			path,
			locale,
		)["diagnostics"]
	)


func get_outline() -> PackedStringArray:
	var outline := PackedStringArray()
	for branch_name: String in branch_definitions:
		outline.append("%s:%d" % [branch_name, branch_definitions[branch_name]])
	return outline


func get_references(kind: String = "", name: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reference: Dictionary in references:
		if not kind.is_empty() and reference.get("kind") != kind:
			continue
		if not name.is_empty() and reference.get("name") != name:
			continue
		result.append(reference.duplicate(true))
	return result


func get_reference_at(line: int, column: int) -> Dictionary:
	if line < 0:
		return {}
	var lines := source.split("\n")
	if line >= lines.size():
		return {}
	return (
		KS_SymbolIndex
		. get_semantic_reference_at(
			String(lines[line]),
			column,
			KS_SymbolIndex.is_screentext_content_line(source, line),
		)
	)


func _collect_dependencies() -> PackedStringArray:
	var result := PackedStringArray()
	for reference: Dictionary in references:
		if reference.get("kind") != "scripts":
			continue
		var target := String(reference.get("name", ""))
		if not target.is_empty() and not result.has(target):
			result.append(target)
	result.sort()
	return result
