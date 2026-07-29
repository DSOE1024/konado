@tool
extends RefCounted
class_name KS_EditorLocale

## Small editor-facing locale adapter.
##
## Godot's editor language can differ from the operating-system locale. Konado
## editor UI therefore reads `interface/editor/editor_language` first and uses
## English as the fallback for every non-Chinese editor locale.


static func get_editor_locale() -> String:
	if Engine.is_editor_hint():
		var settings := EditorInterface.get_editor_settings()
		if settings != null:
			var locale := String(settings.get_setting("interface/editor/editor_language"))
			if not locale.is_empty():
				return locale
	return OS.get_locale()


static func is_chinese(locale: String = "") -> bool:
	var resolved_locale := locale if not locale.is_empty() else get_editor_locale()
	return resolved_locale.to_lower().begins_with("zh")


static func text(english: String, chinese: String, locale: String = "") -> String:
	return chinese if is_chinese(locale) else english
