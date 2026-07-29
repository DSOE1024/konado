@tool
extends RefCounted
class_name KS_ProjectIndex

## Cached, side-effect-free project symbol index for KonadoScript language services.
##
## Textual `.tres` and `.tscn` files are parsed without loading or instantiating
## project scenes. Each symbol keeps its declaration file, source line and final
## resource target so completion, diagnostics and navigation share one source of
## truth without executing user tool scripts while the editor is typing.

const RESOURCE_SCHEMAS: Dictionary = {
	"actors": {"name": "chara_name", "target": "character_scene"},
	"backgrounds": {"name": "background_name", "target": "background_scene"},
	"bgms": {"name": "bgm_name", "target": "bgm"},
	"sfx": {"name": "se_name", "target": "se"},
	"voices": {"name": "voice_name", "target": "voice"},
}
const SCOPED_PROPERTY_SCHEMAS: Dictionary = {
	"states": "status_name",
	"cameras": "camera_setup",
}
const ANIMATION_PATTERN := '"name"\\s*:\\s*&?"([^"]+)"'
const MOTION_PATTERN := '(?m)^\\s*resource_name\\s*=\\s*"([^"]+)"'
const EXT_RESOURCE_HEADER_PATTERN := "(?m)^\\[ext_resource[^\\]]*\\]$"
const BLOCK_HEADER_PATTERN := "(?m)^\\[(?:sub_resource|resource|node)[^\\]]*\\]$"
const SCANNED_EXTENSIONS := ["tres", "tscn"]
const IGNORED_DIRECTORIES := [
	"node_modules",
	"build",
	"dist",
]
const MAX_TEXT_RESOURCE_BYTES := 8 * 1024 * 1024
const DUPLICATE_GLOBAL_KINDS := ["actors", "backgrounds", "bgms", "sfx", "voices"]

static var _shared_instance: KS_ProjectIndex

var _symbols := {}
var _definitions := {}
var _file_cache := {}
var _seen_paths := {}
var _dirty := true
var _filesystem_connected := false


static func shared() -> KS_ProjectIndex:
	if _shared_instance == null:
		_shared_instance = KS_ProjectIndex.new()
	return _shared_instance


func get_values(kind: String) -> PackedStringArray:
	_ensure_index()
	return PackedStringArray(_symbols.get(kind, PackedStringArray()))


func get_definitions(kind: String, name: String = "") -> Array[Dictionary]:
	_ensure_index()
	var results: Array[Dictionary] = []
	var by_name: Dictionary = _definitions.get(kind, {})
	if not name.is_empty():
		for definition: Dictionary in by_name.get(name, []):
			results.append(definition.duplicate(true))
		return results
	for symbol_name: String in by_name:
		for definition: Dictionary in by_name[symbol_name]:
			results.append(definition.duplicate(true))
	return results


func get_definition(kind: String, name: String) -> Dictionary:
	var definitions := get_definitions(kind, name)
	if definitions.size() != 1:
		return {}
	return definitions[0]


func get_navigation_targets(kind: String, name: String) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var seen := {}
	for definition: Dictionary in get_definitions(kind, name):
		var target_path := String(definition.get("target_path", ""))
		if target_path.is_empty():
			target_path = String(definition.get("owner_path", ""))
		if target_path.is_empty() or seen.has(target_path):
			continue
		seen[target_path] = true
		var target := definition.duplicate(true)
		target["path"] = target_path
		targets.append(target)
	return targets


func get_duplicate_definitions() -> Array[Dictionary]:
	_ensure_index()
	var duplicates: Array[Dictionary] = []
	for kind: String in DUPLICATE_GLOBAL_KINDS:
		var by_name: Dictionary = _definitions.get(kind, {})
		for name: String in by_name:
			var definitions: Array = by_name[name]
			if definitions.size() > 1:
				(
					duplicates
					. append(
						{
							"kind": kind,
							"name": name,
							"definitions": definitions.duplicate(true),
						}
					)
				)
	return duplicates


func get_actor_scoped_values(actor_name: String, kind: String) -> PackedStringArray:
	_ensure_index()
	if kind not in ["states", "motions"]:
		return PackedStringArray()
	var actor_definitions := get_definitions("actors", actor_name)
	var owner_paths := {}
	for actor_definition: Dictionary in actor_definitions:
		var actor_scene := String(actor_definition.get("target_path", ""))
		if not actor_scene.is_empty():
			owner_paths[actor_scene] = true
		var motion_scene := String(actor_definition.get("motion_path", ""))
		if not motion_scene.is_empty():
			owner_paths[motion_scene] = true
	if kind == "motions" and owner_paths.is_empty():
		return get_values(kind)
	var values := PackedStringArray()
	for definition: Dictionary in get_definitions(kind):
		if owner_paths.has(String(definition.get("owner_path", ""))):
			var value := String(definition.get("name", ""))
			if not value.is_empty() and not values.has(value):
				values.append(value)
	if kind == "motions" and values.is_empty():
		return get_values(kind)
	values.sort()
	return values


func get_actor_scoped_targets(
	actor_name: String,
	kind: String,
	name: String,
) -> Array[Dictionary]:
	if kind not in ["states", "motions"]:
		return get_navigation_targets(kind, name)
	var actor_definitions := get_definitions("actors", actor_name)
	var owner_paths := {}
	for actor_definition: Dictionary in actor_definitions:
		var actor_scene := String(actor_definition.get("target_path", ""))
		var motion_scene := String(actor_definition.get("motion_path", ""))
		if kind == "states" and not actor_scene.is_empty():
			owner_paths[actor_scene] = true
		if kind == "motions" and not motion_scene.is_empty():
			owner_paths[motion_scene] = true
	var targets: Array[Dictionary] = []
	var seen_paths := {}
	for definition: Dictionary in get_definitions(kind, name):
		if not owner_paths.is_empty() and not owner_paths.has(definition.get("owner_path")):
			continue
		var target := definition.duplicate(true)
		var target_path := String(definition.get("target_path", definition.get("owner_path", "")))
		if target_path.is_empty() or seen_paths.has(target_path):
			continue
		seen_paths[target_path] = true
		target["path"] = target_path
		targets.append(target)
	if kind == "motions" and targets.is_empty() and owner_paths.is_empty():
		return get_navigation_targets(kind, name)
	return targets


func invalidate() -> void:
	_dirty = true


func _ensure_index() -> void:
	_connect_filesystem_signal()
	if not _dirty:
		return
	_symbols = {}
	_definitions = {}
	for kind: String in [
		"actors",
		"backgrounds",
		"bgms",
		"sfx",
		"voices",
		"states",
		"motions",
		"cameras",
		"scripts",
	]:
		_symbols[kind] = PackedStringArray()
		_definitions[kind] = {}
	_seen_paths.clear()
	_scan_directory("res://")
	for cached_path: String in _file_cache.keys():
		if not _seen_paths.has(cached_path):
			_file_cache.erase(cached_path)
	for kind: String in _symbols:
		var values: PackedStringArray = _symbols[kind]
		values.sort()
	_dirty = false


func _connect_filesystem_signal() -> void:
	if _filesystem_connected or not Engine.is_editor_hint():
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return
	var callback := Callable(self, "invalidate")
	if not filesystem.filesystem_changed.is_connected(callback):
		filesystem.filesystem_changed.connect(callback)
	var paths_callback := Callable(self, "_invalidate_paths")
	for signal_name: StringName in [&"resources_reimported", &"resources_reload"]:
		if (
			filesystem.has_signal(signal_name)
			and not filesystem.is_connected(signal_name, paths_callback)
		):
			filesystem.connect(signal_name, paths_callback)
	_filesystem_connected = true


func _invalidate_paths(paths: PackedStringArray) -> void:
	for path: String in paths:
		_file_cache.erase(path)
	_dirty = true


func _scan_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var entry_path := path.path_join(entry)
		if directory.current_is_dir():
			if entry not in IGNORED_DIRECTORIES and not directory.is_link(entry):
				_scan_directory(entry_path)
		else:
			_scan_file(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _scan_file(path: String) -> void:
	var extension := path.get_extension().to_lower()
	if extension == "ks":
		_seen_paths[path] = true
		_merge_file_definitions(
			{
				"scripts":
				[
					_make_definition("scripts", path, path, 1, path),
				]
			}
		)
		return
	if not SCANNED_EXTENSIONS.has(extension):
		return
	_seen_paths[path] = true
	var modified_time := FileAccess.get_modified_time(path)
	var file_size := FileAccess.get_size(path)
	var cached: Dictionary = _file_cache.get(path, {})
	if cached.get("modified_time") == modified_time and cached.get("file_size") == file_size:
		_merge_file_definitions(cached.get("definitions", {}))
		return
	if file_size > MAX_TEXT_RESOURCE_BYTES:
		_file_cache[path] = {
			"modified_time": modified_time,
			"file_size": file_size,
			"definitions": {},
		}
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var source := file.get_as_text()
	var file_definitions := _parse_text_resource(path, source, extension)
	_file_cache[path] = {
		"modified_time": modified_time,
		"file_size": file_size,
		"definitions": file_definitions,
	}
	_merge_file_definitions(file_definitions)


func _parse_text_resource(path: String, source: String, extension: String) -> Dictionary:
	var definitions := {}
	var external_resources := _collect_external_resources(source)
	for block: Dictionary in _collect_blocks(source):
		var block_source := String(block["source"])
		for kind: String in RESOURCE_SCHEMAS:
			var schema: Dictionary = RESOURCE_SCHEMAS[kind]
			var name_match := _find_property(block_source, String(schema["name"]))
			if name_match.is_empty():
				continue
			var target_path := _resolve_property_target(
				block_source,
				String(schema["target"]),
				external_resources,
			)
			var definition := _make_definition(
				kind,
				String(name_match["value"]),
				path,
				_line_at(source, int(block["start"]) + int(name_match["start"])),
				target_path,
			)
			if kind == "actors":
				definition["motion_path"] = _resolve_property_target(
					block_source,
					"actor_motion_layer",
					external_resources,
				)
			_append_definition(definitions, definition)
		for kind: String in SCOPED_PROPERTY_SCHEMAS:
			var name_match := _find_property(
				block_source,
				String(SCOPED_PROPERTY_SCHEMAS[kind]),
			)
			if name_match.is_empty():
				continue
			_append_definition(
				definitions,
				_make_definition(
					kind,
					String(name_match["value"]),
					path,
					_line_at(source, int(block["start"]) + int(name_match["start"])),
					path,
				),
			)
	if extension == "tscn":
		_collect_pattern_definitions(definitions, source, path, "states", ANIMATION_PATTERN)
		_collect_pattern_definitions(definitions, source, path, "motions", MOTION_PATTERN)
	return definitions


func _collect_external_resources(source: String) -> Dictionary:
	var resources := {}
	var regex := RegEx.new()
	if regex.compile(EXT_RESOURCE_HEADER_PATTERN) != OK:
		return resources
	for match_result: RegExMatch in regex.search_all(source):
		var header := match_result.get_string()
		var resource_id := _get_header_attribute(header, "id")
		var resource_path := _get_header_attribute(header, "path")
		if not resource_id.is_empty() and not resource_path.is_empty():
			resources[resource_id] = resource_path
	return resources


func _collect_blocks(source: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var regex := RegEx.new()
	if regex.compile(BLOCK_HEADER_PATTERN) != OK:
		return blocks
	var headers := regex.search_all(source)
	for index: int in headers.size():
		var content_start := headers[index].get_end()
		var content_end := source.length()
		if index + 1 < headers.size():
			content_end = headers[index + 1].get_start()
		(
			blocks
			. append(
				{
					"start": content_start,
					"source": source.substr(content_start, content_end - content_start),
				}
			)
		)
	return blocks


func _get_header_attribute(header: String, attribute: String) -> String:
	var regex := RegEx.new()
	if regex.compile('(?:^|\\s)%s="([^"]+)"' % attribute) != OK:
		return ""
	var match_result := regex.search(header)
	return "" if match_result == null else match_result.get_string(1)


func _find_property(block_source: String, property_name: String) -> Dictionary:
	var regex := RegEx.new()
	if regex.compile('(?m)^\\s*%s\\s*=\\s*"([^"]+)"' % property_name) != OK:
		return {}
	var match_result := regex.search(block_source)
	if match_result == null:
		return {}
	return {
		"value": match_result.get_string(1),
		"start": match_result.get_start(1),
	}


func _resolve_property_target(
	block_source: String,
	property_name: String,
	external_resources: Dictionary,
) -> String:
	var regex := RegEx.new()
	if regex.compile('(?m)^\\s*%s\\s*=\\s*ExtResource\\("([^"]+)"\\)' % property_name) != OK:
		return ""
	var match_result := regex.search(block_source)
	if match_result == null:
		return ""
	return String(external_resources.get(match_result.get_string(1), ""))


func _collect_pattern_definitions(
	definitions: Dictionary,
	source: String,
	path: String,
	kind: String,
	pattern: String,
) -> void:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return
	for match_result: RegExMatch in regex.search_all(source):
		var name := match_result.get_string(1)
		if name.is_empty():
			continue
		_append_definition(
			definitions,
			_make_definition(
				kind,
				name,
				path,
				_line_at(source, match_result.get_start(1)),
				path,
			),
		)


func _make_definition(
	kind: String,
	name: String,
	owner_path: String,
	line: int,
	target_path: String,
) -> Dictionary:
	return {
		"kind": kind,
		"name": name,
		"owner_path": owner_path,
		"line": line,
		"target_path": target_path,
	}


func _append_definition(definitions: Dictionary, definition: Dictionary) -> void:
	var kind := String(definition.get("kind", ""))
	var name := String(definition.get("name", ""))
	if kind.is_empty() or name.is_empty():
		return
	if not definitions.has(kind):
		definitions[kind] = []
	var kind_definitions: Array = definitions[kind]
	for existing: Dictionary in kind_definitions:
		if (
			existing.get("name") == name
			and existing.get("owner_path") == definition.get("owner_path")
			and existing.get("line") == definition.get("line")
		):
			return
	kind_definitions.append(definition)


func _merge_file_definitions(file_definitions: Dictionary) -> void:
	for kind: String in file_definitions:
		for definition: Dictionary in file_definitions[kind]:
			_add_index_definition(definition)


func _add_index_definition(definition: Dictionary) -> void:
	var kind := String(definition.get("kind", ""))
	var name := String(definition.get("name", ""))
	if not _symbols.has(kind) or name.is_empty():
		return
	var values: PackedStringArray = _symbols[kind]
	if not values.has(name):
		values.append(name)
	var by_name: Dictionary = _definitions[kind]
	if not by_name.has(name):
		by_name[name] = []
	var definitions: Array = by_name[name]
	for existing: Dictionary in definitions:
		if (
			existing.get("owner_path") == definition.get("owner_path")
			and existing.get("line") == definition.get("line")
		):
			return
	definitions.append(definition)


func _line_at(source: String, offset: int) -> int:
	return source.left(clampi(offset, 0, source.length())).count("\n") + 1
