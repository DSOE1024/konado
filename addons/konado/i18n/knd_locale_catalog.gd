extends RefCounted

const DEFAULT_LOCALE := "zh_Hans"
const BUILTIN_TRANSLATION_PATHS := {
	"zh_Hans": "res://addons/konado/i18n/runtime.zh_Hans.tres",
	"zh_Hant": "res://addons/konado/i18n/runtime.zh_Hant.tres",
	"en": "res://addons/konado/i18n/runtime.en.tres",
	"ja": "res://addons/konado/i18n/runtime.ja.tres",
	"ko": "res://addons/konado/i18n/runtime.ko.tres",
}

const _SIMPLIFIED_CHINESE_ALIASES := [
	"zh",
	"zh_cn",
	"zh_sg",
	"zh_hans",
]
const _TRADITIONAL_CHINESE_ALIASES := [
	"tc",
	"zh_tw",
	"zh_hk",
	"zh_mo",
	"zh_hant",
]

var _translations := {}


func normalize_locale(locale: String) -> String:
	var cleaned := locale.strip_edges().replace("-", "_")
	if cleaned.is_empty():
		return DEFAULT_LOCALE

	var alias := cleaned.to_lower()
	if _matches_alias(alias, _SIMPLIFIED_CHINESE_ALIASES):
		return "zh_Hans"
	if _matches_alias(alias, _TRADITIONAL_CHINESE_ALIASES):
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


func choose_initial_locale(saved_locale: String, system_locale: String) -> String:
	if not saved_locale.strip_edges().is_empty():
		return normalize_locale(saved_locale)

	var normalized_system := normalize_locale(system_locale)
	if BUILTIN_TRANSLATION_PATHS.has(normalized_system):
		return normalized_system
	var base_language := normalized_system.get_slice("_", 0)
	if BUILTIN_TRANSLATION_PATHS.has(base_language):
		return base_language
	return DEFAULT_LOCALE


func get_builtin_locales() -> PackedStringArray:
	return PackedStringArray(BUILTIN_TRANSLATION_PATHS.keys())


func get_available_locales() -> PackedStringArray:
	var locales := get_builtin_locales()
	for locale: String in _translations:
		if locale not in locales:
			locales.append(locale)
	return locales


func get_translation(locale: String) -> Translation:
	var normalized := normalize_locale(locale)
	if _translations.has(normalized):
		return _translations[normalized]
	var path: String = BUILTIN_TRANSLATION_PATHS.get(normalized, "")
	if path.is_empty():
		return null
	var translation := ResourceLoader.load(path, "Translation") as Translation
	if translation == null:
		push_error("KND_I18n: failed to load translation %s" % path)
		return null
	_translations[normalized] = translation
	return translation


func get_loaded_translations() -> Array[Translation]:
	var loaded: Array[Translation] = []
	for translation: Translation in _translations.values():
		loaded.append(translation)
	return loaded


func cache_translation(locale: String, translation: Translation) -> String:
	var normalized := normalize_locale(locale)
	_translations[normalized] = translation
	return normalized


func remove_cached_translation(locale: String) -> void:
	_translations.erase(normalize_locale(locale))


func _matches_alias(locale: String, aliases: Array) -> bool:
	for alias: String in aliases:
		if locale == alias:
			return true
		if alias != "zh" and locale.begins_with(alias + "_"):
			return true
	return false
