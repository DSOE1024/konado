@tool
extends ResourceFormatSaver
class_name KS_SourceSaver

## Saves the source text held by a loaded KND_Shot back to its .ks file.
##
## The format loader owns compilation and export remapping. Restricting this saver
## to the .ks extension keeps normal KND_Shot serialization untouched.


func _recognize(resource: Resource) -> bool:
	return resource is KND_Shot


func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	if resource is KND_Shot:
		return PackedStringArray(["ks"])
	return PackedStringArray()


func _save(resource: Resource, path: String, _flags: int) -> Error:
	if not resource is KND_Shot or path.get_extension().to_lower() != "ks":
		return ERR_UNAVAILABLE
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string((resource as KND_Shot).get_source_code())
	var error := file.get_error()
	file.close()
	if error != OK and error != ERR_FILE_EOF:
		return error
	_refresh_compiled_data(resource as KND_Shot, path)
	return OK


func _refresh_compiled_data(shot: KND_Shot, path: String) -> void:
	var compiler := KS_Compiler.new()
	compiler.set_console_output_enabled(false)
	var compiled := compiler.compile_string(shot.get_source_code(), path)
	if compiled == null:
		return
	shot.ks_path = path
	shot.shot_id = compiled.shot_id
	shot.start_node_id = compiled.start_node_id
	shot.dialogues = compiled.dialogues
	shot.dep_characters = compiled.dep_characters
	shot.emit_changed()
