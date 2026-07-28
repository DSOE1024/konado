extends Node

## 设置管理器全局设置单例，作为自动加载由插件加载

## 当设置值改变时发出的信号
## @param category: 设置分类
## @param key: 设置项的键
## @param value: 新的设置值
signal setting_changed(category: String, key: String, value: Variant)

## 保存设置的文件路径
const SAVE_PATH := "user://knd_settings.cfg"

## 默认设置的JSON文件路径
const DEFAULT_JSON := "res://addons/konado_settings/resources/default_settings.json"

var save_path := SAVE_PATH

## 存储所有设置分类 { category_id: SettingCategory }
var _categories: Dictionary = {}

## 存储所有设置值 { category_id: { key: value } }
var _values: Dictionary = {}

## 配置文件对象，用于保存设置
var _config := ConfigFile.new()

## 当前运行平台
var _current_platform: String = "all"

## 是否已读取用户配置，用于支持运行时注册分类
var _saved_loaded: bool = false


## 获取设置的当前值
## @param category: 设置分类
## @param key: 设置项的键
## @return: 设置值，如果不存在则返回默认值或null
func get_setting(category: String, key: String) -> Variant:
	if _values.has(category) and _values[category].has(key):
		return _values[category][key]
	# 如果没有找到值，返回默认值
	if _categories.has(category):
		for item: KND_SettingItem in _categories[category].items:
			if item.key == key:
				return item.default_value
	push_warning("KND_Settings: 未知设置 %s/%s" % [category, key])
	return null


## 修改设置，持久化并发出信号
## @param category: 设置分类
## @param key: 设置项的键
## @param value: 新的设置值
func set_setting(category: String, key: String, value: Variant) -> bool:
	var item := _find_item(category, key)
	if item == null:
		push_warning("KND_Settings: 拒绝写入未知设置 %s/%s" % [category, key])
		return false
	var validation := _validate_value(item, value)
	if not validation.valid:
		push_warning("KND_Settings: 拒绝写入无效值 %s/%s" % [category, key])
		return false
	var normalized_value: Variant = validation.value
	var previous_value: Variant = _values[category][key]
	if previous_value == normalized_value:
		return true
	_values[category][key] = normalized_value
	if not _save_config():
		_values[category][key] = previous_value
		_rebuild_config()
		push_error("KND_Settings: 保存设置 %s/%s 失败" % [category, key])
		return false
	setting_changed.emit(category, key, normalized_value)
	return true


## 在运行时注册额外的设置分类
## @param cat: 要注册的设置分类
func register_category(cat: KND_SettingCategory) -> void:
	if cat == null or cat.id.is_empty():
		push_warning("KND_Settings: 忽略缺少有效 ID 的设置分类")
		return
	var item_keys: Dictionary = {}
	for item: KND_SettingItem in cat.items:
		if item == null or item.key.is_empty() or item_keys.has(item.key):
			push_warning("KND_Settings: 分类 %s 包含无效或重复设置项" % cat.id)
			return
		if not _validate_value(item, item.default_value).valid:
			push_warning("KND_Settings: 分类 %s 的默认值无效：%s" % [cat.id, item.key])
			return
		item_keys[item.key] = true
	var previous_values: Dictionary = _values.get(cat.id, {})
	var category_values: Dictionary = {}
	_categories[cat.id] = cat
	for item: KND_SettingItem in cat.items:
		var current_validation := _validate_value(item, previous_values.get(item.key))
		category_values[item.key] = (
			current_validation.value if current_validation.valid else item.default_value
		)
		if _saved_loaded and _config.has_section_key(cat.id, item.key):
			var saved_value: Variant = _config.get_value(cat.id, item.key)
			var validation := _validate_value(item, saved_value)
			if validation.valid:
				category_values[item.key] = validation.value
			else:
				push_warning("KND_Settings: 忽略无效存档值 %s/%s" % [cat.id, item.key])
	_values[cat.id] = category_values


## 将指定分类的所有设置重置为默认值
## @param category_id: 分类ID
func reset_category(category_id: String) -> bool:
	if not _categories.has(category_id):
		push_warning("KND_Settings: 未知设置分类 %s" % category_id)
		return false
	var cat: KND_SettingCategory = _categories[category_id]
	var previous_values: Dictionary = _values[category_id].duplicate(true)
	var changed_items: Array[KND_SettingItem] = []
	for item: KND_SettingItem in cat.items:
		if _values[category_id].get(item.key) != item.default_value:
			_values[category_id][item.key] = item.default_value
			changed_items.append(item)
	if changed_items.is_empty():
		return true
	if not _save_config():
		_values[category_id] = previous_values
		_rebuild_config()
		push_error("KND_Settings: 重置分类失败：%s" % category_id)
		return false
	for item: KND_SettingItem in changed_items:
		setting_changed.emit(category_id, item.key, item.default_value)
	return true


## 获取所有注册的分类（根据当前平台过滤）
## @return: 过滤后的分类数组
func get_categories() -> Array:
	var filtered_categories = []
	for cat in _categories.values():
		var filtered_cat = _filter_category_for_platform(cat)
		if not filtered_cat.items.is_empty():
			filtered_categories.append(filtered_cat)
	return filtered_categories


## 根据ID获取单个分类（根据当前平台过滤）
## @param id: 分类ID
## @return: 过滤后的分类对象
func get_category(id: String) -> KND_SettingCategory:
	var cat = _categories.get(id)
	if cat:
		return _filter_category_for_platform(cat)
	return cat


## 根据平台过滤分类中的设置项
## @param cat: 原始分类
## @return: 过滤后的分类
func _filter_category_for_platform(cat: KND_SettingCategory) -> KND_SettingCategory:
	var filtered_cat = KND_SettingCategory.new()
	filtered_cat.id = cat.id
	filtered_cat.display_name = cat.display_name

	for item: KND_SettingItem in cat.items:
		if _is_item_visible(item):
			filtered_cat.items.append(item)

	return filtered_cat


## 检查设置项是否在当前平台可见
## @param item: 设置项
## @return: 是否可见
func _is_item_visible(item: KND_SettingItem) -> bool:
	if item.platforms.is_empty():
		push_warning("建议补充配置platforms: [all]")
	if item.platforms.has("all"):
		return true

	if item.platforms.has(_current_platform):
		return true

	# 处理linuxbsd别名
	if _current_platform in ["linux", "bsd"] and item.platforms.has("linuxbsd"):
		return true

	# 处理debug/release
	if OS.has_feature("debug") and item.platforms.has("debug"):
		return true
	if not OS.has_feature("debug") and item.platforms.has("release"):
		return true

	return false


## 节点就绪时调用
func _ready() -> void:
	_detect_platform()  # 检测当前平台
	_load_defaults()  # 加载默认设置
	_load_saved()  # 加载已保存的设置


## 检测当前运行平台
func _detect_platform() -> void:
	if Engine.is_editor_hint():
		_current_platform = "editor"
		return

	# 使用OS.has_feature进行更可靠的平台检测
	if OS.has_feature("android"):
		_current_platform = "android"
	elif OS.has_feature("ios"):
		_current_platform = "ios"
	elif OS.has_feature("macos"):
		_current_platform = "macos"
	elif OS.has_feature("windows"):
		_current_platform = "windows"
	elif OS.has_feature("linux"):
		_current_platform = "linux"
	elif OS.has_feature("bsd"):
		_current_platform = "bsd"
	elif OS.has_feature("visionos"):
		_current_platform = "visionos"
	else:
		_current_platform = "all"


## 加载默认设置
func _load_defaults() -> void:
	if not FileAccess.file_exists(DEFAULT_JSON):
		push_warning("KND_Settings: 未找到default_settings.json文件")
		return

	var json_string := FileAccess.get_file_as_string(DEFAULT_JSON)
	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_warning("KND_Settings: 解析default_settings.json失败: " + json.get_error_message())
		return

	var data: Variant = json.get_data()
	if not data is Dictionary or not data.get("categories") is Array:
		push_warning("KND_Settings: default_settings.json必须包含categories数组")
		return

	for cat_data: Variant in data["categories"]:
		var cat := _parse_category(cat_data)
		if cat:
			if _categories.has(cat.id):
				push_warning("KND_Settings: 忽略重复分类 %s" % cat.id)
				continue
			register_category(cat)


## 解析分类数据
## @param data: 分类数据字典
## @return: 解析后的分类对象
func _parse_category(data: Variant) -> KND_SettingCategory:
	if not data is Dictionary:
		push_warning("KND_Settings: 忽略非对象分类")
		return null
	if not data.get("id") is String or data["id"].is_empty() or not data.get("items") is Array:
		push_warning("KND_Settings: 忽略结构无效的分类")
		return null
	if data.has("display_name") and not data["display_name"] is String:
		push_warning("KND_Settings: 忽略名称无效的分类 %s" % data["id"])
		return null

	var cat := KND_SettingCategory.new()
	cat.id = data.get("id", "")
	cat.display_name = data.get("display_name", "")

	var items_array: Array = data.get("items", [])
	var item_keys: Dictionary = {}
	for item_data: Variant in items_array:
		var item := _parse_item(item_data)
		if item:
			if item_keys.has(item.key):
				push_warning("KND_Settings: 忽略分类 %s 中的重复设置 %s" % [cat.id, item.key])
				continue
			item_keys[item.key] = true
			cat.items.append(item)

	return cat


## 解析设置项数据
## @param data: 设置项数据字典
## @return: 解析后的设置项对象
func _parse_item(data: Variant) -> KND_SettingItem:
	if not data is Dictionary:
		push_warning("KND_Settings: 忽略非对象设置项")
		return null
	var data_error := _get_item_data_error(data)
	if not data_error.is_empty():
		push_warning("KND_Settings: 忽略%s" % data_error)
		return null
	var item_type: int = int(data.get("type", KND_SettingItem.Type.SLIDER))

	var item := KND_SettingItem.new()
	item.key = data.get("key", "")
	item.label = data.get("label", "")
	item.type = item_type
	item.default_value = data.get("default_value", 0.0)
	if item.type == KND_SettingItem.Type.SLIDER:
		item.min_value = float(data.get("min_value", 0.0))
		item.max_value = float(data.get("max_value", 1.0))
		item.step = float(data.get("step", 0.01))

	if data.has("options"):
		item.options.assign(data["options"])

	if data.has("platforms"):
		item.platforms.assign(data["platforms"])

	if data.has("tooltip"):
		item.tooltip = data.get("tooltip", "")

	var default_validation := _validate_value(item, item.default_value)
	if not default_validation.valid:
		push_warning("KND_Settings: 忽略默认值无效的设置项 %s" % item.key)
		return null
	item.default_value = default_validation.value
	return item


func _get_item_data_error(data: Dictionary) -> String:
	var error_message: String = ""
	var item_key: Variant = data.get("key")
	var item_type: Variant = data.get("type", KND_SettingItem.Type.SLIDER)
	var normalized_item_type: int = (
		int(item_type) if typeof(item_type) in [TYPE_INT, TYPE_FLOAT] else -1
	)
	if not item_key is String or item_key.is_empty():
		error_message = "缺少有效 key 的设置项"
	elif (
		typeof(item_type) not in [TYPE_INT, TYPE_FLOAT]
		or float(item_type) != float(normalized_item_type)
		or normalized_item_type not in KND_SettingItem.Type.values()
	):
		error_message = "类型无效的设置项 %s" % item_key
	else:
		for string_field: String in ["label", "tooltip"]:
			if data.has(string_field) and not data[string_field] is String:
				error_message = "%s 无效的设置项 %s" % [string_field, item_key]
				break
	if error_message.is_empty() and normalized_item_type == KND_SettingItem.Type.SLIDER:
		for numeric_field: String in ["min_value", "max_value", "step", "default_value"]:
			if (
				data.has(numeric_field)
				and typeof(data[numeric_field]) not in [TYPE_INT, TYPE_FLOAT]
			):
				error_message = "%s 无效的设置项 %s" % [numeric_field, item_key]
				break
		if error_message.is_empty():
			var minimum := float(data.get("min_value", 0.0))
			var maximum := float(data.get("max_value", 1.0))
			var step := float(data.get("step", 0.01))
			if minimum > maximum or step <= 0.0:
				error_message = "数值范围无效的设置项 %s" % item_key
	if error_message.is_empty() and data.has("options") and not _is_string_array(data["options"]):
		error_message = "options 无效的设置项 %s" % item_key
	if (
		error_message.is_empty()
		and normalized_item_type == KND_SettingItem.Type.OPTION
		and (not data.has("options") or data["options"].is_empty())
	):
		error_message = "缺少 options 的设置项 %s" % item_key
	if (
		error_message.is_empty()
		and data.has("platforms")
		and not _is_string_array(data["platforms"])
	):
		error_message = "platforms 无效的设置项 %s" % item_key
	return error_message


## 加载已保存的设置
func _load_saved() -> void:
	var load_path := save_path
	var load_error := _config.load(load_path)
	if load_error != OK and FileAccess.file_exists(save_path + ".bak"):
		load_path = save_path + ".bak"
		load_error = _config.load(load_path)
	if load_error != OK:
		_config.clear()
		_saved_loaded = true
		return  # 还没有保存文件 - 默认值就可以
	for category_id: String in _values.keys():
		for key: String in _values[category_id].keys():
			if _config.has_section_key(category_id, key):
				var item := _find_item(category_id, key)
				var validation := _validate_value(item, _config.get_value(category_id, key))
				if validation.valid:
					_values[category_id][key] = validation.value
				else:
					push_warning("KND_Settings: 忽略无效存档值 %s/%s" % [category_id, key])
	_saved_loaded = true
	if load_path != save_path:
		push_warning("KND_Settings: 已从备份配置恢复。")


func _find_item(category: String, key: String) -> KND_SettingItem:
	if not _categories.has(category):
		return null
	var cat: KND_SettingCategory = _categories[category]
	for item: KND_SettingItem in cat.items:
		if item.key == key:
			return item
	return null


func _validate_value(item: KND_SettingItem, value: Variant) -> Dictionary:
	var result := {"valid": false}
	if item == null:
		return result
	if item.type == KND_SettingItem.Type.SLIDER:
		if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			var numeric_value := float(value)
			if (
				is_finite(numeric_value)
				and numeric_value >= item.min_value
				and numeric_value <= item.max_value
			):
				result = {"valid": true, "value": numeric_value}
	elif item.type == KND_SettingItem.Type.TOGGLE:
		if value is bool:
			result = {"valid": true, "value": value}
	elif item.type == KND_SettingItem.Type.OPTION:
		if value is String and item.options.has(value):
			result = {"valid": true, "value": value}
	return result


func _is_string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is String:
			return false
	return true


func _save_config() -> bool:
	_rebuild_config()
	var temporary_path := save_path + ".tmp"
	var save_error := _config.save(temporary_path)
	if save_error != OK:
		return false
	return _replace_save_file(temporary_path)


func _rebuild_config() -> void:
	_config.clear()
	for category_id: String in _values:
		for key: String in _values[category_id]:
			_config.set_value(category_id, key, _values[category_id][key])


func _replace_save_file(temporary_path: String) -> bool:
	var backup_path := save_path + ".bak"
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temporary)
			return false
	var replace_error := DirAccess.rename_absolute(absolute_temporary, absolute_save)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	return true
