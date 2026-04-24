extends Node

## 全局成就管理器单例

signal achievement_unlocked(achievement_id: String, data: Dictionary)
signal achievement_progress_updated(achievement_id: String, current: float, target: float)
signal achievements_reset()
signal achievements_loaded()

@export var config_path: String = "res://addons/konado_achievement/data/achievements.json"
@export var save_path: String = "user://achievements_save.json"
@export var popup_duration: float = 3.0
@export var popup_position: String = "top_left" # top_left, top_right, bottom_left, bottom_right

var _achievements: Dictionary = {}       # id -> 成就数据字典
var _unlocked: Dictionary = {}           # id -> bool
var _progress: Dictionary = {}           # key -> float (计数器值)
var _popup_scene: PackedScene = null
var _panel_scene: PackedScene = null
var _active_popup: Control = null
var _active_panel: Control = null
var _popup_timer: Timer = null

## 覆盖此回调以将解锁同步到外部后端。
## func(achievement_id: String, data: Dictionary) -> void
var on_external_unlock: Callable = Callable()

## 覆盖此以提供自定义保存/加载后端。
var custom_save_handler: Callable = Callable()  # func(data: Dictionary) -> void
var custom_load_handler: Callable = Callable()  # func() -> Dictionary


func _ready() -> void:
	_popup_scene = load("res://addons/konado_achievement/achievement_popup.tscn")
	_panel_scene = load("res://addons/konado_achievement/achievement_panel.tscn")
	_load_config()
	_load_save_data()
	achievements_loaded.emit()

func _load_config() -> void:
	_achievements.clear()
	var file := FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_warning("KonadoAchievement 无法打开配置：%s" % config_path)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("KonadoAchievement JSON 解析错误：%s" % json.get_error_message())
		return
	var data: Dictionary = json.data
	if data.has("achievements") and data["achievements"] is Array:
		for entry in data["achievements"]:
			if entry is Dictionary and entry.has("id"):
				_achievements[entry["id"]] = entry
	print("KonadoAchievement 加载了 %d 个成就。" % _achievements.size())

func _load_save_data() -> void:
	if custom_load_handler.is_valid():
		var data: Dictionary = custom_load_handler.call()
		_unlocked = data.get("unlocked", {})
		_progress = data.get("progress", {})
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return
	var data: Dictionary = json.data
	_unlocked = data.get("unlocked", {})
	_progress = data.get("progress", {})

func _save_data() -> void:
	var data := {"unlocked": _unlocked, "progress": _progress}
	if custom_save_handler.is_valid():
		custom_save_handler.call(data)
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("KonadoAchievement 无法写入保存：%s" % save_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## 通过 ID 直接解锁成就。如果是新解锁则返回 true。
func unlock_achievement(achievement_id: String) -> bool:
	if not _achievements.has(achievement_id):
		push_warning("KonadoAchievement 未知成就：%s" % achievement_id)
		return false
	if _unlocked.get(achievement_id, false):
		return false  # 已经解锁
	_unlocked[achievement_id] = true
	var ach_data: Dictionary = _achievements[achievement_id]
	_save_data()
	achievement_unlocked.emit(achievement_id, ach_data)
	_show_popup(ach_data)
	# 外部集成回调
	if on_external_unlock.is_valid():
		on_external_unlock.call(achievement_id, ach_data)
	return true

## 增加计数器键值并自动检查相关成就。
func increment_progress(key: String, amount: float = 1.0) -> void:
	_progress[key] = _progress.get(key, 0.0) + amount
	_save_data()
	# 检查所有依赖于此键的成就
	for ach_id in _achievements:
		if _unlocked.get(ach_id, false):
			continue
		var ach: Dictionary = _achievements[ach_id]
		var cond: Dictionary = ach.get("conditions", {})
		if cond.get("target_key", "") == key:
			var target_val: float = float(cond.get("target_value", 0))
			achievement_progress_updated.emit(ach_id, _progress[key], target_val)
			if _check_conditions(cond):
				unlock_achievement(ach_id)

## 设置标志键值并自动检查相关成就。
func set_flag(key: String, value: Variant = true) -> void:
	_progress[key] = value
	_save_data()
	for ach_id in _achievements:
		if _unlocked.get(ach_id, false):
			continue
		var ach: Dictionary = _achievements[ach_id]
		var cond: Dictionary = ach.get("conditions", {})
		if cond.get("target_key", "") == key:
			if _check_conditions(cond):
				unlock_achievement(ach_id)

## 检查成就是否已解锁。
func is_unlocked(achievement_id: String) -> bool:
	return _unlocked.get(achievement_id, false)

## 获取单个成就的完整数据字典。
func get_achievement(achievement_id: String) -> Dictionary:
	return _achievements.get(achievement_id, {})

## 获取所有成就作为字典数组。
func get_all_achievements() -> Array:
	var result: Array = []
	for ach_id in _achievements:
		var d: Dictionary = _achievements[ach_id].duplicate()
		d["unlocked"] = _unlocked.get(ach_id, false)
		result.append(d)
	return result

## 仅获取已解锁的成就。
func get_unlocked_achievements() -> Array:
	return get_all_achievements().filter(func(a): return a["unlocked"])

## 仅获取未解锁的成就。
func get_locked_achievements() -> Array:
	return get_all_achievements().filter(func(a): return not a["unlocked"])

## 获取键的当前进度值。
func get_progress(key: String) -> float:
	return float(_progress.get(key, 0.0))

## 获取解锁百分比（0.0 到 1.0）。
func get_unlock_percentage() -> float:
	if _achievements.is_empty():
		return 0.0
	var unlocked_count := 0
	for ach_id in _achievements:
		if _unlocked.get(ach_id, false):
			unlocked_count += 1
	return float(unlocked_count) / float(_achievements.size())

## 重置所有成就和进度
func reset_all() -> void:
	print("重置所有成就")
	_unlocked.clear()
	_progress.clear()
	_save_data()
	achievements_reset.emit()

## 重置单个成就
func reset_achievement(achievement_id: String) -> void:
	_unlocked.erase(achievement_id)
	_save_data()

## 从 JSON 重新加载配置
func reload_config() -> void:
	_load_config()
	_load_save_data()
	achievements_loaded.emit()

# 弹出成就
func _show_popup(ach_data: Dictionary) -> void:
	if not _popup_scene:
		return
	# 关闭现有弹出
	_dismiss_popup()
	_active_popup = _popup_scene.instantiate()
	# 添加到场景树的根视口
	var root := get_tree().root
	root.add_child(_active_popup)
	# 设置弹出内容
	if _active_popup.has_method("setup"):
		var icon_path: String = ach_data.get("icon", "")
		if icon_path.is_empty():
			icon_path = "res://addons/konado_achievement/icons/default_icon.svg"
		_active_popup.setup(ach_data.get("name", ""), ach_data.get("description", ""), icon_path, popup_position)
	# 自动关闭计时器
	if _popup_timer:
		_popup_timer.queue_free()
	_popup_timer = Timer.new()
	_popup_timer.wait_time = popup_duration
	_popup_timer.one_shot = true
	_popup_timer.timeout.connect(_dismiss_popup)
	add_child(_popup_timer)
	_popup_timer.start()

func _dismiss_popup() -> void:
	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null

# 弹出成就列表
func show_panel() -> void:
	if _active_panel and is_instance_valid(_active_panel):
		_active_panel.visible = true
		if _active_panel.has_method("refresh"):
			_active_panel.refresh()
		return
	if not _panel_scene:
		return
	_active_panel = _panel_scene.instantiate()
	var root := get_tree().root
	root.add_child(_active_panel)
	if _active_panel.has_method("refresh"):
		_active_panel.refresh()

func hide_panel() -> void:
	if _active_panel and is_instance_valid(_active_panel):
		_active_panel.visible = false

func toggle_panel() -> void:
	if is_panel_visible():
		hide_panel()
	else:
		show_panel()

func is_panel_visible() -> bool:
	return _active_panel != null and is_instance_valid(_active_panel) and _active_panel.visible

## 判断成就条件
func _check_conditions(cond: Dictionary) -> bool:
	var cond_type: String = cond.get("type", "flag")
	var key: String = cond.get("target_key", "")
	var target = cond.get("target_value", 0)
	match cond_type:
		"counter":
			return _progress.get(key, 0.0) >= float(target)
		"flag":
			return _progress.get(key, false) == target
		_:
			return false
