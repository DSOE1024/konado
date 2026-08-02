extends Node

signal shot_start
signal shot_end
signal dialogue_line_start(node_id: String)
signal dialogue_line_end(node_id: String)
signal custom_signal(content: String)

var last_shot: Resource


func init_dialogue(_callback: Callable = Callable()) -> void:
	pass


func set_shot(shot: Resource) -> void:
	last_shot = shot


func start_dialogue() -> void:
	pass


func stop_dialogue() -> void:
	pass


func start_autoplay(_enabled: bool) -> void:
	pass


func set_chara_list(_value: Resource) -> void:
	pass


func set_background_list(_value: Resource) -> void:
	pass


func set_bgm_list(_value: Resource) -> void:
	pass


func get_dialogue_variable(_name: String) -> Variant:
	return null


func save_game(_save_id: int) -> bool:
	return true


func load_game(_save_id: int) -> bool:
	return true


func delete_save(_save_id: int) -> bool:
	return true


func get_save_info(_save_id: int) -> Dictionary:
	return {}


func get_all_save_info() -> Array[Dictionary]:
	return []


func set_save_strategy(_strategy: Dictionary) -> void:
	pass


func get_save_strategy() -> Dictionary:
	return {}


func reload_localized_script(_locale: String = "") -> bool:
	return true


func emit_wait_signal(_signal_name: String) -> bool:
	return true
