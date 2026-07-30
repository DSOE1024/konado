@tool
extends RefCounted
class_name KS_LocalizationValidator

## Validates structural parity between a default script and one localized variant.

const MAX_ALIGNMENT_CELLS := 1_000_000


static func compare(
	default_source: String,
	localized_source: String,
	default_path: String = "",
	localized_path: String = "",
	locale: String = "",
) -> Dictionary:
	var default_entries := _collect_entries(default_source)
	var localized_entries := _collect_entries(localized_source)
	var rows: Array[Dictionary] = []
	var diagnostics: Array[Dictionary] = []
	var aligned_entries := _align_entries(default_entries, localized_entries)
	for index: int in aligned_entries.size():
		var pair: Dictionary = aligned_entries[index]
		var base: Dictionary = pair["default"]
		var translated: Dictionary = pair["localized"]
		var status := "matched"
		if base.is_empty():
			status = "extra"
		elif translated.is_empty():
			status = "missing"
		elif base.get("signature") != translated.get("signature"):
			status = "structure_changed"
		elif bool(base.get("translatable", false)) and base.get("text") == translated.get("text"):
			status = "untranslated"
		(
			rows
			. append(
				{
					"index": index,
					"status": status,
					"default": base,
					"localized": translated,
				}
			)
		)
		if status in ["missing", "extra", "structure_changed"]:
			var line := int(translated.get("line", base.get("line", 1)))
			var line_source := localized_source if not translated.is_empty() else default_source
			(
				diagnostics
				. append(
					{
						"severity": "error",
						"line": line,
						"column": 1,
						"end_line": line,
						"end_column": _line_end_column(line_source, line),
						"path": localized_path,
						"code": "locale_%s" % status,
						"arguments": [line],
						"actions": [],
						"message": _status_message(status, line, locale),
					}
				)
			)
		elif status == "untranslated":
			(
				diagnostics
				. append(
					{
						"severity": "warning",
						"line": int(translated.get("line", 1)),
						"column": 1,
						"end_line": int(translated.get("line", 1)),
						"end_column":
						_line_end_column(localized_source, int(translated.get("line", 1))),
						"path": localized_path,
						"code": "locale_untranslated",
						"arguments": [],
						"actions": [],
						"message":
						(
							KS_EditorLocale
							. text(
								"Text may be untranslated.",
								"文本可能尚未翻译。",
								locale,
							)
						),
					}
				)
			)
	return {
		"default_path": default_path,
		"localized_path": localized_path,
		"rows": rows,
		"diagnostics": diagnostics,
		"compatible":
		diagnostics.all(func(item: Dictionary) -> bool: return item["severity"] != "error"),
	}


static func _line_end_column(source: String, line_number: int) -> int:
	var lines := source.split("\n")
	var index := line_number - 1
	if index < 0 or index >= lines.size():
		return 2
	return maxi(2, String(lines[index]).length() + 1)


static func _align_entries(
	default_entries: Array[Dictionary],
	localized_entries: Array[Dictionary],
) -> Array[Dictionary]:
	var default_count := default_entries.size()
	var localized_count := localized_entries.size()
	if (default_count + 1) * (localized_count + 1) > MAX_ALIGNMENT_CELLS:
		return _align_entries_by_position(default_entries, localized_entries)
	var lengths: Array[PackedInt32Array] = []
	for _row: int in default_count + 1:
		lengths.append(PackedInt32Array())
		lengths[-1].resize(localized_count + 1)
	for default_index: int in range(default_count - 1, -1, -1):
		for localized_index: int in range(localized_count - 1, -1, -1):
			if (
				default_entries[default_index].get("signature")
				== localized_entries[localized_index].get("signature")
			):
				lengths[default_index][localized_index] = (
					lengths[default_index + 1][localized_index + 1] + 1
				)
			else:
				lengths[default_index][localized_index] = maxi(
					lengths[default_index + 1][localized_index],
					lengths[default_index][localized_index + 1],
				)
	var aligned: Array[Dictionary] = []
	var default_index := 0
	var localized_index := 0
	while default_index < default_count and localized_index < localized_count:
		var base: Dictionary = default_entries[default_index]
		var translated: Dictionary = localized_entries[localized_index]
		if base.get("signature") == translated.get("signature"):
			aligned.append({"default": base, "localized": translated})
			default_index += 1
			localized_index += 1
		elif (
			lengths[default_index + 1][localized_index]
			>= lengths[default_index][localized_index + 1]
		):
			aligned.append({"default": base, "localized": {}})
			default_index += 1
		else:
			aligned.append({"default": {}, "localized": translated})
			localized_index += 1
	while default_index < default_count:
		aligned.append({"default": default_entries[default_index], "localized": {}})
		default_index += 1
	while localized_index < localized_count:
		aligned.append({"default": {}, "localized": localized_entries[localized_index]})
		localized_index += 1
	return aligned


static func _align_entries_by_position(
	default_entries: Array[Dictionary],
	localized_entries: Array[Dictionary],
) -> Array[Dictionary]:
	var aligned: Array[Dictionary] = []
	for index: int in maxi(default_entries.size(), localized_entries.size()):
		(
			aligned
			. append(
				{
					"default": default_entries[index] if index < default_entries.size() else {},
					"localized":
					localized_entries[index] if index < localized_entries.size() else {},
				}
			)
		)
	return aligned


static func _collect_entries(source: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var inside_screen_text := false
	var lines := source.split("\n")
	for line_index: int in lines.size():
		var line := String(lines[line_index])
		var tokens := KS_SymbolIndex.get_line_tokens(line)
		if tokens.is_empty():
			continue
		if inside_screen_text and tokens.size() == 1 and tokens[0].get("text") == "}":
			inside_screen_text = false
			entries.append(_entry(line_index + 1, "}", "", false))
			continue
		if inside_screen_text and bool(tokens[0].get("quoted", false)):
			entries.append(_entry(line_index + 1, "screen_text", tokens[0]["text"], true))
			continue
		var command := String(tokens[0]["text"])
		if command == "screentext":
			inside_screen_text = true
			entries.append(_entry(line_index + 1, "screentext {", "", false))
		elif bool(tokens[0].get("quoted", false)):
			var voice := String(tokens[2]["text"]) if tokens.size() >= 3 else ""
			(
				entries
				. append(
					_entry(
						line_index + 1,
						"dialogue|%s|%s" % [tokens[0]["text"], voice],
						String(tokens[1]["text"]) if tokens.size() >= 2 else "",
						true,
					)
				)
			)
		elif command == "choice":
			var target := ""
			for token_index: int in tokens.size():
				if String(tokens[token_index]["text"]) == "->" and token_index + 1 < tokens.size():
					target = String(tokens[token_index + 1]["text"])
					break
			(
				entries
				. append(
					_entry(
						line_index + 1,
						"choice|%s" % target,
						String(tokens[1]["text"]) if tokens.size() >= 2 else "",
						true,
					)
				)
			)
		else:
			var structural_tokens := PackedStringArray()
			for token: Dictionary in tokens:
				structural_tokens.append(String(token["text"]))
			entries.append(_entry(line_index + 1, " ".join(structural_tokens), "", false))
	return entries


static func _entry(line: int, signature: String, text: String, translatable: bool) -> Dictionary:
	return {
		"line": line,
		"signature": signature,
		"text": text,
		"translatable": translatable,
	}


static func _status_message(status: String, line: int, locale: String) -> String:
	var messages := {
		"missing":
		(
			KS_EditorLocale
			. text(
				"Localized script is missing the item corresponding to line %d." % line,
				"本地化剧本缺少与第 %d 行对应的内容。" % line,
				locale,
			)
		),
		"extra":
		(
			KS_EditorLocale
			. text(
				"Localized script contains an extra structural item on line %d." % line,
				"本地化剧本第 %d 行存在额外结构。" % line,
				locale,
			)
		),
		"structure_changed":
		(
			KS_EditorLocale
			. text(
				"Localized script structure differs on line %d." % line,
				"本地化剧本第 %d 行的结构与默认剧本不同。" % line,
				locale,
			)
		),
	}
	return String(messages.get(status, status))
