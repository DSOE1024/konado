@tool
extends EditorImportPlugin

const FORMAT_VERSION := 1


func _get_importer_name() -> String:
	return "konado.scripts"


func _get_import_order() -> int:
	return 0


func _get_priority() -> float:
	return 1.0


func _get_visible_name() -> String:
	return "KonadoScript"


func _get_recognized_extensions() -> PackedStringArray:
	return ["ks"]


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	# Script global classes are not registered in ClassDB, so Godot's binary
	# resource loader cannot resolve a `.res` import advertised as KND_Shot.
	# The saved resource still loads as KND_Shot through its script metadata.
	return "Resource"


func _get_format_version() -> int:
	return FORMAT_VERSION


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index) -> String:
	return "Default"


func _get_import_options(_path, _preset_index) -> Array[Dictionary]:
	return []


func _get_option_visibility(_path, _option_name, _options) -> bool:
	return true


func _import(source_file, save_path, _options, _platform_variants, _gen_files) -> Error:
	var interpreter = KonadoScriptsInterpreter.new()
	var diadata: KND_Shot = interpreter.process_scripts_to_data(source_file)
	if diadata == null:
		printerr("Failed to process scripts")
		return FAILED
	var output_path = "%s.%s" % [save_path, _get_save_extension()]
	var error = ResourceSaver.save(
		diadata,
		output_path,
		ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	)

	if error != OK:
		printerr(error)
		return error

	return OK
