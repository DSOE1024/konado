@tool
extends EditorPlugin

const AUTOLOAD_NAME := "KND_WebTool"
const AUTOLOAD_PATH := "res://addons/konado_webtool/konado_webtool.gd"


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	print("[KND_WebTool] 已启用")

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	print("[KND_WebTool] 已禁用")
