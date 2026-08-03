extends SceneTree

const DIALOGUE_MANAGER_SCENE := preload("res://addons/konado/template/default/konado_dialogue.tscn")
const DIALOGUE_BOX_SCENE := preload("res://addons/konado/template/default/knd_dialogue_box.tscn")

var _failures: int = 0


class WarningCapture:
	extends Logger

	var fallback_warnings: Array[String] = []

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		_rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING and code.begins_with("KND_I18n:"):
			fallback_warnings.append(code)


class RuntimeErrorCapture:
	extends Logger

	var errors: Array[String] = []

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		_rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append(code)


class FakeLocalizedScriptService:
	extends Node

	var localized_shot: KND_Shot
	var restore_node_id: String = ""

	func load_localized_script(
		_script_path: String, _locale: String = "", _warn_on_fallback: bool = true
	) -> KND_Shot:
		return localized_shot

	func choose_restore_node_id(
		_source_shot: KND_Shot, _localized_shot: KND_Shot, current_node_id: String
	) -> String:
		return restore_node_id if not restore_node_id.is_empty() else current_node_id

	func unregister_dialogue_manager(_manager: Node) -> void:
		pass


func _create_manager() -> KND_DialogueManager:
	var manager := DIALOGUE_MANAGER_SCENE.instantiate() as KND_DialogueManager
	manager.init_onstart = false
	manager.check_visable = false
	manager.enable_overlay_log = false
	manager.auto_show_dialogue_box = true
	manager._typing_interval = 0.001
	manager._konado_dialogue_box.enable_typing_effect_audio = false
	root.add_child(manager)
	await process_frame
	manager._konado_dialogue_box.fade_duration = 0.01
	return manager


func _make_dialogue(node_id: String, content: String) -> KND_Dialogue:
	var dialogue := KND_Dialogue.new()
	dialogue.dialog_type = KND_Dialogue.Type.ORDINARY_DIALOG
	dialogue.node_id = node_id
	dialogue.dialog_content = content
	return dialogue


func _make_visibility_shot(
	id_prefix: String, speaker: String, content: String, duration: float
) -> KND_Shot:
	var show := KND_Dialogue.new()
	show.dialog_type = KND_Dialogue.Type.SHOW_TEXTBOX
	show.node_id = "show_" + id_prefix
	show.next_id = "line_" + id_prefix
	show.textbox_duration = duration
	var line := _make_dialogue("line_" + id_prefix, content)
	line.character_id = speaker
	line.next_id = "hide_" + id_prefix
	var hide := KND_Dialogue.new()
	hide.dialog_type = KND_Dialogue.Type.HIDE_TEXTBOX
	hide.node_id = "hide_" + id_prefix
	hide.textbox_duration = duration
	return _make_shot_from_dialogues([show, line, hide])


func _make_shot(content: String) -> KND_Shot:
	return _make_shot_from_dialogues([_make_dialogue("start", content)])


func _make_shot_from_dialogues(dialogues: Array) -> KND_Shot:
	var shot := KND_Shot.new()
	shot.dialogues.assign(dialogues)
	if not dialogues.is_empty():
		shot.start_node_id = dialogues[0].node_id
	return shot


func _free_node(node: Node) -> void:
	node.queue_free()
	await process_frame
	await process_frame


func _wait_for_state(manager: KND_DialogueManager, expected_state: int) -> void:
	for _frame: int in range(30):
		if manager.dialogue_state == expected_state:
			return
		await process_frame
	_expect(false, "dialogue manager reaches state %d" % expected_state)


func _wait_for_node_and_state(
	manager: KND_DialogueManager, expected_node: String, expected_state: int
) -> void:
	await _wait_for_condition(
		func() -> bool:
			return manager.cur_node_id == expected_node and manager.dialogue_state == expected_state,
		"dialogue reaches node %s in state %d" % [expected_node, expected_state],
	)


func _wait_for_condition(condition: Callable, message: String) -> void:
	for _frame: int in range(240):
		if condition.call():
			return
		await process_frame
	_expect(false, message)


func _wait_for_typing_connection_count(
	manager: KND_DialogueManager, expected_count: int, message: String
) -> void:
	for _frame: int in range(60):
		if manager._konado_dialogue_box.typing_completed.get_connections().size() == expected_count:
			return
		await process_frame
	_expect_equal(
		manager._konado_dialogue_box.typing_completed.get_connections().size(),
		expected_count,
		message,
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	printerr("ASSERTION FAILED: " + message)
	_failures += 1


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])
