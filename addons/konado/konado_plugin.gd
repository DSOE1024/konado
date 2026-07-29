@tool
extends EditorPlugin
class_name KonadoEditorPlugin
# Konado框架入口文件，负责初始化插件和注册相关功能

const VERSION: String = "2.6.2"
const CODENAME: String = "Ketchup"
const I18N_AUTOLOAD_NAME := "KND_I18n"
const I18N_AUTOLOAD_PATH := "res://addons/konado/i18n/knd_i18n.gd"
const EDITOR_METADATA_SECTION := "konado"
const KS_IMPORT_VERSION_METADATA_KEY := "ks_import_format_version"

## 自定义EditorImportPlugin脚本
const KS_IMPORTER_SCRIPT := preload("uid://rp35gse7j4sv")
const KDIC_IMPORTER_SCRIPT := preload("uid://b7a8r75oh165c")
const KS_EXPORT_PLUGIN_SCRIPT := preload("res://addons/konado/export/knd_script_export_plugin.gd")

## 插件实例变量
var ks_import_plugin: EditorImportPlugin
var kdic_import_plugin: EditorImportPlugin
var ks_export_plugin: EditorExportPlugin

# 文件系统dock
var filesystem_dock: FileSystemDock
var ks_tooltip_plugin: EditorResourceTooltipPlugin

var ks_editor: KsEditorWindow
var ks_dock: EditorDock

var inspector_plugin: EditorInspectorPlugin = null
var _ks_import_migration_running := false
var _ks_import_migration_retry_pending := false


func _has_main_screen() -> bool:
	return false


func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/" + I18N_AUTOLOAD_NAME):
		add_autoload_singleton(I18N_AUTOLOAD_NAME, I18N_AUTOLOAD_PATH)
	_setup_import_plugins()
	_schedule_ks_import_migration()
	_setup_export_plugin()
	_print_loading_message()

	filesystem_dock = get_editor_interface().get_file_system_dock()
	ks_tooltip_plugin = preload("res://addons/konado/ks/ks_tooltip_plugin.gd").new()
	filesystem_dock.add_resource_tooltip_plugin(ks_tooltip_plugin)

	ks_dock = EditorDock.new()
	ks_dock.title = "KonadoEdit"
	# 4.5改用 EditorPlugin
	#ks_dock.default_slot = EditorPlugin.DOCK_SLOT_BOTTOM
	# 4.6以上改用 EditorDock
	ks_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	ks_editor = (
		load("res://addons/konado/editor/ks_editor/ks_editor.tscn").instantiate() as KsEditorWindow
	)
	ks_dock.add_child(ks_editor)
	ks_editor.visible = true
	add_dock(ks_dock)

	inspector_plugin = (
		preload("res://addons/konado/audioeffect/audioeffect_inspector_plugin.gd").new()
	)
	# add_inspector_plugin完成注册
	add_inspector_plugin(inspector_plugin)


# 控制显示
#func _make_visible(visible: bool) -> void:
#ks_dock.visible = visible


func _exit_tree() -> void:
	_cancel_ks_import_migration()
	_cleanup_export_plugin()
	_cleanup_import_plugins()

	if filesystem_dock:
		filesystem_dock.remove_resource_tooltip_plugin(ks_tooltip_plugin)
		ks_tooltip_plugin = null

	if ks_dock:
		if ks_editor:
			ks_editor.prepare_for_shutdown()
		remove_dock(ks_dock)
		ks_dock.queue_free()

	if inspector_plugin != null:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null
	print("Konado unloaded")


func _disable_plugin() -> void:
	if ProjectSettings.has_setting("autoload/" + I18N_AUTOLOAD_NAME):
		remove_autoload_singleton(I18N_AUTOLOAD_NAME)


## 用于处理ks文件和KND_Shot资源
func _handles(object: Object) -> bool:
	if object is Resource and object.resource_path.get_extension() == "ks":
		return true
	return false


func _edit(object: Object) -> void:
	if object is Resource and object.resource_path.get_extension() == "ks":
		ks_editor.edit(object.resource_path)
		ks_dock.make_visible()


## 设置导入插件
func _setup_import_plugins() -> void:
	ks_import_plugin = KS_IMPORTER_SCRIPT.new()
	kdic_import_plugin = KDIC_IMPORTER_SCRIPT.new()

	add_import_plugin(ks_import_plugin)
	add_import_plugin(kdic_import_plugin)


func _schedule_ks_import_migration() -> void:
	if _ks_import_migration_retry_pending:
		return
	_ks_import_migration_retry_pending = true
	call_deferred("_migrate_ks_imports")


func _migrate_ks_imports() -> void:
	_ks_import_migration_retry_pending = false
	if ks_import_plugin == null or _ks_import_migration_running:
		return
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing():
		_wait_for_filesystem_before_migration(filesystem)
		return
	_disconnect_ks_migration_retry(filesystem)

	var target_version := ks_import_plugin._get_format_version()
	var editor_settings := get_editor_interface().get_editor_settings()
	var completed_version := int(
		editor_settings.get_project_metadata(
			EDITOR_METADATA_SECTION, KS_IMPORT_VERSION_METADATA_KEY, 0
		)
	)
	if completed_version >= target_version:
		return

	_ks_import_migration_running = true
	var script_paths: PackedStringArray = []
	_collect_ks_paths(filesystem.get_filesystem(), script_paths)
	var reimport_paths: PackedStringArray = []
	for path: String in script_paths:
		if _ks_import_needs_migration(path, target_version):
			reimport_paths.append(path)
	if not reimport_paths.is_empty():
		print("[Konado] 正在迁移 %d 个 KonadoScript 导入缓存。" % reimport_paths.size())
		filesystem.reimport_files(reimport_paths)

	var failed_paths: PackedStringArray = []
	for path: String in script_paths:
		if (
			_ks_import_needs_migration(path, target_version)
			or not ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) is KND_Shot
		):
			failed_paths.append(path)
	if failed_paths.is_empty():
		editor_settings.set_project_metadata(
			EDITOR_METADATA_SECTION, KS_IMPORT_VERSION_METADATA_KEY, target_version
		)
	else:
		push_warning("[Konado] 以下 KonadoScript 导入缓存迁移失败，将在下次启动时重试：%s" % ", ".join(failed_paths))
	_ks_import_migration_running = false


func _wait_for_filesystem_before_migration(filesystem: EditorFileSystem) -> void:
	var callback := Callable(self, "_on_filesystem_ready_for_ks_migration")
	if not filesystem.filesystem_changed.is_connected(callback):
		filesystem.filesystem_changed.connect(callback)


func _on_filesystem_ready_for_ks_migration() -> void:
	_schedule_ks_import_migration()


func _cancel_ks_import_migration() -> void:
	_ks_import_migration_retry_pending = false
	var filesystem := get_editor_interface().get_resource_filesystem()
	_disconnect_ks_migration_retry(filesystem)


func _disconnect_ks_migration_retry(filesystem: EditorFileSystem) -> void:
	var callback := Callable(self, "_on_filesystem_ready_for_ks_migration")
	if filesystem.filesystem_changed.is_connected(callback):
		filesystem.filesystem_changed.disconnect(callback)


func _collect_ks_paths(directory: EditorFileSystemDirectory, result: PackedStringArray) -> void:
	for file_index in directory.get_file_count():
		var path := directory.get_file_path(file_index)
		if path.get_extension().to_lower() == "ks":
			result.append(path)
	for directory_index in directory.get_subdir_count():
		_collect_ks_paths(directory.get_subdir(directory_index), result)


func _ks_import_needs_migration(path: String, target_version: int) -> bool:
	var import_config := ConfigFile.new()
	if import_config.load(path + ".import") != OK:
		return true
	return (
		import_config.get_value("remap", "importer", "") != "konado.scripts"
		or import_config.get_value("remap", "type", "") != "Resource"
		or int(import_config.get_value("remap", "importer_version", 0)) < target_version
	)


## 清理导入插件
func _cleanup_import_plugins() -> void:
	if ks_import_plugin:
		remove_import_plugin(ks_import_plugin)
		ks_import_plugin = null

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
	print("Konado %s %s" % [VERSION, CODENAME])
	print("Konado loaded")
