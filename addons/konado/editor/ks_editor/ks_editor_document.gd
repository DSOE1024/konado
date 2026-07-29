extends RefCounted
class_name KS_EditorDocument

var path := ""
var content := ""
var saved_content := ""
var modified_time := 0
var file_size := 0
var caret_line := 0
var caret_column := 0
var scroll_vertical := 0
var dirty := false
var external_prompt_open := false


func _init(document_path: String = "", disk_content: String = "") -> void:
	path = document_path
	content = disk_content
	saved_content = disk_content
	refresh_disk_metadata()


func update_content(new_content: String) -> void:
	content = new_content
	dirty = content != saved_content


func mark_saved(new_content: String) -> void:
	content = new_content
	saved_content = new_content
	dirty = false
	refresh_disk_metadata()


func refresh_disk_metadata() -> void:
	if not FileAccess.file_exists(path):
		modified_time = 0
		file_size = 0
		return
	modified_time = FileAccess.get_modified_time(path)
	file_size = FileAccess.get_size(path)


func disk_metadata_changed() -> bool:
	if not FileAccess.file_exists(path):
		return modified_time != 0 or file_size != 0
	return (
		modified_time != FileAccess.get_modified_time(path)
		or file_size != FileAccess.get_size(path)
	)
