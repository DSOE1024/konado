extends Node

signal initialized(locale: String)
signal locale_changed(locale: String)

const LOCALE_CATALOG := preload("res://addons/konado/i18n/knd_locale_catalog.gd")
const SCRIPT_LOADER := preload("res://addons/konado/i18n/knd_localized_script_loader.gd")

const SETTINGS_CATEGORY := "display"
const LANGUAGE_SETTING := "language"

var _locale_catalog := LOCALE_CATALOG.new()
var _script_loader := SCRIPT_LOADER.new(_locale_catalog)
var _locale: String = LOCALE_CATALOG.DEFAULT_LOCALE
var _settings_manager: Node
var _is_syncing_setting := false
var _dialogue_managers: Array[WeakRef] = []
var _registered_translations := {}
var _initialized := false


func _ready() -> void:
	call_deferred("_initialize_from_tree")


func _exit_tree() -> void:
	_bind_settings_manager(null)
	for translation: Translation in _registered_translations.values():
		TranslationServer.remove_translation(translation)
	_registered_translations.clear()


func initialize(settings_manager: Node = null, system_locale: String = "") -> void:
	var manager := settings_manager
	if manager == null and is_inside_tree():
		manager = get_tree().root.get_node_or_null("KND_Settings")
	_bind_settings_manager(manager)
	_register_builtin_translations()

	var saved_locale := _read_saved_locale()
	var detected_locale := system_locale if not system_locale.is_empty() else OS.get_locale()
	var initial_locale: String = _locale_catalog.choose_initial_locale(
		saved_locale, detected_locale
	)
	var first_initialization := not _initialized
	_initialized = true
	_apply_locale(initial_locale, false, first_initialization)
	if not saved_locale.is_empty() and saved_locale != initial_locale:
		_persist_locale(initial_locale)
	if first_initialization:
		initialized.emit(_locale)


func is_initialized() -> bool:
	return _initialized


func set_locale(locale: String, persist: bool = true) -> bool:
	_register_builtin_translations()
	var normalized: String = _locale_catalog.normalize_locale(locale)
	_apply_locale(normalized, persist)
	return true


func get_locale() -> String:
	return _locale


func get_available_locales() -> PackedStringArray:
	return _locale_catalog.get_available_locales()


func choose_initial_locale(saved_locale: String, system_locale: String) -> String:
	return _locale_catalog.choose_initial_locale(saved_locale, system_locale)


func normalize_locale(locale: String) -> String:
	return _locale_catalog.normalize_locale(locale)


func get_builtin_translation(locale: String) -> Translation:
	return _locale_catalog.get_translation(locale)


func register_translation(translation: Translation) -> bool:
	if translation == null or translation.locale.strip_edges().is_empty():
		push_error("KND_I18n: translation requires a locale")
		return false
	var normalized: String = _locale_catalog.normalize_locale(translation.locale)
	if _registered_translations.has(normalized):
		TranslationServer.remove_translation(_registered_translations[normalized])
	translation.locale = normalized
	_locale_catalog.cache_translation(normalized, translation)
	TranslationServer.add_translation(translation)
	_registered_translations[normalized] = translation
	return true


func unregister_translation(locale: String) -> bool:
	var normalized: String = _locale_catalog.normalize_locale(locale)
	if not _registered_translations.has(normalized):
		return false
	TranslationServer.remove_translation(_registered_translations[normalized])
	_registered_translations.erase(normalized)
	_locale_catalog.remove_cached_translation(normalized)
	if normalized in _locale_catalog.get_builtin_locales():
		var builtin: Translation = _locale_catalog.get_translation(normalized)
		if builtin != null:
			TranslationServer.add_translation(builtin)
			_registered_translations[normalized] = builtin
	return true


func get_script_candidates(script_path: String, locale: String = "") -> PackedStringArray:
	return _script_loader.get_script_candidates(script_path, _resolve_locale(locale))


func resolve_script_path(
	script_path: String, locale: String = "", warn_on_fallback: bool = true
) -> String:
	return _script_loader.resolve_script_path(
		script_path, _resolve_locale(locale), warn_on_fallback
	)


func load_localized_script(
	script_path: String, locale: String = "", warn_on_fallback: bool = true
) -> KND_Shot:
	return _script_loader.load_localized_script(
		script_path, _resolve_locale(locale), warn_on_fallback
	)


func choose_restore_node_id(
	previous_shot: KND_Shot, localized_shot: KND_Shot, previous_node_id: String
) -> String:
	return _script_loader.choose_restore_node_id(previous_shot, localized_shot, previous_node_id)


func register_dialogue_manager(manager: Node) -> void:
	if manager == null or not is_instance_valid(manager):
		return
	_prune_dialogue_managers()
	for manager_ref: WeakRef in _dialogue_managers:
		if manager_ref.get_ref() == manager:
			return
	_dialogue_managers.append(weakref(manager))


func unregister_dialogue_manager(manager: Node) -> void:
	for index in range(_dialogue_managers.size() - 1, -1, -1):
		var registered: Variant = _dialogue_managers[index].get_ref()
		if registered == null or registered == manager:
			_dialogue_managers.remove_at(index)


func _initialize_from_tree() -> void:
	if not _initialized:
		initialize()


func _apply_locale(locale: String, persist: bool, force_notify: bool = false) -> void:
	var changed := locale != _locale
	_locale = locale
	if TranslationServer.get_locale() != _locale:
		TranslationServer.set_locale(_locale)
	if persist:
		_persist_locale(_locale)
	if changed or force_notify:
		locale_changed.emit(_locale)
		_reload_dialogue_managers()


func _resolve_locale(locale: String) -> String:
	return _locale if locale.is_empty() else _locale_catalog.normalize_locale(locale)


func _bind_settings_manager(manager: Node) -> void:
	var callback := Callable(self, "_on_setting_changed")
	if (
		_settings_manager != null
		and is_instance_valid(_settings_manager)
		and _settings_manager.has_signal("setting_changed")
		and _settings_manager.is_connected("setting_changed", callback)
	):
		_settings_manager.disconnect("setting_changed", callback)

	_settings_manager = manager if is_instance_valid(manager) else null
	if (
		_settings_manager != null
		and _settings_manager.has_signal("setting_changed")
		and not _settings_manager.is_connected("setting_changed", callback)
	):
		_settings_manager.connect("setting_changed", callback)


func _read_saved_locale() -> String:
	if _settings_manager == null or not _settings_manager.has_method("get_setting"):
		return ""
	var saved_value: Variant = _settings_manager.call(
		"get_setting", SETTINGS_CATEGORY, LANGUAGE_SETTING
	)
	return "" if saved_value == null else str(saved_value)


func _persist_locale(locale: String) -> void:
	if (
		_settings_manager == null
		or not _settings_manager.has_method("set_setting")
		or _is_syncing_setting
	):
		return
	if _read_saved_locale() == locale:
		return
	_is_syncing_setting = true
	_settings_manager.call("set_setting", SETTINGS_CATEGORY, LANGUAGE_SETTING, locale)
	_is_syncing_setting = false


func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	if _is_syncing_setting or category != SETTINGS_CATEGORY or key != LANGUAGE_SETTING:
		return
	var normalized: String = _locale_catalog.normalize_locale(str(value))
	_apply_locale(normalized, false)
	if str(value) != normalized:
		_persist_locale(normalized)


func _register_builtin_translations() -> void:
	for locale: String in _locale_catalog.get_builtin_locales():
		if _registered_translations.has(locale):
			continue
		var translation: Translation = _locale_catalog.get_translation(locale)
		if translation == null:
			continue
		TranslationServer.add_translation(translation)
		_registered_translations[locale] = translation


func _reload_dialogue_managers() -> void:
	_prune_dialogue_managers()
	for manager_ref: WeakRef in _dialogue_managers:
		var manager: Variant = manager_ref.get_ref()
		if manager.has_method("reload_localized_script"):
			manager.call("reload_localized_script", _locale)


func _prune_dialogue_managers() -> void:
	for index in range(_dialogue_managers.size() - 1, -1, -1):
		if _dialogue_managers[index].get_ref() == null:
			_dialogue_managers.remove_at(index)
