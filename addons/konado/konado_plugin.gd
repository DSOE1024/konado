@tool
extends EditorPlugin
class_name KonadoEditorPlugin
# Konado框架入口文件，负责初始化插件和注册相关功能

const CODENAME: String = "Wontons"
const PLUGIN_CONFIG_PATH := "res://addons/konado/plugin.cfg"
const I18N_AUTOLOAD_NAME := "KND_I18n"
const I18N_AUTOLOAD_PATH := "res://addons/konado/i18n/knd_i18n.gd"

## Konado 字典导入器与剧本导出保护插件。
const KDIC_IMPORTER_SCRIPT := preload("uid://b7a8r75oh165c")
const KS_EXPORT_PLUGIN_SCRIPT := preload("res://addons/konado/export/knd_script_export_plugin.gd")
const KS_HIGHLIGHTER_SCRIPT := preload(
	"res://addons/konado/editor/ks_editor/ks_syntax_highlighter.gd"
)
const KS_RESOURCE_LOADER_SCRIPT := preload("res://addons/konado/ks/konado_script_loader.gd")
const KS_SOURCE_SAVER_SCRIPT := preload("res://addons/konado/editor/ks_editor/ks_source_saver.gd")
const KS_CREATE_MENU_SCRIPT := preload("res://addons/konado/editor/ks_editor/ks_create_menu.gd")
const KS_CODE_CONTEXT_MENU_SCRIPT := preload(
	"res://addons/konado/editor/ks_editor/ks_code_context_menu.gd"
)
const KS_SCRIPT_EDITOR_INTEGRATION_SCRIPT := preload(
	"res://addons/konado/editor/ks_editor/ks_script_editor_integration.gd"
)

## 插件实例变量
var kdic_import_plugin: EditorImportPlugin
var ks_export_plugin: EditorExportPlugin
var ks_resource_loader: ResourceFormatLoader
var ks_source_saver: ResourceFormatSaver
var ks_highlighter: EditorSyntaxHighlighter
var ks_create_menu: EditorContextMenuPlugin
var ks_code_context_menu: EditorContextMenuPlugin
var ks_script_editor_integration: KS_ScriptEditorIntegration
var ks_debugger_plugin: EditorDebuggerPlugin

# 文件系统dock
var filesystem_dock: FileSystemDock
var ks_tooltip_plugin: EditorResourceTooltipPlugin

var inspector_plugin: EditorInspectorPlugin = null
var _plugin_version := ""
var _debugger_registered := false


func _has_main_screen() -> bool:
	return false


func _enter_tree() -> void:
	_plugin_version = _read_plugin_version()
	if _plugin_version.is_empty():
		push_error("Konado failed to read its version from %s" % PLUGIN_CONFIG_PATH)
		return
	if not ProjectSettings.has_setting("autoload/" + I18N_AUTOLOAD_NAME):
		add_autoload_singleton(I18N_AUTOLOAD_NAME, I18N_AUTOLOAD_PATH)
	_setup_script_resources()
	_setup_import_plugins()
	_setup_export_plugin()
	_setup_script_editor()
	_print_loading_message()

	filesystem_dock = get_editor_interface().get_file_system_dock()
	ks_tooltip_plugin = preload("res://addons/konado/ks/ks_tooltip_plugin.gd").new()
	filesystem_dock.add_resource_tooltip_plugin(ks_tooltip_plugin)

	inspector_plugin = (
		preload("res://addons/konado/audioeffect/audioeffect_inspector_plugin.gd").new()
	)
	# add_inspector_plugin完成注册
	add_inspector_plugin(inspector_plugin)


# 控制显示
#func _make_visible(visible: bool) -> void:
#ks_dock.visible = visible


func _exit_tree() -> void:
	_cleanup_script_editor()
	_cleanup_export_plugin()
	_cleanup_import_plugins()

	if filesystem_dock:
		filesystem_dock.remove_resource_tooltip_plugin(ks_tooltip_plugin)
		ks_tooltip_plugin = null

	if inspector_plugin != null:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null
	print("Konado unloaded")


func _disable_plugin() -> void:
	# Godot clears custom resource handlers before EditorPlugin._exit_tree during
	# editor shutdown. Remove them here for live plugin disable/re-enable, while
	# allowing the engine to own shutdown cleanup.
	_detach_debugger_plugin()
	_cleanup_script_resources()
	if ProjectSettings.has_setting("autoload/" + I18N_AUTOLOAD_NAME):
		remove_autoload_singleton(I18N_AUTOLOAD_NAME)


func _setup_script_editor() -> void:
	var script_editor := get_editor_interface().get_script_editor()
	ks_highlighter = KS_HIGHLIGHTER_SCRIPT.new()
	script_editor.register_syntax_highlighter(ks_highlighter)
	ks_script_editor_integration = KS_SCRIPT_EDITOR_INTEGRATION_SCRIPT.new()
	ks_script_editor_integration.setup(script_editor, _plugin_version)
	# A headless editor has no interactive debugger session UI and may terminate
	# before EditorDebuggerNode completes its normal detach sequence.
	if DisplayServer.get_name() != "headless":
		var debugger_script := (
			load("res://addons/konado/editor/ks_editor/ks_debugger_plugin.gd") as GDScript
		)
		ks_debugger_plugin = debugger_script.new()
		add_debugger_plugin(ks_debugger_plugin)
		_debugger_registered = true
		var base_control := get_editor_interface().get_base_control()
		if not base_control.tree_exiting.is_connected(_detach_debugger_plugin):
			base_control.tree_exiting.connect(_detach_debugger_plugin)
	ks_create_menu = KS_CREATE_MENU_SCRIPT.new()
	add_context_menu_plugin(
		EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE,
		ks_create_menu,
	)
	ks_code_context_menu = KS_CODE_CONTEXT_MENU_SCRIPT.new()
	add_context_menu_plugin(
		EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE,
		ks_code_context_menu,
	)


func _setup_script_resources() -> void:
	ks_resource_loader = KS_RESOURCE_LOADER_SCRIPT.new()
	ks_source_saver = KS_SOURCE_SAVER_SCRIPT.new()
	ResourceLoader.add_resource_format_loader(ks_resource_loader, true)
	ResourceSaver.add_resource_format_saver(ks_source_saver, true)


func _cleanup_script_resources() -> void:
	if ks_source_saver:
		ResourceSaver.remove_resource_format_saver(ks_source_saver)
		ks_source_saver = null
	if ks_resource_loader:
		ResourceLoader.remove_resource_format_loader(ks_resource_loader)
		ks_resource_loader = null


func _cleanup_script_editor() -> void:
	_detach_debugger_plugin()
	if ks_script_editor_integration:
		ks_script_editor_integration.cleanup()
		ks_script_editor_integration = null
	if ks_code_context_menu:
		remove_context_menu_plugin(ks_code_context_menu)
		if ks_code_context_menu.has_method("cleanup"):
			ks_code_context_menu.cleanup()
		ks_code_context_menu = null
	if ks_create_menu:
		remove_context_menu_plugin(ks_create_menu)
		if ks_create_menu.has_method("cleanup"):
			ks_create_menu.cleanup()
		ks_create_menu = null
	if ks_highlighter:
		get_editor_interface().get_script_editor().unregister_syntax_highlighter(ks_highlighter)
		ks_highlighter = null


func _detach_debugger_plugin() -> void:
	if not _debugger_registered or ks_debugger_plugin == null:
		return
	if ks_debugger_plugin.has_method("cleanup"):
		ks_debugger_plugin.cleanup()
	remove_debugger_plugin(ks_debugger_plugin)
	_debugger_registered = false
	ks_debugger_plugin = null


## 设置导入插件
func _setup_import_plugins() -> void:
	kdic_import_plugin = KDIC_IMPORTER_SCRIPT.new()

	add_import_plugin(kdic_import_plugin)


## 清理导入插件
func _cleanup_import_plugins() -> void:
	if kdic_import_plugin:
		remove_import_plugin(kdic_import_plugin)
		kdic_import_plugin = null


func _setup_export_plugin() -> void:
	ks_export_plugin = KS_EXPORT_PLUGIN_SCRIPT.new()
	add_export_plugin(ks_export_plugin)


func _cleanup_export_plugin() -> void:
	if ks_export_plugin:
		remove_export_plugin(ks_export_plugin)
		ks_export_plugin = null


## 打印加载信息
func _print_loading_message() -> void:
	print("Konado %s %s" % [_plugin_version, CODENAME])
	print("Konado loaded")


static func _read_plugin_version() -> String:
	var config := ConfigFile.new()
	if config.load(PLUGIN_CONFIG_PATH) != OK:
		return ""
	return String(config.get_value("plugin", "version", "")).strip_edges()
