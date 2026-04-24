@tool
extends EditorPlugin

const AUTOLOAD_NAME := "KND_AchievementManager"
const AUTOLOAD_PATH := "res://addons/konado_achievement/achievement_manager.gd"

var _debug_dock: Control = null

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	print("[Achievement] 已启用。")

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	print("[Achievement] 已禁用。")
