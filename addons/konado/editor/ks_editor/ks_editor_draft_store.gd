extends RefCounted
class_name KS_EditorDraftStore

const DRAFT_DIRECTORY := "user://konado/editor_drafts"


static func save(document: KS_EditorDocument) -> Error:
	if document == null or document.path.is_empty() or not document.dirty:
		return OK
	var directory_error := _ensure_directory()
	if directory_error != OK:
		return directory_error

	var draft_path := get_draft_path(document.path)
	var temporary_path := draft_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var payload := (
		JSON
		. stringify(
			{
				"path": document.path,
				"content": document.content,
				"saved_hash": document.saved_content.sha256_text(),
			}
		)
	)
	file.store_string(payload)
	file.flush()
	file.close()

	var global_draft_path := ProjectSettings.globalize_path(draft_path)
	var global_temporary_path := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(draft_path):
		var remove_error := DirAccess.remove_absolute(global_draft_path)
		if remove_error != OK:
			return remove_error
	return DirAccess.rename_absolute(global_temporary_path, global_draft_path)


static func load_for_path(path: String, saved_content: String) -> Dictionary:
	var draft_path := get_draft_path(path)
	if not FileAccess.file_exists(draft_path):
		return {}
	var file := FileAccess.open(draft_path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	if not json.data is Dictionary:
		return {}
	var draft: Dictionary = json.data
	if draft.get("path", "") != path or typeof(draft.get("content", "")) != TYPE_STRING:
		return {}
	if draft.get("saved_hash", "") != saved_content.sha256_text():
		draft["base_changed"] = true
	return draft


static func remove(path: String) -> Error:
	var draft_path := get_draft_path(path)
	if not FileAccess.file_exists(draft_path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(draft_path))


static func get_draft_path(path: String) -> String:
	return DRAFT_DIRECTORY.path_join(path.sha256_text() + ".json")


static func _ensure_directory() -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DRAFT_DIRECTORY))
