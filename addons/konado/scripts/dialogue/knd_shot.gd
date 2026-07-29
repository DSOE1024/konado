@tool
extends KND_Data
class_name KND_Shot

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
