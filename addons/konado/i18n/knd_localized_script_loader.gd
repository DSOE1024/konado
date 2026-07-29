extends RefCounted

var _locale_catalog: RefCounted
var _warned_fallbacks := {}


func _init(locale_catalog: RefCounted) -> void:
	_locale_catalog = locale_catalog


func get_script_candidates(script_path: String, locale: String) -> PackedStringArray:
	var normalized: String = _locale_catalog.normalize_locale(locale)
	var base_path := get_base_script_path(script_path)
	var extension := base_path.get_extension()
	var stem := base_path.trim_suffix("." + extension) if not extension.is_empty() else base_path
	var candidates := PackedStringArray()

	_append_localized_candidate(candidates, stem, normalized, extension)
	var language := normalized.get_slice("_", 0)
	if language != normalized:
		_append_localized_candidate(candidates, stem, language, extension)
	_append_unique(candidates, base_path)
	return candidates


func resolve_script_path(
	script_path: String, locale: String, warn_on_fallback: bool = true
) -> String:
	if script_path.strip_edges().is_empty():
		push_error("KND_I18n: script path is empty")
		return ""

	var candidates := get_script_candidates(script_path, locale)
	for index in range(candidates.size()):
		var candidate := candidates[index]
		if not _resource_exists(candidate):
			continue
		if index > 0 and warn_on_fallback:
			_warn_fallback_once(script_path, locale, candidate)
		return candidate
	push_error("KND_I18n: no script found for %s" % script_path)
	return ""


func load_localized_script(
	script_path: String, locale: String, warn_on_fallback: bool = true
) -> KND_Shot:
	var resolved_path := resolve_script_path(script_path, locale, warn_on_fallback)
	if resolved_path.is_empty():
		return null

	var shot: KND_Shot
	if ResourceLoader.exists(resolved_path):
		shot = ResourceLoader.load(resolved_path) as KND_Shot
	if shot == null and FileAccess.file_exists(resolved_path):
		shot = KS_Compiler.new().compile_file(resolved_path)
	if shot == null:
		push_error("KND_I18n: failed to load localized script %s" % resolved_path)
	return shot


func choose_restore_node_id(
	previous_shot: KND_Shot, localized_shot: KND_Shot, previous_node_id: String
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


func get_base_script_path(script_path: String) -> String:
	var extension := script_path.get_extension()
	if extension.is_empty():
		return script_path
	var without_extension := script_path.trim_suffix("." + extension)
	var suffix := without_extension.get_file().get_extension()
	if not _looks_like_locale_suffix(suffix):
		return script_path
	return without_extension.trim_suffix("." + suffix) + "." + extension


func get_script_locale(script_path: String) -> String:
	var base_path := get_base_script_path(script_path)
	if base_path == script_path:
		return ""
	var extension := script_path.get_extension()
	var without_extension := script_path.trim_suffix("." + extension)
	var suffix := without_extension.get_file().get_extension()
	return _locale_catalog.normalize_locale(suffix)


func _looks_like_locale_suffix(suffix: String) -> bool:
	if suffix.is_empty():
		return false
	var parts := suffix.replace("-", "_").split("_", false)
	if parts.size() == 1:
		return parts[0].length() == 2 and _is_ascii_alpha(parts[0])
	if parts.size() > 3 or parts[0].length() not in [2, 3] or not _is_ascii_alpha(parts[0]):
		return false
	for index in range(1, parts.size()):
		var part: String = parts[index]
		if part.length() == 2 and _is_ascii_alpha(part):
			continue
		if part.length() == 4 and _is_ascii_alpha(part):
			continue
		if part.length() == 3 and _is_ascii_numeric(part):
			continue
		return false
	return true


func _is_ascii_alpha(value: String) -> bool:
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if not (
			(codepoint >= "A".unicode_at(0) and codepoint <= "Z".unicode_at(0))
			or (codepoint >= "a".unicode_at(0) and codepoint <= "z".unicode_at(0))
		):
			return false
	return not value.is_empty()


func _is_ascii_numeric(value: String) -> bool:
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint < "0".unicode_at(0) or codepoint > "9".unicode_at(0):
			return false
	return not value.is_empty()


func _append_localized_candidate(
	candidates: PackedStringArray, stem: String, locale: String, extension: String
) -> void:
	var candidate := "%s.%s" % [stem, locale]
	if not extension.is_empty():
		candidate += "." + extension
	_append_unique(candidates, candidate)


func _append_unique(values: PackedStringArray, value: String) -> void:
	if value not in values:
		values.append(value)


func _resource_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func _warn_fallback_once(
	script_path: String, requested_locale: String, resolved_path: String
) -> void:
	var normalized: String = _locale_catalog.normalize_locale(requested_locale)
	var warning_key := "%s|%s|%s" % [script_path, normalized, resolved_path]
	if _warned_fallbacks.has(warning_key):
		return
	_warned_fallbacks[warning_key] = true
	push_warning(
		"KND_I18n: %s is unavailable for %s; using %s" % [script_path, normalized, resolved_path]
	)
