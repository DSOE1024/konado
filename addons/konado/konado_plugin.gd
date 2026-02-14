@tool
extends EditorPlugin
class_name KonadoEditorPlugin
# Konado框架入口文件，负责初始化插件和注册相关功能

## 插件版本信息
const VERSION: String = "2.3"
const CODENAME: String = "Tieton"

## 自定义EditorImportPlugin脚本
const KS_IMPORTER_SCRIPT := preload("res://addons/konado/importer/konado_importer.gd")
const KDIC_IMPORTER_SCRIPT := preload("res://addons/konado/editor/ks_csv_importer/ks_csv_importer.gd")


## 翻译文件路径
const TRANSLATION_PATHS: PackedStringArray = [
	#"res://addons/konado/i18n/i18n.zh.translation",
	#"res://addons/konado/i18n/i18n.zh_HK.translation",
	#"res://addons/konado/i18n/i18n.en.translation",
	#"res://addons/konado/i18n/i18n.ja.translation",
	#"res://addons/konado/i18n/i18n.ko.translation",
	#"res://addons/konado/i18n/i18n.de.translation"
]



## 插件实例变量
var ks_import_plugin: EditorImportPlugin
var kdic_import_plugin: EditorImportPlugin

# 文件系统dock
var filesystem_dock: FileSystemDock
var ks_tooltip_plugin: EditorResourceTooltipPlugin

var ks_editor: KsEditorWindow

var inspector_plugin: EditorInspectorPlugin = null

func _get_plugin_name() -> String:
	return "Konado"
	
func _get_plugin_icon() -> Texture2D:
	return null
	
func _has_main_screen() -> bool:
	return true

func _enter_tree() -> void:
	_setup_import_plugins()

	_print_loading_message()
	
	filesystem_dock = get_editor_interface().get_file_system_dock()
	ks_tooltip_plugin = preload("res://addons/konado/ks/ks_tooltip_plugin.gd").new()
	filesystem_dock.add_resource_tooltip_plugin(ks_tooltip_plugin)
	

	ks_editor = load("res://addons/konado/editor/ks_editor/ks_editor.tscn").instantiate() as KsEditorWindow
	EditorInterface.get_editor_main_screen().add_child(ks_editor)
	ks_editor.hide()
	
	var inspector_plugin = preload("res://addons/konado/audioeffect/audioeffect_inspector_plugin.gd").new()
	# add_inspector_plugin完成注册
	add_inspector_plugin(inspector_plugin)
	
# 控制显示
func _make_visible(visible:bool) -> void:
	if not ks_editor:
		return

	if ks_editor.get_parent() is Window:
		if visible:
			get_editor_interface().set_main_screen_editor("Script")
			ks_editor.show()
			ks_editor.get_parent().grab_focus()
	else:
		ks_editor.visible = visible

func _exit_tree() -> void:
	_cleanup_import_plugins()
	
	if filesystem_dock:
		filesystem_dock.remove_resource_tooltip_plugin(ks_tooltip_plugin)
		ks_tooltip_plugin = null
		
	if ks_editor:
		EditorInterface.get_editor_main_screen().remove_child(ks_editor)
	
	if inspector_plugin != null:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null
	print("Konado unloaded")

## 用于处理ks文件
func _handles(object: Object) -> bool:
	if object is Resource and object.resource_path.get_extension() == "ks":
		ks_editor.edit(object.resource_path)
		return true
	return false
	
	

## 设置导入插件
func _setup_import_plugins() -> void:
	ks_import_plugin = KS_IMPORTER_SCRIPT.new()
	kdic_import_plugin = KDIC_IMPORTER_SCRIPT.new()
	
	add_import_plugin(ks_import_plugin)
	add_import_plugin(kdic_import_plugin)
	
	
## 设置国际化
func _setup_internationalization() -> void:
	ProjectSettings.set_setting("internationalization/locale/translations", TRANSLATION_PATHS)
	ProjectSettings.set_setting("internationalization/locale/locale_filter_mode", 1)  # 允许所有区域
	ProjectSettings.save()
	

## 清理导入插件
func _cleanup_import_plugins() -> void:
	if ks_import_plugin:
		remove_import_plugin(ks_import_plugin)
		ks_import_plugin = null
		
	if kdic_import_plugin:
		remove_import_plugin(kdic_import_plugin)
		kdic_import_plugin = null
		
		
## 打印加载信息
func _print_loading_message() -> void:
	print("Konado %s %s" % [VERSION, CODENAME])
	print("Konado loaded")
