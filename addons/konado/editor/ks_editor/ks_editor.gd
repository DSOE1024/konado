@tool
extends Node

## 使用统一语言目录构建可插入的 KonadoScript 语句列表。

@onready var code_edit: CodeEdit = %CodeEdit
@onready var statement_tree: Tree = %StatementTree


func _ready() -> void:
	_build_statement_tree()


func _build_statement_tree() -> void:
	statement_tree.clear()
	var root := statement_tree.create_item()
	var chinese := KS_LanguageCatalog.is_chinese_locale()
	var group_items := {}

	for snippet: Dictionary in KS_LanguageCatalog.SNIPPETS:
		var group: String = snippet["group"]
		if not group_items.has(group):
			var group_item := statement_tree.create_item(root)
			group_item.set_text(0, KS_LanguageCatalog.get_group_label(group, chinese))
			group_item.set_selectable(0, false)
			group_items[group] = group_item

		var item := statement_tree.create_item(group_items[group])
		item.set_text(0, KS_LanguageCatalog.get_snippet_label(snippet, chinese))
		item.set_tooltip_text(0, KS_LanguageCatalog.get_snippet_description(snippet, chinese))
		item.set_metadata(0, snippet["snippet"])

	if not statement_tree.item_selected.is_connected(_on_item_selected):
		statement_tree.item_selected.connect(_on_item_selected)


func _on_item_selected() -> void:
	var selected_item := statement_tree.get_selected()
	if selected_item != null and selected_item.get_metadata(0) != null:
		_insert_snippet(str(selected_item.get_metadata(0)))
		statement_tree.deselect_all()


func _insert_snippet(snippet: String) -> void:
	if not code_edit.editable or snippet.is_empty():
		return

	if code_edit.has_selection():
		code_edit.delete_selection()
	var line := code_edit.get_caret_line()
	var needs_newline := not code_edit.get_line(line).strip_edges().is_empty()
	code_edit.insert_text_at_caret(("\n" if needs_newline else "") + snippet)
	code_edit.grab_focus()
