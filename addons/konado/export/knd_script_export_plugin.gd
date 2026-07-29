@tool
extends EditorExportPlugin

## Encrypts compiled KS dialogue payloads with a fresh key for every export.

const EXPORT_CACHE_ROOT := "user://.konado_export"
const PROTECTED_RESOURCE_ROOT := "res://.konado_script_data"

var _build_key := PackedByteArray()
var _export_cache_dir := ""
var _key_announced := false
var _protected_shot_count := 0
var _failed_shot_count := 0
var _last_protection_error := ""


func _get_name() -> String:
	return "KonadoScriptProtection"


func _supports_platform(_platform: EditorExportPlatform) -> bool:
	return true


func _export_begin(_features: PackedStringArray, is_debug: bool, path: String, _flags: int) -> void:
	_start_export_key()
	var export_kind := "调试" if is_debug else "正式"
	print("[Konado] 已为%s导出生成随机剧本密钥：%s" % [export_kind, path])
	_announce_key()


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.get_extension().to_lower() != "ks":
		return
	_ensure_export_key()
	var protected_bytes := _protect_script(path)
	if protected_bytes.is_empty():
		_register_export_failure(path)
		skip()
		return
	var protected_path := PROTECTED_RESOURCE_ROOT.path_join("%s.res" % path.md5_text())
	add_file(protected_path, protected_bytes, false)
	add_file(path + ".remap", _build_remap(protected_path), false)
	skip()
	_protected_shot_count += 1


func _protect_script(path: String) -> PackedByteArray:
	_last_protection_error = ""
	var source_shot := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as KND_Shot
	if source_shot == null:
		return _protection_failure("无法加载待加密的剧本资源")
	var protected_shot := source_shot.duplicate(true) as KND_Shot
	if protected_shot == null:
		return _protection_failure("无法复制待加密的剧本资源")
	if not protected_shot.protect_script_for_export(_build_key):
		return _protection_failure("无法加密剧本资源")
	if not protected_shot.dialogues.is_empty():
		return _protection_failure("加密后仍残留明文剧本节点")
	return _serialize_protected_shot(protected_shot, path)


func _serialize_protected_shot(shot: KND_Shot, source_path: String) -> PackedByteArray:
	if _export_cache_dir.is_empty():
		return _protection_failure("剧本导出缓存目录尚未初始化")
	var cache_path := _export_cache_dir.path_join("%s.res" % source_path.md5_text())
	var absolute_cache_dir := ProjectSettings.globalize_path(cache_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_cache_dir) != OK:
		return _protection_failure("无法创建剧本导出缓存目录：%s" % absolute_cache_dir)
	var save_error := ResourceSaver.save(shot, cache_path)
	if save_error != OK:
		return _protection_failure("无法序列化加密剧本：%s" % error_string(save_error))
	var protected_bytes := FileAccess.get_file_as_bytes(cache_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
	if protected_bytes.is_empty():
		return _protection_failure("加密剧本导出数据为空")
	return protected_bytes


func _build_remap(protected_path: String) -> PackedByteArray:
	return ('[remap]\n\npath="%s"\n' % protected_path).to_utf8_buffer()


func _export_end() -> void:
	if _failed_shot_count == 0:
		print("[Konado] 剧本加密完成，共保护 %d 个 KND_Shot 资源。" % _protected_shot_count)
	else:
		push_error("[Konado] 剧本加密失败，共有 %d 个资源未能保护。" % _failed_shot_count)
	_cleanup_export_cache()
	_build_key.clear()
	_export_cache_dir = ""
	_key_announced = false
	_protected_shot_count = 0
	_failed_shot_count = 0
	_last_protection_error = ""


func _start_export_key() -> void:
	_cleanup_export_cache()
	_build_key = Crypto.new().generate_random_bytes(KND_ScriptProtection.KEY_SIZE)
	_export_cache_dir = EXPORT_CACHE_ROOT.path_join(
		Crypto.new().generate_random_bytes(8).hex_encode()
	)
	_key_announced = false
	_protected_shot_count = 0
	_failed_shot_count = 0
	_last_protection_error = ""


func _ensure_export_key() -> void:
	if _build_key.size() == KND_ScriptProtection.KEY_SIZE:
		return
	_start_export_key()
	_announce_key()


func _announce_key() -> void:
	if _key_announced:
		return
	_key_announced = true
	var key_hex := _build_key.hex_encode()
	if OS.has_environment("GITHUB_ACTIONS"):
		print("::add-mask::%s" % key_hex)
		print("[Konado] 本次导出剧本密钥：***（GitHub Actions 日志已自动隐藏）")
		return
	print("[Konado] 本次导出剧本密钥：%s" % key_hex)


func _protection_failure(message: String) -> PackedByteArray:
	_last_protection_error = message
	return PackedByteArray()


func _register_export_failure(path: String) -> void:
	_failed_shot_count += 1
	var reason := _last_protection_error
	if reason.is_empty():
		reason = "未知剧本保护错误"
	var message := "%s：%s" % [path, reason]
	push_error("[Konado] " + message)
	var export_platform := get_export_platform()
	if export_platform:
		export_platform.add_message(
			EditorExportPlatform.EXPORT_MESSAGE_ERROR, "KonadoScript Protection", message
		)


func _cleanup_export_cache() -> void:
	if _export_cache_dir.is_empty():
		return
	var directory := DirAccess.open(_export_cache_dir)
	if directory:
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir():
				DirAccess.remove_absolute(
					ProjectSettings.globalize_path(_export_cache_dir.path_join(entry))
				)
			entry = directory.get_next()
		directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_export_cache_dir))
