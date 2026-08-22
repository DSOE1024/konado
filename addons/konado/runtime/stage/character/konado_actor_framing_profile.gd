extends Resource
class_name KonadoActorFramingProfile

## Typed framing presets for one actor. A character can share a profile or
## override it when its artwork needs a different face/pivot alignment.

const BUILTIN_PRESET_IDS := [&"default", &"full", &"medium", &"close", &"extreme_close"]

@export var default_preset_id: StringName = &"default":
	set(value):
		if default_preset_id == value:
			return
		default_preset_id = value
		emit_changed()
@export var presets: Array[KonadoActorFramingPreset] = []:
	set(value):
		for preset in presets:
			if preset != null and preset.changed.is_connected(_on_preset_changed):
				preset.changed.disconnect(_on_preset_changed)
		presets = value
		for preset in presets:
			if preset != null and not preset.changed.is_connected(_on_preset_changed):
				preset.changed.connect(_on_preset_changed)
		emit_changed()


func has_preset(preset_id: StringName) -> bool:
	return get_preset(preset_id) != null


func get_preset(preset_id: StringName) -> KonadoActorFramingPreset:
	for preset in presets:
		if preset != null and preset.is_valid() and preset.preset_id == preset_id:
			return preset
	return null


func get_default_preset() -> KonadoActorFramingPreset:
	var configured := get_preset(default_preset_id)
	if configured != null:
		return configured
	return get_preset(&"default")


func get_default_preset_id() -> StringName:
	var preset := get_default_preset()
	return preset.preset_id if preset != null else &""


func get_preset_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for preset in presets:
		if preset != null and preset.is_valid() and not result.has(String(preset.preset_id)):
			result.append(String(preset.preset_id))
	result.sort()
	return result


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var preset_ids := {}
	for preset in presets:
		if preset == null or not preset.is_valid():
			errors.append("景别配置包含无效预设")
			continue
		if preset_ids.has(preset.preset_id):
			errors.append("景别预设 ID 重复：%s" % preset.preset_id)
			continue
		preset_ids[preset.preset_id] = true
	if default_preset_id.is_empty():
		errors.append("景别配置的默认预设 ID 不能为空")
	elif not preset_ids.has(default_preset_id):
		errors.append("景别配置缺少指定的默认预设：%s" % default_preset_id)
	return errors


func _on_preset_changed() -> void:
	emit_changed()


static func create_builtin() -> KonadoActorFramingProfile:
	var profile := KonadoActorFramingProfile.new()
	profile.presets = [
		_create_preset(&"default", 1.0, Vector2.ZERO, Vector2(0.5, 0.5)),
		_create_preset(&"full", 1.0, Vector2.ZERO, Vector2(0.5, 0.5)),
		_create_preset(&"medium", 1.3, Vector2.ZERO, Vector2(0.5, 0.38)),
		_create_preset(&"close", 1.65, Vector2.ZERO, Vector2(0.5, 0.32)),
		_create_preset(&"extreme_close", 2.1, Vector2.ZERO, Vector2(0.5, 0.28)),
	]
	return profile


static func _create_preset(
	preset_id: StringName, scale: float, offset: Vector2, pivot: Vector2
) -> KonadoActorFramingPreset:
	var preset := KonadoActorFramingPreset.new()
	preset.preset_id = preset_id
	preset.scale = scale
	preset.offset = offset
	preset.pivot = pivot
	return preset
