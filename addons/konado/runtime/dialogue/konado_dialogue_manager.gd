extends Control
class_name KonadoDialogueManager

## Konado 2.8 atomic Program runtime

signal shot_start
signal shot_end
signal dialogue_line_start(instruction_id: String)
signal dialogue_line_end(instruction_id: String)
signal custom_signal(content: String)
signal runtime_failed(message: String, instruction_id: String, source_line: int)

enum DialogState { OFF, EXECUTING, WAITING }

const DIALOGUE_SERVICES := preload(
	"res://addons/konado/runtime/dialogue/konado_dialogue_services.gd"
)
const SCRIPT_RUNTIME_DEBUGGER := preload(
	"res://addons/konado/language/integration/konado_script_runtime_debugger.gd"
)
const CAMERA_CONTROLLER_SCRIPT := preload(
	"res://addons/konado/runtime/camera/konado_camera_controller.gd"
)
const CHOICE_CONTROLLER_SCRIPT := preload(
	"res://addons/konado/runtime/dialogue/konado_choice_controller.gd"
)
const SAVE_SYSTEM_SCRIPT := preload("res://addons/konado/runtime/save/konado_save_system.gd")
const SAVE_PANEL_SCRIPT := preload("res://addons/konado/runtime/ui/save/konado_save_panel.gd")
const SETTINGS_ADAPTER_SCRIPT := preload(
	"res://addons/konado/runtime/integrations/konado_settings_adapter.gd"
)
const INVALID_NEXT := -2
const MAX_IMMEDIATE_INSTRUCTIONS_PER_PUMP := 4096

@export_category("Playback Settings")
@export var require_visible_in_tree := true
@export var initialize_on_ready := true
@export var start_on_ready := true
@export var actor_auto_highlight := true
@export var autoplay := false
@export var typing_interval := 0.04
@export var auto_play_delay := 2.0
@export var deterministic_seed := 0

@export_category("Global Variable")
@export var variable_store: KonadoVariableStore

@export_category("UI Settings")
@export var auto_show_dialogue_box := true
@export var horizontal_division := 5
@export var choice_controller: CHOICE_CONTROLLER_SCRIPT
@export var dialogue_box: KonadoDialogueBox
@export var screen_text: KonadoScreenText
@export var stage_controller: KonadoStageController
@export var audio_controller: KonadoAudioController
@export var quick_save_button: Button
@export var quick_load_button: Button
@export var save_panel_button: Button
@export var auto_play_button: Button
@export var achievement_button: Button
@export var settings_button: Button
@export var save_panel: SAVE_PANEL_SCRIPT
@export var save_feedback_label: Label

@export_category("Dialogue Resources")
@export var start_dialogue_shot: KonadoShot
@export var character_list: KonadoCharacterList
@export var background_list: KonadoBackgroundList
@export var background_music_list: KonadoBackgroundMusicList
@export var voice_list: KonadoVoiceList
@export var sound_effect_list: KonadoSoundEffectList

@export_category("Log Tool")
@export var enable_overlay_log := true
@export var error_tooltip_panel: ColorRect
@export var error_tooltip_label: Label
@export var error_skip_button: Button

@export_category("System")
@export var save_system: SAVE_SYSTEM_SCRIPT
@export var settings_adapter: SETTINGS_ADAPTER_SCRIPT

@export_category("Camera")
@export var camera_controller: CAMERA_CONTROLLER_SCRIPT

var dialogue_state := DialogState.OFF
var current_shot: KonadoShot
var _achievement_manager: Node
var _temp_variables: Dictionary = {}
var _waiting_signal_name := ""
var _dialog_data_id := 0
var _story_localization: Node
var _logger: KonadoLogger
var _dialogue_services: RefCounted
var _vm := KonadoVirtualMachine.new()
var _executor: KonadoInstructionExecutor
var _active_token: Dictionary = {}
var _typing_completed_callback := Callable()
var _pending_connections: Array[Dictionary] = []
var _playback_generation := 0
var _shot_active := false
var _pumping := false
var _pump_scheduled := false
var _dialogue_typing := false
var _rng := RandomNumberGenerator.new()
var _shot_program_cache: Dictionary = {}
var _translation_reload_queued := false
var _loaded_locale := ""
var _save_feedback_generation := 0


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_inside_tree():
		return
	_queue_translation_reload()


func _ready() -> void:
	if deterministic_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = deterministic_seed
	_executor = KonadoInstructionExecutor.new(self)
	variable_store = variable_store if variable_store != null else KonadoVariableStore.new()
	_achievement_manager = get_tree().root.get_node_or_null("KonadoAchievements")
	_story_localization = get_tree().root.get_node_or_null("KonadoStoryLocalization")
	_loaded_locale = TranslationServer.get_locale()
	if require_visible_in_tree:
		if not is_visible_in_tree():
			return
		hidden.connect(stop_dialogue)
	if dialogue_box != null:
		dialogue_box.on_dialogue_click.connect(_process_next)
		if audio_controller != null and audio_controller.voice_player != null:
			dialogue_box.bind_voice_player(audio_controller.voice_player)
	if auto_play_button != null:
		auto_play_button.toggled.connect(start_autoplay)
	if quick_save_button != null:
		quick_save_button.pressed.connect(_quick_save)
	if quick_load_button != null:
		quick_load_button.pressed.connect(_quick_load)
	if save_panel_button != null:
		save_panel_button.pressed.connect(_open_save_panel)
	for save_button: Button in [quick_save_button, quick_load_button, save_panel_button]:
		if save_button != null:
			save_button.visible = save_system != null
	if achievement_button != null:
		achievement_button.visible = _achievement_manager != null
		if _achievement_manager != null:
			achievement_button.pressed.connect(_achievement_manager.show_panel)
	if settings_adapter != null:
		settings_adapter.setting_changed.connect(_on_setting_changed)
		if settings_button != null:
			settings_button.pressed.connect(settings_adapter.show_settings_panel)
	if save_system != null:
		save_system.set_dialogue_manager(self)
	if save_panel != null:
		save_panel.set_save_system(save_system)
	_setup_logger()

	if initialize_on_ready:
		_initialize_on_ready.call_deferred()


func _exit_tree() -> void:
	_cancel_execution()
	if _logger != null:
		if _logger.error_caught.is_connected(_show_error):
			_logger.error_caught.disconnect(_show_error)
		OS.remove_logger(_logger)


func _initialize_on_ready() -> void:
	if not is_inside_tree() or not initialize_on_ready:
		return
	# A parent may explicitly select or initialize a shot from its own _ready().
	# Preserve that configuration instead of replacing it with the exported shot.
	if current_shot != null:
		if start_on_ready and not _shot_active:
			start_dialogue()
		return
	init_dialogue(start_dialogue if start_on_ready else Callable())


func init_dialogue(callback: Callable = Callable()) -> void:
	_cancel_execution()
	var shot := _load_localized_shot(start_dialogue_shot)
	if not _install_shot(shot):
		return
	_reset_transient_interfaces()
	if stage_controller != null:
		stage_controller.character_list = character_list
		stage_controller.remove_all_actors(true)
	if callback.is_valid():
		callback.call()


func set_shot(new_shot: KonadoShot) -> void:
	_cancel_execution()
	if screen_text != null:
		screen_text.reset_screen_text()
	var localized := _load_localized_shot(new_shot)
	if _install_shot(localized):
		start_dialogue_shot = localized


func start_dialogue() -> void:
	if current_shot == null or _vm.program == null or _vm.pc == KonadoProgram.INVALID_PC:
		push_error("Konado: 对话尚未初始化")
		return
	if _shot_active:
		return
	_shot_active = true
	dialogue_state = DialogState.EXECUTING
	if not _vm.has_state():
		_vm.synchronize_state(KonadoRuntimeState.capture(self))
	shot_start.emit()
	_schedule_pump()


func stop_dialogue() -> void:
	var emit_end := _shot_active
	_cancel_execution()
	dialogue_state = DialogState.OFF
	_reset_transient_interfaces(false)
	if stage_controller != null:
		stage_controller.remove_all_actors()
		stage_controller.clean_background(
			KonadoStageController.BackgroundTransitionEffect.ALPHA_FADE
		)
	if dialogue_box != null:
		dialogue_box.dismiss_dialogue_box()
	if emit_end:
		shot_end.emit()


func _install_shot(shot: KonadoShot) -> bool:
	if shot == null or not shot.ensure_script_ready() or shot.program == null:
		push_error("Konado: 镜头没有可执行 Program")
		return false
	current_shot = shot.duplicate() as KonadoShot
	_remember_shot(current_shot)
	_temp_variables.clear()
	_waiting_signal_name = ""
	dialogue_state = DialogState.OFF
	return _vm.install(current_shot.program, current_shot.entry_pc())


func _pump() -> void:
	_pump_scheduled = false
	if _pumping or not _shot_active or dialogue_state != DialogState.EXECUTING:
		return
	_pumping = true
	var count := 0
	while _shot_active and dialogue_state == DialogState.EXECUTING:
		if count >= MAX_IMMEDIATE_INSTRUCTIONS_PER_PUMP:
			# This is a per-pump time-slice, not a total execution limit. Yielding
			# keeps a large linear script responsive without misdiagnosing it as an
			# infinite loop. A genuine no-wait loop is likewise unable to lock a
			# frame and remains observable/cancellable by the host application.
			break
		count += 1
		var instruction := _current_instruction()
		if instruction == null:
			_finish_shot()
			break
		if SCRIPT_RUNTIME_DEBUGGER.before_instruction(self, instruction):
			dialogue_state = DialogState.WAITING
			break
		_active_token = _vm.begin_patch(_capture_instruction_state(instruction))
		if _active_token.is_empty():
			_fail_current("VM 无法开始当前指令")
			break
		dialogue_line_start.emit(instruction.stable_key())
		if not _token_is_active(_active_token):
			break
		var result := _executor.execute(instruction, _active_token)
		if result == KonadoVirtualMachine.Result.WAITING:
			# Zero-duration transitions and already-satisfied awaitables may complete
			# synchronously inside the handler. Only suspend if that transaction is
			# still active; otherwise continue pumping the newly committed PC.
			if not _active_token.is_empty():
				dialogue_state = DialogState.WAITING
				break
			continue
		if result == KonadoVirtualMachine.Result.FAILED:
			var failure_reason := _executor.get_failure_reason()
			_fail_current(
				(
					failure_reason
					if not failure_reason.is_empty()
					else "指令执行失败：%s" % KonadoOpcode.name_of(instruction.opcode())
				)
			)
			break
		if not _active_token.is_empty():
			_fail_current("指令执行器未提交原子事务")
			break
	_pumping = false
	if _shot_active and dialogue_state == DialogState.EXECUTING:
		_schedule_pump()


func _schedule_pump() -> void:
	if _pump_scheduled or not _shot_active:
		return
	_pump_scheduled = true
	_pump.call_deferred()


func _resume_from_debugger() -> void:
	if not _shot_active or not _active_token.is_empty():
		return
	dialogue_state = DialogState.EXECUTING
	_schedule_pump()


func _complete_instruction(
	token: Dictionary, next_pc := INVALID_NEXT, schedule_next := true
) -> void:
	if not _token_is_active(token):
		return
	var instruction := _current_instruction()
	if instruction == null:
		return
	if next_pc == INVALID_NEXT:
		next_pc = instruction.next_pc()
	dialogue_line_end.emit(instruction.stable_key())
	if not _token_is_active(token):
		return
	if not _vm.commit_patch(token, next_pc, _capture_instruction_state(instruction)):
		_fail_current("VM 提交失败")
		return
	_active_token.clear()
	_waiting_signal_name = ""
	_dialogue_typing = false
	dialogue_state = DialogState.EXECUTING
	if next_pc == KonadoProgram.INVALID_PC:
		_finish_shot()
	elif schedule_next:
		_schedule_pump()


func _transition_to_shot(token: Dictionary, target: KonadoShot) -> bool:
	if not _token_is_active(token):
		return false
	var next_shot := _prepare_transition_target(target)
	if next_shot == null:
		return false
	var entry_pc := next_shot.entry_pc()
	dialogue_line_end.emit(_current_instruction().stable_key())
	if not _token_is_active(token):
		return false
	var previous_shot := current_shot
	var previous_temporary_variables := _temp_variables.duplicate(true)
	_temp_variables.clear()
	_waiting_signal_name = ""
	current_shot = next_shot
	_remember_shot(current_shot)
	var state_after := KonadoRuntimeState.capture(self)
	if not _vm.transition(token, next_shot.program, entry_pc, state_after):
		current_shot = previous_shot
		_temp_variables = previous_temporary_variables
		return false
	_active_token.clear()
	_dialogue_typing = false
	dialogue_state = DialogState.EXECUTING
	shot_end.emit()
	if not _shot_active:
		return true
	shot_start.emit()
	if _shot_active:
		_schedule_pump()
	return true


func _prepare_transition_target(target: KonadoShot) -> KonadoShot:
	var localized := _load_localized_shot(target)
	if localized == null or not localized.ensure_script_ready() or localized.program == null:
		push_error("Konado: jump 目标没有可执行 Program")
		return null
	var next_shot := localized.duplicate() as KonadoShot
	if next_shot.entry_pc() == KonadoProgram.INVALID_PC:
		push_error("Konado: jump 目标没有入口指令")
		return null
	return next_shot


func _finish_shot() -> void:
	if not _shot_active:
		return
	_shot_active = false
	dialogue_state = DialogState.OFF
	_cancel_pending_callbacks()
	shot_end.emit()


func _fail_current(message: String) -> void:
	var instruction := _current_instruction()
	var key := instruction.stable_key() if instruction != null else ""
	var line := instruction.source_line() if instruction != null else -1
	if not _active_token.is_empty():
		_vm.fail(_active_token)
	_active_token.clear()
	push_error("Konado: %s (%s:%d)" % [message, key, line])
	runtime_failed.emit(message, key, line)
	_cancel_execution()
	dialogue_state = DialogState.OFF


func _current_instruction() -> KonadoInstruction:
	return current_shot.instruction_at(_vm.pc) if current_shot != null else null


func _capture_instruction_state(instruction: KonadoInstruction) -> Dictionary:
	return KonadoRuntimeState.capture_instruction_patch(self, instruction)


func _token_is_active(token: Dictionary) -> bool:
	return not token.is_empty() and token == _active_token


func _set_waiting_token(token: Dictionary) -> void:
	if _token_is_active(token):
		dialogue_state = DialogState.WAITING


func _await_signal(completion: Signal, token: Dictionary, two_arguments := false) -> void:
	if completion.is_null() or not _token_is_active(token):
		return
	var callback := (
		_on_two_argument_signal_completed.bind(token)
		if two_arguments
		else _on_signal_completed.bind(token)
	)
	completion.connect(callback, CONNECT_ONE_SHOT)
	_pending_connections.append({"signal": completion, "callback": callback, "token": token})
	_set_waiting_token(token)


func _await_result_signal(completion: Signal, token: Dictionary, motion := false) -> void:
	if completion.is_null() or not _token_is_active(token):
		return
	var callback := (
		_on_motion_signal_completed.bind(token)
		if motion
		else _on_result_signal_completed.bind(token)
	)
	completion.connect(callback, CONNECT_ONE_SHOT)
	_pending_connections.append({"signal": completion, "callback": callback, "token": token})
	_set_waiting_token(token)


func _on_signal_completed(token: Dictionary) -> void:
	_forget_connection_for(token)
	_complete_instruction(token)


func _on_two_argument_signal_completed(
	_first: Variant, _second: Variant, token: Dictionary
) -> void:
	_forget_connection_for(token)
	_complete_instruction(token)


func _on_result_signal_completed(succeeded: bool, token: Dictionary) -> void:
	_forget_connection_for(token)
	if succeeded:
		_complete_instruction(token)
	elif _token_is_active(token):
		_fail_current("表现操作执行失败")


func _on_motion_signal_completed(
	_actor_id: String, _motion_name: String, succeeded: bool, token: Dictionary
) -> void:
	_on_result_signal_completed(succeeded, token)


func _forget_connection_for(token: Dictionary) -> void:
	for index in range(_pending_connections.size() - 1, -1, -1):
		if _pending_connections[index]["token"] == token:
			_pending_connections.remove_at(index)


func _cancel_execution() -> void:
	_playback_generation += 1
	_shot_active = false
	_vm.cancel()
	_active_token.clear()
	_dialogue_typing = false
	_cancel_pending_callbacks()


func _cancel_pending_callbacks() -> void:
	if (
		dialogue_box != null
		and _typing_completed_callback.is_valid()
		and dialogue_box.typing_completed.is_connected(_typing_completed_callback)
	):
		dialogue_box.typing_completed.disconnect(_typing_completed_callback)
	_typing_completed_callback = Callable()
	for connection in _pending_connections:
		var completion: Signal = connection["signal"]
		var callback: Callable = connection["callback"]
		if not completion.is_null() and completion.is_connected(callback):
			completion.disconnect(callback)
	_pending_connections.clear()
	if dialogue_box != null:
		dialogue_box.cancel_pending_operations()
	if screen_text != null:
		screen_text.cancel_pending_operations()
	if stage_controller != null:
		stage_controller.cancel_pending_operations()
	if audio_controller != null:
		audio_controller.cancel_pending_operations()
	if camera_controller != null:
		camera_controller.cancel_pending_operations()


func _begin_dialogue_instruction(instruction: KonadoInstruction, token: Dictionary) -> void:
	var begin := func() -> void:
		if not _token_is_active(token):
			return
		var speaker_result: Dictionary = _services().resolve_speaker(
			int(instruction.value(&"speaker_kind")), String(instruction.value(&"speaker"))
		)
		if not bool(speaker_result.get("ok", false)):
			_fail_current(String(speaker_result.get("error", "无法解析对话署名")))
			return
		var character := String(speaker_result.get("value", ""))
		var voice := String(instruction.value(&"voice_id"))
		if not voice.is_empty():
			var voice_result := _play_voice_resource(voice)
			if not bool(voice_result.get("ok", false)):
				_fail_current("未找到语音资源：%s" % voice)
				return
		elif dialogue_box != null:
			dialogue_box.clear_voice_progress()
		if actor_auto_highlight and stage_controller != null and not character.is_empty():
			stage_controller.highlight_actor(character)
		var interval := float(instruction.value(&"interval", -1.0))
		var speed := float(instruction.value(&"speed", 1.0))
		dialogue_box.typing_interval = (interval if interval >= 0.0 else typing_interval / speed)
		dialogue_box.character_name = character
		dialogue_box.dialogue_text = _interpolate_variables(String(instruction.value(&"content")))
		_dialogue_typing = true
		_typing_completed_callback = _on_dialogue_typing_completed.bind(token)
		dialogue_box.typing_completed.connect(_typing_completed_callback, CONNECT_ONE_SHOT)
		_set_waiting_token(token)
	if auto_show_dialogue_box and not dialogue_box.is_dialogue_box_visible():
		dialogue_box.show_dialogue_box(begin)
	else:
		begin.call()


func _on_dialogue_typing_completed(token: Dictionary) -> void:
	if not _token_is_active(token):
		return
	_dialogue_typing = false
	_typing_completed_callback = Callable()
	if autoplay:
		var generation := _playback_generation
		await get_tree().create_timer(auto_play_delay).timeout
		if generation == _playback_generation:
			_complete_instruction(token)
		return
	var instruction := _current_instruction()
	if instruction != null:
		var next := current_shot.instruction_at(instruction.next_pc())
		if next != null and next.opcode() == KonadoOpcode.Type.CHOICE:
			_complete_instruction.call_deferred(token)


func _process_next() -> void:
	if not _shot_active or dialogue_state != DialogState.WAITING:
		return
	var instruction := _current_instruction()
	if instruction == null or instruction.opcode() != KonadoOpcode.Type.DIALOGUE:
		return
	if _dialogue_typing:
		dialogue_box.skip_typing_anim()
	else:
		_complete_instruction(_active_token)


func _on_option_triggered(choice: Dictionary, playback_generation := -1) -> void:
	if playback_generation >= 0 and playback_generation != _playback_generation:
		return
	if not _token_is_active(_active_token):
		return
	var target_pc := int(choice.get("target_pc", KonadoProgram.INVALID_PC))
	if target_pc == KonadoProgram.INVALID_PC:
		_fail_current("选项目标无效")
		return
	if choice_controller != null:
		choice_controller.distroy_options()
	_complete_instruction(_active_token, target_pc)


func emit_wait_signal(signal_name: String) -> void:
	if _waiting_signal_name == signal_name and _token_is_active(_active_token):
		_complete_instruction(_active_token)


func reload_localized_script(locale: String) -> bool:
	return _services()._reload_localized_script(locale)


func _queue_translation_reload() -> void:
	if _translation_reload_queued:
		return
	_translation_reload_queued = true
	_apply_translation_change.call_deferred()


func _apply_translation_change() -> void:
	_translation_reload_queued = false
	if not is_inside_tree() or not is_node_ready():
		return
	var locale := TranslationServer.get_locale()
	if locale == _loaded_locale:
		return
	if current_shot == null or reload_localized_script(locale):
		_loaded_locale = locale


func _refresh_current_localized_dialogue() -> void:
	var instruction := _current_instruction()
	if instruction == null:
		return
	if instruction.opcode() == KonadoOpcode.Type.DIALOGUE and dialogue_box != null:
		var speaker_result: Dictionary = _services().resolve_speaker(
			int(instruction.value(&"speaker_kind")), String(instruction.value(&"speaker"))
		)
		if not bool(speaker_result.get("ok", false)):
			return
		dialogue_box.character_name = String(speaker_result.get("value", ""))
		dialogue_box.dialogue_text = _interpolate_variables(String(instruction.value(&"content")))
	elif instruction.opcode() == KonadoOpcode.Type.CHOICE and choice_controller != null:
		choice_controller.display_options(
			instruction.value(&"options", []), self, 32, _playback_generation
		)


func _load_localized_shot(shot: KonadoShot) -> KonadoShot:
	return _services()._load_localized_shot(shot)


func _display_background_resource(name: String, effect: int, duration: float) -> bool:
	return _services()._display_background(name, effect, duration)


func _show_actor_resource(actor: String, state: String, position: int, duration: float) -> bool:
	var target: KonadoCharacter
	if character_list != null:
		for character in character_list.characters:
			if character.character_id == actor:
				target = character
				break
	if target == null or target.character_scene == null:
		push_error("Konado: 未找到角色资源 '%s'" % actor)
		return false
	stage_controller.show_actor(
		actor,
		horizontal_division,
		position,
		state,
		target.character_scene,
		target.actor_motion_layer,
		duration
	)
	return true


func _play_bgm_resource(name: String) -> bool:
	return _services()._play_bgm(name)


func _play_voice_resource(name: String) -> Dictionary:
	return _services()._play_voice(name)


func _play_sfx_resource(name: String) -> bool:
	return _services()._play_sound_effect(name)


func _read_variable(name: String, persistent: bool) -> Variant:
	return variable_store.get_value(name) if persistent else _temp_variables.get(name)


func _resolve_operand(value: Variant) -> Variant:
	if value is Dictionary and value.get("kind") == "variable":
		return _read_variable(String(value.get("name", "")), bool(value.get("persistent", false)))
	return value


func _compare_values(left: Variant, right: Variant, operator: int) -> Dictionary:
	return KonadoValueOperations.compare(left, right, operator)


func _apply_variable_instruction(instruction: KonadoInstruction) -> bool:
	var name := String(instruction.value(&"name"))
	var operation := int(instruction.value(&"operation"))
	var operand := _resolve_operand(instruction.value(&"operand"))
	if bool(instruction.value(&"persistent")):
		return variable_store.apply_operation(name, operation, operand)
	return _services()._apply_temp_operation(name, operation, operand)


func _interpolate_variables(text: String) -> String:
	return _services()._interpolate_variables(text)


func can_rollback(steps := 1) -> bool:
	return _vm.can_rollback(steps, true)


func rollback(steps := 1) -> bool:
	# A waiting instruction owns an uncommitted VM token. Rollback operates on
	# committed boundaries, so cancel that transaction before inspecting history.
	_cancel_active_instruction()
	var ok := _vm.rollback(steps, _restore_runtime_state)
	if ok:
		_shot_active = true
		dialogue_state = DialogState.EXECUTING
		_schedule_pump()
	else:
		_cancel_pending_callbacks()
	return ok


func create_checkpoint(label := "") -> String:
	return _vm.create_checkpoint(label, KonadoRuntimeState.capture(self))


func restore_checkpoint(checkpoint_id: String) -> bool:
	_cancel_active_instruction()
	var ok := _vm.restore_checkpoint(checkpoint_id, _restore_runtime_state)
	if ok:
		_shot_active = true
		dialogue_state = DialogState.EXECUTING
		_schedule_pump()
	else:
		_cancel_pending_callbacks()
	return ok


func get_execution_history(limit := 0) -> Array[Dictionary]:
	return _vm.history(limit)


func clear_execution_history() -> void:
	_vm.clear_history()


func _capture_execution_snapshot() -> Dictionary:
	if (
		current_shot == null
		or current_shot.source_path.is_empty()
		or current_shot.source_path == "null"
		or _vm.program == null
		or _vm.pc == KonadoProgram.INVALID_PC
	):
		return {}
	var state := _vm.snapshot_state()
	if state.is_empty():
		state = KonadoRuntimeState.capture(self)
	return {
		"execution":
		{
			"shot_path": current_shot.source_path,
			"program_fingerprint": _vm.program.fingerprint(),
			"instruction_id": _vm.program.key_for_pc(_vm.pc),
		},
		"runtime_state": state,
	}


func _restore_execution_snapshot(snapshot: Dictionary) -> bool:
	var execution: Dictionary = snapshot.get("execution", {})
	var runtime_state: Dictionary = snapshot.get("runtime_state", {})
	var resolved := _resolve_snapshot_target(execution)
	if resolved.is_empty():
		return false
	var shot: KonadoShot = resolved.shot
	var pc := int(resolved.pc)
	if not KonadoRuntimeState.validate(runtime_state, self):
		return false
	_cancel_execution()
	current_shot = shot.duplicate() as KonadoShot
	if not _vm.restore_boundary(current_shot.program, pc, runtime_state):
		_enter_safe_off_state()
		return false
	if not KonadoRuntimeState.restore(runtime_state, self):
		_enter_safe_off_state()
		return false
	_shot_active = true
	dialogue_state = DialogState.EXECUTING
	_schedule_pump()
	return true


func _restore_runtime_state(state: Dictionary) -> bool:
	var execution: Dictionary = state.get("execution", {})
	var shot_path := String(execution.get("shot_path", ""))
	var expected_fingerprint := String(execution.get("program_fingerprint", ""))
	if expected_fingerprint.is_empty():
		return false
	var shot := _shot_program_cache.get(expected_fingerprint) as KonadoShot
	if shot == null and not shot_path.is_empty():
		shot = _load_localized_shot(load(shot_path) as KonadoShot)
	if shot == null and not shot_path.is_empty() and FileAccess.file_exists(shot_path):
		shot = KonadoScriptCompiler.new().compile_file(shot_path)
	if (
		shot == null
		or not shot.ensure_script_ready()
		or shot.program == null
		or shot.program_fingerprint() != expected_fingerprint
		or _vm.program == null
		or _vm.program.fingerprint() != expected_fingerprint
	):
		return false
	var previous_shot := current_shot
	current_shot = shot.duplicate() as KonadoShot
	if not KonadoRuntimeState.restore(state, self):
		current_shot = previous_shot
		return false
	return true


func _remember_shot(shot: KonadoShot) -> void:
	if shot == null or shot.program == null or not shot.program.is_valid():
		return
	_shot_program_cache[shot.program_fingerprint()] = shot.duplicate() as KonadoShot


func _enter_safe_off_state() -> void:
	_cancel_execution()
	if stage_controller != null:
		stage_controller.remove_all_actors(true)
		stage_controller.clean_background(KonadoStageController.BackgroundTransitionEffect.NONE)
	if audio_controller != null:
		audio_controller.stop_background_music()
		audio_controller.stop_voice()
	if camera_controller != null:
		camera_controller.restore_state(
			{"position": Vector2.ZERO, "zoom": Vector2.ONE, "offset": Vector2.ZERO}
		)
	current_shot = null
	dialogue_state = DialogState.OFF
	_reset_transient_interfaces()


func _cancel_active_instruction() -> void:
	_playback_generation += 1
	_vm.cancel()
	_active_token.clear()
	_dialogue_typing = false
	_cancel_pending_callbacks()


func _resolve_snapshot_target(execution: Dictionary) -> Dictionary:
	var shot_path := String(execution.get("shot_path", ""))
	if shot_path.is_empty() or not ResourceLoader.exists(shot_path):
		return {}
	var shot := _load_localized_shot(load(shot_path) as KonadoShot)
	if shot == null or not shot.ensure_script_ready() or shot.program == null:
		return {}
	if shot.program.fingerprint() != String(execution.get("program_fingerprint", "")):
		return {}
	var pc := shot.pc_for_key(String(execution.get("instruction_id", "")))
	if pc == KonadoProgram.INVALID_PC:
		return {}
	return {"shot": shot, "pc": pc}


func start_autoplay(value: bool) -> void:
	autoplay = value
	if auto_play_button != null:
		auto_play_button.text = tr("KONADO_AUTO_PLAY_STOP") if value else tr("KONADO_AUTO_PLAY")


func _quick_save() -> void:
	if save_system == null:
		return
	var succeeded := save_game(0)
	_show_save_feedback("KONADO_QUICK_SAVE_SUCCEEDED" if succeeded else "KONADO_QUICK_SAVE_FAILED")
	if save_panel != null:
		save_panel.show_status(
			"KONADO_QUICK_SAVE_SUCCEEDED" if succeeded else "KONADO_QUICK_SAVE_FAILED"
		)


func _quick_load() -> void:
	if save_system == null:
		return
	if not bool(get_save_info(0).get("exists", false)):
		_show_save_feedback("KONADO_QUICK_SAVE_MISSING")
		if save_panel != null:
			save_panel.show_status("KONADO_QUICK_SAVE_MISSING")
		return
	if not load_game(0):
		_show_save_feedback("KONADO_QUICK_LOAD_FAILED")
		if save_panel != null:
			save_panel.show_status("KONADO_QUICK_LOAD_FAILED")


func _open_save_panel() -> void:
	if save_panel != null:
		save_panel.open_panel()


func _show_save_feedback(message_key: StringName) -> void:
	if save_feedback_label == null:
		return
	_save_feedback_generation += 1
	var generation := _save_feedback_generation
	save_feedback_label.text = tr(message_key)
	save_feedback_label.visible = true
	get_tree().create_timer(2.0).timeout.connect(
		func() -> void:
			if generation == _save_feedback_generation and save_feedback_label != null:
				save_feedback_label.visible = false
	)


func get_dialogue_variable(key: String) -> Dictionary:
	return {"value": variable_store.get_value(key)} if variable_store.has(key) else {}


func save_game(id: int) -> bool:
	return _services()._save_game(id)


func load_game(id: int) -> bool:
	return _services()._load_game(id)


func delete_save(id: int) -> bool:
	return _services()._delete_save(id)


func get_save_info(id: int) -> Dictionary:
	return _services()._get_save_info(id)


func get_all_save_info() -> Array[Dictionary]:
	return _services()._get_all_save_info()


func _services() -> RefCounted:
	if _dialogue_services == null:
		_dialogue_services = DIALOGUE_SERVICES.new(self)
	return _dialogue_services


func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	_services()._apply_setting(category, key, value)


func _reset_transient_interfaces(reset_dialogue_box := true) -> void:
	_waiting_signal_name = ""
	if choice_controller != null:
		choice_controller.init_dialog_box()
	if reset_dialogue_box and dialogue_box != null:
		dialogue_box.reset_dialogue_box()
	if screen_text != null:
		screen_text.reset_screen_text()
	if audio_controller != null:
		audio_controller.stop_voice()


func _setup_logger() -> void:
	if not enable_overlay_log:
		return
	_logger = KonadoLogger.new()
	OS.add_logger(_logger)
	_logger.error_caught.connect(_show_error, CONNECT_DEFERRED)
	if error_skip_button != null and error_tooltip_panel != null:
		error_skip_button.pressed.connect(error_tooltip_panel.hide)


func _show_error(message: String) -> void:
	if error_tooltip_label != null:
		error_tooltip_label.text = message
	if error_tooltip_panel != null:
		error_tooltip_panel.show()
