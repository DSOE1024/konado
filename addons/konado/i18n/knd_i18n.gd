extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "zh_Hans"
const BUILTIN_LOCALES := ["zh_Hans", "zh_Hant", "en", "ja", "ko"]
const BUILTIN_TRANSLATION_PATHS := {
	"zh_Hans": "res://addons/konado/i18n/runtime.zh_Hans.tres",
	"zh_Hant": "res://addons/konado/i18n/runtime.zh_Hant.tres",
	"en": "res://addons/konado/i18n/runtime.en.tres",
	"ja": "res://addons/konado/i18n/runtime.ja.tres",
	"ko": "res://addons/konado/i18n/runtime.ko.tres",
}

const _SIMPLIFIED_CHINESE_ALIASES := [
	"zh", "zh_cn", "zh_sg", "zh_hans",
]
const _TRADITIONAL_CHINESE_ALIASES := [
	"tc", "zh_tw", "zh_hk", "zh_mo", "zh_hant",
]

var _locale := DEFAULT_LOCALE
var _settings_manager: Node
var _is_syncing_setting := false
var _warned_fallbacks := {}
var _dialogue_managers: Array[WeakRef] = []
var _builtin_translations := {}
var _translations_registered := false


func _ready() -> void:
	call_deferred("initialize")


func initialize(settings_manager: Node = null, system_locale: String = "") -> void:
	_register_builtin_translations()
	_settings_manager = settings_manager
	if _settings_manager == null:
		_settings_manager = get_tree().root.get_node_or_null("KND_Settings")
	var saved_locale := ""
	if _settings_manager != null:
		if _settings_manager.has_method("get_setting"):
			var saved_value: Variant = _settings_manager.call("get_setting", "display", "language")
			if saved_value != null:
				saved_locale = str(saved_value)
		if _settings_manager.has_signal("setting_changed"):
			var callback := Callable(self, "_on_setting_changed")
			if not _settings_manager.is_connected("setting_changed", callback):
				_settings_manager.connect("setting_changed", callback)

	var detected_locale := system_locale if not system_locale.is_empty() else OS.get_locale()
	var initial_locale := choose_initial_locale(saved_locale, detected_locale)
	set_locale(initial_locale, false)
	if not saved_locale.is_empty() and saved_locale != initial_locale:
		_persist_locale(initial_locale)


func choose_initial_locale(saved_locale: String, system_locale: String) -> String:
	if not saved_locale.strip_edges().is_empty():
		return normalize_locale(saved_locale)

	var normalized_system := normalize_locale(system_locale)
	if normalized_system in BUILTIN_LOCALES:
		return normalized_system
	var base_language := normalized_system.get_slice("_", 0)
	if base_language in BUILTIN_LOCALES:
		return base_language
	return DEFAULT_LOCALE


func set_locale(locale: String, persist: bool = true) -> void:
	var normalized := normalize_locale(locale)
	var changed := normalized != _locale
	_locale = normalized
	TranslationServer.set_locale(_locale)
	if persist:
		_persist_locale(_locale)
	if changed:
		locale_changed.emit(_locale)
		_reload_dialogue_managers()


func get_locale() -> String:
	return _locale


func get_builtin_translation(locale: String) -> Translation:
	var normalized := normalize_locale(locale)
	if _builtin_translations.has(normalized):
		return _builtin_translations[normalized]
	var path: String = BUILTIN_TRANSLATION_PATHS.get(normalized, "")
	if path.is_empty():
		return null
	var translation := ResourceLoader.load(path) as Translation
	if translation != null:
		_builtin_translations[normalized] = translation
	return translation


func normalize_locale(locale: String) -> String:
	var cleaned := locale.strip_edges().replace("-", "_")
	if cleaned.is_empty():
		return DEFAULT_LOCALE

	var alias := cleaned.to_lower()
	if alias in _SIMPLIFIED_CHINESE_ALIASES or _starts_with_alias(alias, _SIMPLIFIED_CHINESE_ALIASES):
		return "zh_Hans"
	if alias in _TRADITIONAL_CHINESE_ALIASES or _starts_with_alias(alias, _TRADITIONAL_CHINESE_ALIASES):
		return "zh_Hant"

	var parts := cleaned.split("_", false)
	if parts.is_empty():
		return DEFAULT_LOCALE
	var normalized := PackedStringArray([parts[0].to_lower()])
	for index in range(1, parts.size()):
		var part: String = parts[index]
		if part.length() == 4:
			normalized.append(part.left(1).to_upper() + part.substr(1).to_lower())
		else:
			normalized.append(part.to_upper())
	return "_".join(normalized)


func get_script_candidates(script_path: String, locale: String = "") -> PackedStringArray:
	var normalized := normalize_locale(locale if not locale.is_empty() else _locale)
	var base_path := _get_base_script_path(script_path)
	var extension := base_path.get_extension()
	var stem := base_path.trim_suffix("." + extension) if not extension.is_empty() else base_path
	var candidates := PackedStringArray()

	_append_unique(candidates, "%s.%s.%s" % [stem, normalized, extension])
	var language := normalized.get_slice("_", 0)
	if language != normalized:
		_append_unique(candidates, "%s.%s.%s" % [stem, language, extension])
	_append_unique(candidates, base_path)
	return candidates


func resolve_script_path(
	script_path: String,
	locale: String = "",
	warn_on_fallback: bool = true
) -> String:
	var candidates := get_script_candidates(script_path, locale)
	for index in range(candidates.size()):
		var candidate := candidates[index]
		if not FileAccess.file_exists(candidate):
			continue
		if index > 0 and warn_on_fallback:
			_warn_fallback_once(script_path, locale if not locale.is_empty() else _locale, candidate)
		return candidate
	push_error("KND_I18n: no script found for %s" % script_path)
	return ""


func load_localized_script(
	script_path: String,
	locale: String = "",
	warn_on_fallback: bool = true
) -> KND_Shot:
	var resolved_path := resolve_script_path(script_path, locale, warn_on_fallback)
	if resolved_path.is_empty():
		return null
	var shot: KND_Shot
	if ResourceLoader.exists(resolved_path):
		shot = ResourceLoader.load(resolved_path) as KND_Shot
	if shot == null and FileAccess.file_exists(resolved_path):
		var compiler := KS_Compiler.new()
		shot = compiler.compile_file(resolved_path)
	if shot == null:
		push_error("KND_I18n: failed to load localized script %s" % resolved_path)
	return shot


func register_dialogue_manager(manager: Node) -> void:
	if manager == null:
		return
	for manager_ref: WeakRef in _dialogue_managers:
		if manager_ref.get_ref() == manager:
			return
	_dialogue_managers.append(weakref(manager))


func unregister_dialogue_manager(manager: Node) -> void:
	for index in range(_dialogue_managers.size() - 1, -1, -1):
		var registered: Variant = _dialogue_managers[index].get_ref()
		if registered == null or registered == manager:
			_dialogue_managers.remove_at(index)


func choose_restore_node_id(
	previous_shot: KND_Shot,
	localized_shot: KND_Shot,
	previous_node_id: String
) -> String:
	if localized_shot == null:
		return ""
	if not previous_node_id.is_empty() and localized_shot.find_node(previous_node_id) != null:
		return previous_node_id

	var previous_index := -1
	if previous_shot != null:
		for index in range(previous_shot.dialogues.size()):
			if previous_shot.dialogues[index].node_id == previous_node_id:
				previous_index = index
				break
	if previous_index >= 0 and previous_index < localized_shot.dialogues.size():
		return localized_shot.dialogues[previous_index].node_id
	if not localized_shot.start_node_id.is_empty():
		return localized_shot.start_node_id
	if not localized_shot.dialogues.is_empty():
		return localized_shot.dialogues[0].node_id
	return ""


func _get_base_script_path(script_path: String) -> String:
	var extension := script_path.get_extension()
	if extension.is_empty():
		return script_path
	var without_extension := script_path.trim_suffix("." + extension)
	var suffix := without_extension.get_file().get_extension()
	if not _looks_like_locale_suffix(suffix):
		return script_path
	return without_extension.trim_suffix("." + suffix) + "." + extension


func _looks_like_locale_suffix(suffix: String) -> bool:
	if suffix.is_empty():
		return false
	var normalized := suffix.replace("-", "_")
	var parts := normalized.split("_", false)
	if parts.size() == 1:
		return parts[0].length() in [2, 3]
	return parts[0].length() in [2, 3] and parts[1].length() in [2, 3, 4]


func _starts_with_alias(locale: String, aliases: Array) -> bool:
	for alias: String in aliases:
		if alias == "zh":
			continue
		if locale.begins_with(alias + "_"):
			return true
	return false


func _append_unique(values: PackedStringArray, value: String) -> void:
	if value not in values:
		values.append(value)


func _get_settings_manager() -> Node:
	if _settings_manager == null and is_inside_tree():
		_settings_manager = get_tree().root.get_node_or_null("KND_Settings")
	return _settings_manager


func _persist_locale(locale: String) -> void:
	var manager := _get_settings_manager()
	if manager == null or not manager.has_method("set_setting") or _is_syncing_setting:
		return
	var current_value: Variant = null
	if manager.has_method("get_setting"):
		current_value = manager.call("get_setting", "display", "language")
	if current_value != null and str(current_value) == locale:
		return
	_is_syncing_setting = true
	manager.call("set_setting", "display", "language", locale)
	_is_syncing_setting = false


func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	if _is_syncing_setting or category != "display" or key != "language":
		return
	set_locale(str(value), false)


func _warn_fallback_once(script_path: String, requested_locale: String, resolved_path: String) -> void:
	var warning_key := "%s|%s|%s" % [script_path, requested_locale, resolved_path]
	if _warned_fallbacks.has(warning_key):
		return
	_warned_fallbacks[warning_key] = true
	push_warning(
		"KND_I18n: %s is unavailable for %s; using %s" % [
			script_path,
			normalize_locale(requested_locale),
			resolved_path,
		]
	)


func _reload_dialogue_managers() -> void:
	for index in range(_dialogue_managers.size() - 1, -1, -1):
		var manager: Variant = _dialogue_managers[index].get_ref()
		if manager == null:
			_dialogue_managers.remove_at(index)
			continue
		if manager.has_method("reload_localized_script"):
			manager.call("reload_localized_script", _locale)


func _register_builtin_translations() -> void:
	if _translations_registered:
		return
	for locale: String in BUILTIN_LOCALES:
		var translation := get_builtin_translation(locale)
		if translation != null:
			TranslationServer.add_translation(translation)
	_translations_registered = true
