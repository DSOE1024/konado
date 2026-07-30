@tool
extends RefCounted
class_name KS_DocumentStore

## Shared revision cache for disk files and unsaved Script Editor buffers.

static var _shared_instance: KS_DocumentStore

var _documents := {}


static func shared() -> KS_DocumentStore:
	if _shared_instance == null:
		_shared_instance = KS_DocumentStore.new()
	return _shared_instance


func get_document(path: String) -> KS_DocumentModel:
	var source := ""
	var open_buffer := _find_open_buffer(path)
	if bool(open_buffer.get("found", false)):
		source = String(open_buffer.get("source", ""))
	elif FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			source = file.get_as_text()
	var document := _get_or_create(path)
	document.update(source, path)
	return document


func update_buffer(path: String, source: String) -> KS_DocumentModel:
	var document := _get_or_create(path)
	document.update(source, path)
	return document


func get_open_source(path: String) -> String:
	return String(_find_open_buffer(path).get("source", ""))


func _find_open_buffer(path: String) -> Dictionary:
	if not Engine.is_editor_hint():
		return {"found": false}
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return {"found": false}
	for script: Script in script_editor.get_open_scripts():
		if script != null and script.resource_path == path:
			return {"found": true, "source": script.source_code}
	return {"found": false}


func _get_or_create(path: String) -> KS_DocumentModel:
	var document: KS_DocumentModel = _documents.get(path)
	if document == null:
		document = KS_DocumentModel.new()
		_documents[path] = document
	return document


func invalidate(path: String = "") -> void:
	if path.is_empty():
		_documents.clear()
	else:
		_documents.erase(path)


func get_cached_paths() -> PackedStringArray:
	var paths := PackedStringArray(_documents.keys())
	paths.sort()
	return paths
