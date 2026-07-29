@tool
extends RefCounted
class_name KS_ScriptEditorIntegration

## Adapts the native Godot Script Editor chrome while a KonadoScript is active.
##
## Godot does not currently expose public insertion slots for the document list
## or the online-documentation button. This adapter therefore locates the
## Godot 4.7 Script Editor's split-container structure, validates every target
## before touching it, and restores the original controls on cleanup.

const DOCS_ORIGIN := "https://godothub.com/oss/konado"
const JUMP_LINK_OVERLAY_SCRIPT := preload(
	"res://addons/konado/editor/ks_editor/ks_jump_link_overlay.gd"
)

var _script_editor: ScriptEditor
var _list_split: VSplitContainer
var _document_list: Control
var _palette: VBoxContainer
var _palette_title: Label
var _palette_toggle: CheckButton
var _instruction_tree: Tree
var _site_search: Button
var _help_search: Button
var _docs_button: Button
var _jump_link_overlay: Control
var _plugin_version := ""
var _is_konado_active := false
var _document_list_was_visible := true
var _site_search_was_visible := true
var _help_search_was_visible := true
var _initial_split_applied := false
var _initial_split_pending := false


func setup(script_editor: ScriptEditor, plugin_version: String) -> bool:
	_script_editor = script_editor
	_plugin_version = plugin_version
	if not _find_script_editor_controls():
		push_warning(
			(
				"KonadoScript editor chrome could not be installed because the Godot Script Editor "
				+ "layout was not recognized."
			)
		)
		return false
	_create_instruction_palette()
	_create_docs_button()
	if not _script_editor.editor_script_changed.is_connected(_on_editor_script_changed):
		_script_editor.editor_script_changed.connect(_on_editor_script_changed)
	_on_editor_script_changed(_script_editor.get_current_script())
	return true


func cleanup() -> void:
	if (
		_script_editor != null
		and _script_editor.editor_script_changed.is_connected(_on_editor_script_changed)
	):
		_script_editor.editor_script_changed.disconnect(_on_editor_script_changed)
	_restore_native_controls()
	_detach_jump_link_overlay()
	if is_instance_valid(_palette):
		_palette.free()
	if is_instance_valid(_docs_button):
		_docs_button.free()
	_palette = null
	_palette_title = null
	_palette_toggle = null
	_instruction_tree = null
	_docs_button = null
	_site_search = null
	_help_search = null
	_document_list = null
	_list_split = null
	_script_editor = null


func get_instruction_tree() -> Tree:
	return _instruction_tree


func get_document_list() -> Control:
	return _document_list


func get_docs_button() -> Button:
	return _docs_button


func is_konado_active() -> bool:
	return _is_konado_active


static func get_docs_version(plugin_version: String) -> String:
	var parts := plugin_version.split(".")
	if parts.size() < 2:
		return plugin_version
	return "%s.%s" % [parts[0], parts[1]]


static func get_docs_locale(locale: String) -> String:
	var normalized := locale.to_lower().replace("_", "-")
	if normalized.begins_with("zh"):
		for traditional_marker: String in ["zh-tw", "zh-hk", "zh-mo", "zh-hant"]:
			if normalized.begins_with(traditional_marker):
				return "tc"
		return "zh"
	if normalized.begins_with("ja"):
		return "ja"
	if normalized.begins_with("ko"):
		return "ko"
	return "en"


static func get_docs_url(plugin_version: String, locale: String) -> String:
	return (
		"%s/%s/%s/"
		% [
			DOCS_ORIGIN,
			get_docs_locale(locale),
			get_docs_version(plugin_version),
		]
	)


func _find_script_editor_controls() -> bool:
	var main_container: VBoxContainer
	for child: Node in _script_editor.get_children():
		if child is VBoxContainer:
			main_container = child
			break
	if main_container == null:
		return false

	var menu_bar: HBoxContainer
	var script_split: HSplitContainer
	for child: Node in main_container.get_children():
		if menu_bar == null and child is HBoxContainer:
			menu_bar = child
		elif script_split == null and child is HSplitContainer:
			script_split = child
	if menu_bar == null or script_split == null:
		return false

	for child: Node in script_split.get_children():
		if child is VSplitContainer:
			_list_split = child
			break
	if _list_split == null or _list_split.get_child_count() < 2:
		return false
	_document_list = _list_split.get_child(0) as Control
	if _document_list == null or not _is_native_document_list(_document_list):
		_document_list = null
		return false

	var passed_script_name_area := false
	for child: Node in menu_bar.get_children():
		if child is HBoxContainer:
			passed_script_name_area = true
			continue
		if passed_script_name_area and child is Button and not child is MenuButton:
			if _site_search == null:
				_site_search = child
			else:
				_help_search = child
				break
	return _site_search != null


func _is_native_document_list(control: Control) -> bool:
	var has_filter := false
	var has_list := false
	for child: Node in control.get_children():
		has_filter = has_filter or child is LineEdit
		has_list = has_list or child is ItemList
	return has_filter and has_list


func _create_instruction_palette() -> void:
	_palette = VBoxContainer.new()
	_palette.name = "KonadoInstructionPalette"
	_palette.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	_palette.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	_palette.size_flags_stretch_ratio = 2.0
	_palette.visible = false

	var header := HBoxContainer.new()
	header.name = "InstructionPaletteHeader"
	header.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	_palette.add_child(header)

	_palette_title = Label.new()
	_palette_title.name = "InstructionPaletteTitle"
	_palette_title.text = KS_EditorLocale.text("Components", "组件")
	_palette_title.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	header.add_child(_palette_title)

	_palette_toggle = CheckButton.new()
	_palette_toggle.name = "InstructionPaletteToggle"
	_palette_toggle.button_pressed = true
	_palette_toggle.accessibility_name = (
		KS_EditorLocale
		. text(
			"Expand or collapse all component and command groups",
			"展开或折叠全部组件和指令分组",
		)
	)
	_palette_toggle.tooltip_text = _palette_toggle.accessibility_name
	_palette_toggle.toggled.connect(_on_palette_expansion_toggled)
	header.add_child(_palette_toggle)

	_instruction_tree = Tree.new()
	_instruction_tree.name = "InstructionTree"
	_instruction_tree.hide_root = true
	_instruction_tree.allow_reselect = true
	_instruction_tree.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	_instruction_tree.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	_instruction_tree.custom_minimum_size = Vector2(100, 60)
	_palette.add_child(_instruction_tree)
	_build_instruction_tree()
	_instruction_tree.item_selected.connect(_on_instruction_selected)

	_list_split.add_child(_palette)
	_list_split.move_child(_palette, 0)


func _on_palette_expansion_toggled(expanded: bool) -> void:
	if not is_instance_valid(_instruction_tree):
		return
	var root := _instruction_tree.get_root()
	if root == null:
		return
	var group := root.get_first_child()
	while group != null:
		group.set_collapsed(not expanded)
		group = group.get_next()


func _build_instruction_tree() -> void:
	_instruction_tree.clear()
	var root := _instruction_tree.create_item()
	var chinese := KS_EditorLocale.is_chinese()
	var group_items := {}
	for snippet: Dictionary in KS_LanguageCatalog.SNIPPETS:
		var group: String = snippet["group"]
		if not group_items.has(group):
			var group_item := _instruction_tree.create_item(root)
			group_item.set_text(0, KS_LanguageCatalog.get_group_label(group, chinese))
			group_item.set_selectable(0, false)
			group_item.set_collapsed(
				is_instance_valid(_palette_toggle) and not _palette_toggle.button_pressed
			)
			group_items[group] = group_item
		var item := _instruction_tree.create_item(group_items[group])
		item.set_text(0, KS_LanguageCatalog.get_snippet_label(snippet, chinese))
		item.set_tooltip_text(0, KS_LanguageCatalog.get_snippet_description(snippet, chinese))
		item.set_metadata(0, snippet["snippet"])


func _create_docs_button() -> void:
	_docs_button = Button.new()
	_docs_button.name = "KonadoOnlineDocs"
	_docs_button.theme_type_variation = "FlatButton"
	_docs_button.visible = false
	_docs_button.accessibility_name = "KonadoScript Documentation"
	_docs_button.pressed.connect(_open_versioned_docs)
	var menu_bar := _site_search.get_parent()
	menu_bar.add_child(_docs_button)
	menu_bar.move_child(_docs_button, _site_search.get_index() + 1)
	_sync_docs_button_appearance()


func _sync_docs_button_appearance() -> void:
	if not is_instance_valid(_site_search) or not is_instance_valid(_docs_button):
		return
	_docs_button.text = _site_search.text
	_docs_button.icon = _site_search.icon
	var docs_version := get_docs_version(_plugin_version)
	_docs_button.tooltip_text = (
		KS_EditorLocale
		. text(
			"Open Konado %s online documentation." % docs_version,
			"打开 Konado %s 在线文档。" % docs_version,
		)
	)


func _on_editor_script_changed(script: Script) -> void:
	_set_konado_active(script is KND_Shot)


func _set_konado_active(active: bool) -> void:
	if not is_instance_valid(_document_list) or not is_instance_valid(_palette):
		return
	if active == _is_konado_active:
		if active:
			_attach_jump_link_overlay()
		return
	if active:
		_document_list_was_visible = _document_list.visible
		_site_search_was_visible = _site_search.visible if is_instance_valid(_site_search) else true
		_help_search_was_visible = _help_search.visible if is_instance_valid(_help_search) else true
		_document_list.visible = false
		_palette.visible = true
		_sync_docs_button_appearance()
		if is_instance_valid(_site_search):
			_site_search.visible = false
		if is_instance_valid(_help_search):
			_help_search.visible = false
		if is_instance_valid(_docs_button):
			_docs_button.visible = true
		_schedule_initial_split()
		_attach_jump_link_overlay()
	else:
		_detach_jump_link_overlay()
		_restore_native_controls()
	_is_konado_active = active


func _restore_native_controls() -> void:
	if is_instance_valid(_palette):
		_palette.visible = false
	if is_instance_valid(_docs_button):
		_docs_button.visible = false
	if not _is_konado_active:
		return
	if is_instance_valid(_document_list):
		_document_list.visible = _document_list_was_visible
	if is_instance_valid(_site_search):
		_site_search.visible = _site_search_was_visible
	if is_instance_valid(_help_search):
		_help_search.visible = _help_search_was_visible


func _schedule_initial_split() -> void:
	if _initial_split_applied or _initial_split_pending:
		return
	_initial_split_pending = true
	_apply_initial_split.call_deferred()


func _apply_initial_split() -> void:
	if _script_editor == null or _script_editor.get_tree() == null:
		_initial_split_pending = false
		return
	await _script_editor.get_tree().create_timer(0.1).timeout
	_initial_split_pending = false
	if (
		_initial_split_applied
		or not _is_konado_active
		or not is_instance_valid(_list_split)
		or not is_instance_valid(_palette)
	):
		return
	var lower_region: Control
	for child: Node in _list_split.get_children():
		if child != _palette and child is Control and child.visible:
			lower_region = child
			break
	if lower_region == null:
		return
	var available_height := _palette.size.y + lower_region.size.y
	if available_height <= 0.0:
		return
	var lower_minimum_height := ceili(lower_region.get_combined_minimum_size().y)
	var target_height := mini(
		roundi(available_height * 2.0 / 3.0),
		maxi(0, roundi(available_height) - lower_minimum_height),
	)
	var adjustment := target_height - roundi(_palette.size.y)
	_list_split.split_offset += adjustment
	_initial_split_applied = true


func _attach_jump_link_overlay() -> void:
	if _script_editor == null:
		return
	var current_editor := _script_editor.get_current_editor()
	var code_edit := (
		current_editor.get_base_editor() as CodeEdit if current_editor != null else null
	)
	if code_edit == null:
		_detach_jump_link_overlay()
		return
	if is_instance_valid(_jump_link_overlay) and _jump_link_overlay.get_parent() == code_edit:
		return
	_detach_jump_link_overlay()
	_jump_link_overlay = JUMP_LINK_OVERLAY_SCRIPT.new()
	code_edit.add_child(_jump_link_overlay)
	_jump_link_overlay.setup(code_edit)


func _detach_jump_link_overlay() -> void:
	if not is_instance_valid(_jump_link_overlay):
		_jump_link_overlay = null
		return
	_jump_link_overlay.cleanup()
	# Opening another script emits editor_script_changed synchronously from the
	# overlay's navigation callback. The overlay is still locked on that call
	# stack, so defer destruction until the frame ends.
	var parent := _jump_link_overlay.get_parent()
	if parent != null:
		parent.remove_child(_jump_link_overlay)
	_jump_link_overlay.call_deferred("free")
	_jump_link_overlay = null


func _on_instruction_selected() -> void:
	var item := _instruction_tree.get_selected()
	if item == null:
		return
	var metadata: Variant = item.get_metadata(0)
	if metadata == null:
		return
	_insert_snippet(str(metadata))
	_instruction_tree.deselect_all()


func _insert_snippet(snippet: String) -> void:
	if snippet.is_empty() or _script_editor == null:
		return
	var current_editor := _script_editor.get_current_editor()
	if current_editor == null:
		return
	var code_edit := current_editor.get_base_editor() as CodeEdit
	if code_edit == null or not code_edit.editable:
		return

	code_edit.begin_complex_operation()
	if code_edit.has_selection():
		code_edit.delete_selection()
	var line := code_edit.get_caret_line()
	var current_line := code_edit.get_line(line)
	var indentation := current_line.left(
		current_line.length() - current_line.strip_edges(true, false).length()
	)
	var indented_snippet := snippet.replace("\n", "\n" + indentation)
	if not current_line.strip_edges().is_empty():
		indented_snippet = "\n" + indentation + indented_snippet
	code_edit.insert_text_at_caret(indented_snippet)
	code_edit.end_complex_operation()
	code_edit.grab_focus()


func _open_versioned_docs() -> void:
	var url := get_docs_url(_plugin_version, KS_EditorLocale.get_editor_locale())
	var open_error := OS.shell_open(url)
	if open_error != OK:
		push_error("Unable to open Konado documentation: %s" % url)
