@tool
extends ScriptExtension
class_name KND_Shot

static var _konado_script_language: KND_KonadoScriptLanguage

@export var ks_path: String = "null"

@export var shot_id: String = "新镜头"

## 起始节点ID
@export var start_node_id: String = ""

## 所有对话节点（扁平列表）
@export var dialogues: Array[KND_Dialogue]:
	set(value):
		_dialogues = value
	get:
		if _protection_version > 0 and not Engine.is_editor_hint():
			ensure_script_ready()
		return _dialogues

## 依赖角色
@export var dep_characters: Array[String] = []

@export_storage var _protection_version := 0
@export_storage var _protection_serialized_size := 0
@export_storage var _protection_iv := PackedByteArray()
@export_storage var _protection_wrapped_key := PackedByteArray()
@export_storage var _protection_ciphertext := PackedByteArray()
@export_storage var _protection_mac := PackedByteArray()

var _dialogues: Array[KND_Dialogue] = []
var _protection_attempted := false
var _source_code := ""
var _source_loaded := false


## Expose loaded KonadoScript data as an editor-only script document.
##
## Runtime dialogue behavior remains resource-based. Implementing ScriptExtension
## lets Godot's native Script Editor own editing, saving, diagnostics, completion,
## navigation, and external-change handling for the original .ks source.
func _editor_can_reload_from_file() -> bool:
	return true


func _can_instantiate() -> bool:
	return false


func _get_base_script() -> Script:
	return null


func _get_global_name() -> StringName:
	return &""


func _inherits_script(_script: Script) -> bool:
	return false


func _get_instance_base_type() -> StringName:
	return &""


func _has_source_code() -> bool:
	return true


func _get_source_code() -> String:
	_load_source_code()
	return _source_code


func _set_source_code(source: String) -> void:
	_source_code = source
	_source_loaded = true


func _reload(_keep_state: bool) -> Error:
	_source_loaded = false
	_source_code = ""
	_load_source_code()
	return OK if _source_loaded else ERR_FILE_CANT_OPEN


func _get_doc_class_name() -> StringName:
	return &""


func _get_documentation() -> Array[Dictionary]:
	return []


func _get_method_info(_method: StringName) -> Dictionary:
	return {}


func _is_valid() -> bool:
	return true


func _is_tool() -> bool:
	return false


func _get_language() -> ScriptLanguage:
	if _konado_script_language == null:
		_konado_script_language = KND_KonadoScriptLanguage.new()
	return _konado_script_language


func _has_method(_method: StringName) -> bool:
	return false


func _has_static_method(_method: StringName) -> bool:
	return false


func _has_script_signal(_signal: StringName) -> bool:
	return false


func _get_script_signal_list() -> Array[Dictionary]:
	return []


func _has_property_default_value(_property: StringName) -> bool:
	return false


func _get_property_default_value(_property: StringName) -> Variant:
	return null


func _update_exports() -> void:
	pass


func _get_script_method_list() -> Array[Dictionary]:
	return []


func _get_script_property_list() -> Array[Dictionary]:
	return []


func _get_member_line(_member: StringName) -> int:
	return -1


func _get_constants() -> Dictionary:
	return {}


func _get_members() -> Array[StringName]:
	return []


func _is_placeholder_fallback_enabled() -> bool:
	return false


func _get_rpc_config() -> Variant:
	return {}


func _load_source_code() -> void:
	if _source_loaded:
		return
	if not Engine.is_editor_hint() or ks_path.is_empty() or ks_path == "null":
		_source_loaded = true
		return
	var file := FileAccess.open(ks_path, FileAccess.READ)
	if file == null:
		return
	_source_code = file.get_as_text()
	_source_loaded = true


## Convert this shot into an encrypted export resource.
func protect_script_for_export(build_key: PackedByteArray) -> bool:
	if is_script_protected():
		return true
	var result := KND_ScriptProtection.protect(_dialogues, build_key, ks_path)
	if not result.get("ok", false):
		push_error("[Konado] %s：%s" % [ks_path, result.get("error", "未知加密错误")])
		return false
	_protection_version = result["version"]
	_protection_serialized_size = result["serialized_size"]
	_protection_iv = result["iv"]
	_protection_wrapped_key = result["wrapped_key"]
	_protection_ciphertext = result["ciphertext"]
	_protection_mac = result["mac"]
	_dialogues.clear()
	_protection_attempted = false
	return true


## Restore protected dialogue nodes in memory on their first runtime access.
func ensure_script_ready() -> bool:
	if not is_script_protected():
		return true
	if _protection_attempted:
		return false
	_protection_attempted = true
	var result := KND_ScriptProtection.unprotect(
		_protection_version,
		_protection_serialized_size,
		_protection_iv,
		_protection_wrapped_key,
		_protection_ciphertext,
		_protection_mac,
		ks_path
	)
	if not result.get("ok", false):
		push_error("[Konado] %s：%s" % [ks_path, result.get("error", "未知解密错误")])
		return false
	_dialogues = result["dialogues"]
	_clear_script_protection()
	return true


func is_script_protected() -> bool:
	return _protection_version > 0


func _clear_script_protection() -> void:
	_protection_version = 0
	_protection_serialized_size = 0
	_protection_iv.clear()
	_protection_wrapped_key.clear()
	_protection_ciphertext.clear()
	_protection_mac.clear()
	_protection_attempted = false


## 根据 node_id 查找对话节点
func find_node(id: String) -> KND_Dialogue:
	if not ensure_script_ready():
		return null
	if id.is_empty():
		return null
	for d in _dialogues:
		if d.node_id == id:
			return d
	return null


## 获取起始节点
func get_start_node() -> KND_Dialogue:
	if not ensure_script_ready():
		return null
	if not start_node_id.is_empty():
		return find_node(start_node_id)
	if _dialogues.size() > 0:
		return _dialogues[0]
	return null
