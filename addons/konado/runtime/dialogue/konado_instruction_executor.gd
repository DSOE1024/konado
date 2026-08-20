extends RefCounted
class_name KonadoInstructionExecutor

## Executes one atomic instruction. Flow ownership remains in KonadoVirtualMachine.

var _host_ref: WeakRef
var _handlers: Dictionary = {}
var _failure_reason := ""


func _init(host: KonadoDialogueManager) -> void:
	_host_ref = weakref(host)
	for opcode in KonadoScriptCommandRegistry.RUNTIME_HANDLERS:
		var handler_name := KonadoScriptCommandRegistry.runtime_handler(int(opcode))
		var handler := Callable(self, handler_name)
		if handler.is_valid():
			_handlers[int(opcode)] = handler


func execute(instruction: KonadoInstruction, token: Dictionary) -> int:
	_failure_reason = ""
	var host := _host_ref.get_ref() as KonadoDialogueManager
	if host == null:
		return KonadoVirtualMachine.Result.FAILED
	var handler: Callable = _handlers.get(instruction.opcode(), Callable())
	if not handler.is_valid():
		push_error("Konado VM 不支持操作码：%s" % KonadoOpcode.name_of(instruction.opcode()))
		return KonadoVirtualMachine.Result.FAILED
	var result := int(handler.call(host, instruction, token))
	if result == KonadoVirtualMachine.Result.COMPLETED and host._token_is_active(token):
		host._complete_instruction(token, instruction.next_pc())
	return result


func get_failure_reason() -> String:
	return _failure_reason


func _failed(reason: String) -> int:
	_failure_reason = reason if not reason.is_empty() else "指令执行失败"
	return KonadoVirtualMachine.Result.FAILED


func _dialogue(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.dialogue_box == null:
		push_error("Konado: dialogue 指令需要 KonadoDialogueBox")
		return KonadoVirtualMachine.Result.FAILED
	host._begin_dialogue_instruction(instruction, token)
	return KonadoVirtualMachine.Result.WAITING


func _background(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.stage_controller == null:
		return KonadoVirtualMachine.Result.FAILED
	host._await_result_signal(host.stage_controller.background_change_finished, token)
	var accepted := (
		host
		. _display_background_resource(
			String(instruction.value(&"background")),
			int(instruction.value(&"effect")),
			float(instruction.value(&"duration")),
		)
	)
	if not accepted:
		return KonadoVirtualMachine.Result.FAILED
	return KonadoVirtualMachine.Result.WAITING


func _actor_show(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.stage_controller == null:
		return KonadoVirtualMachine.Result.FAILED
	host._await_result_signal(host.stage_controller.actor_shown, token)
	var position: Vector2 = instruction.value(&"position", Vector2.ZERO)
	if not host._show_actor_resource(
		String(instruction.value(&"actor")),
		String(instruction.value(&"state")),
		int(position.x),
		float(instruction.value(&"duration"))
	):
		return KonadoVirtualMachine.Result.FAILED
	return KonadoVirtualMachine.Result.WAITING


func _actor_change(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.stage_controller == null:
		return KonadoVirtualMachine.Result.FAILED
	if host.stage_controller.get_actor(String(instruction.value(&"actor"))) == null:
		return KonadoVirtualMachine.Result.FAILED
	host._await_result_signal(host.stage_controller.actor_state_changed, token)
	host.stage_controller.change_actor_state(
		String(instruction.value(&"actor")),
		String(instruction.value(&"state")),
		float(instruction.value(&"duration"))
	)
	return KonadoVirtualMachine.Result.WAITING


func _actor_move(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.stage_controller == null:
		return KonadoVirtualMachine.Result.FAILED
	if host.stage_controller.get_actor(String(instruction.value(&"actor"))) == null:
		return KonadoVirtualMachine.Result.FAILED
	host._await_result_signal(host.stage_controller.actor_moved, token)
	var position: Vector2 = instruction.value(&"position", Vector2.ZERO)
	host.stage_controller.move_actor(
		String(instruction.value(&"actor")), int(position.x), float(instruction.value(&"duration"))
	)
	return KonadoVirtualMachine.Result.WAITING


func _actor_motion(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.stage_controller == null:
		return KonadoVirtualMachine.Result.FAILED
	if host.stage_controller.get_actor(String(instruction.value(&"actor"))) == null:
		return KonadoVirtualMachine.Result.FAILED
	host._await_result_signal(host.stage_controller.actor_motion_finished, token, true)
	host.stage_controller.play_actor_motion(
		String(instruction.value(&"actor")),
		String(instruction.value(&"motion")),
		{"duration": float(instruction.value(&"duration"))}
	)
	return KonadoVirtualMachine.Result.WAITING


func _actor_exit(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.stage_controller == null:
		return KonadoVirtualMachine.Result.FAILED
	if host.stage_controller.get_actor(String(instruction.value(&"actor"))) == null:
		return KonadoVirtualMachine.Result.FAILED
	host._await_result_signal(host.stage_controller.actor_removed, token)
	host.stage_controller.remove_actor(
		String(instruction.value(&"actor")), float(instruction.value(&"duration"))
	)
	return KonadoVirtualMachine.Result.WAITING


func _choice(host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary) -> int:
	var choices: Array[Dictionary] = instruction.value(&"options", [])
	if choices.is_empty() or host.choice_controller == null:
		push_error("Konado: choice 指令没有有效选项或选项界面")
		return KonadoVirtualMachine.Result.FAILED
	host._set_waiting_token(token)
	host.choice_controller.display_options(choices, host, 32, host._playback_generation)
	host.choice_controller.show()
	return KonadoVirtualMachine.Result.WAITING


func _audio_bgm_play(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	return (
		KonadoVirtualMachine.Result.COMPLETED
		if host._play_bgm_resource(String(instruction.value(&"resource")))
		else KonadoVirtualMachine.Result.FAILED
	)


func _audio_bgm_stop(
	host: KonadoDialogueManager, _instruction: KonadoInstruction, _token: Dictionary
) -> int:
	if host.audio_controller == null:
		return KonadoVirtualMachine.Result.FAILED
	host.audio_controller.stop_background_music()
	return KonadoVirtualMachine.Result.COMPLETED


func _audio_sfx_play(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	return (
		KonadoVirtualMachine.Result.COMPLETED
		if host._play_sfx_resource(String(instruction.value(&"resource")))
		else KonadoVirtualMachine.Result.FAILED
	)


func _condition(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	var target := _condition_target(host, instruction)
	if not bool(target.get("ok", false)):
		return _failed("condition：%s" % String(target.get("reason", "条件求值失败")))
	host._complete_instruction(token, int(target.get("pc", KonadoProgram.INVALID_PC)))
	return KonadoVirtualMachine.Result.COMPLETED


func _variable(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	return (
		KonadoVirtualMachine.Result.COMPLETED
		if host._apply_variable_instruction(instruction)
		else KonadoVirtualMachine.Result.FAILED
	)


func _jump_branch(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	host._complete_instruction(token, instruction.next_pc())
	return KonadoVirtualMachine.Result.COMPLETED


func _emit_signal(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	host.custom_signal.emit(String(instruction.value(&"content")))
	return KonadoVirtualMachine.Result.COMPLETED


func _achievement_unlock(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	if host._achievement_manager == null:
		push_error("Konado: achievement 指令需要启用 KonadoAchievements")
		return KonadoVirtualMachine.Result.FAILED
	host._achievement_manager.unlock_achievement(String(instruction.value(&"id")))
	return KonadoVirtualMachine.Result.COMPLETED


func _achievement_progress(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	if host._achievement_manager == null:
		push_error("Konado: achievement 指令需要启用 KonadoAchievements")
		return KonadoVirtualMachine.Result.FAILED
	host._achievement_manager.increment_progress(
		String(instruction.value(&"id")), instruction.value(&"value")
	)
	return KonadoVirtualMachine.Result.COMPLETED


func _achievement_flag(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	if host._achievement_manager == null:
		push_error("Konado: achievement 指令需要启用 KonadoAchievements")
		return KonadoVirtualMachine.Result.FAILED
	host._achievement_manager.set_flag(
		String(instruction.value(&"id")), bool(instruction.value(&"value"))
	)
	return KonadoVirtualMachine.Result.COMPLETED


func _halt(host: KonadoDialogueManager, _instruction: KonadoInstruction, token: Dictionary) -> int:
	host._complete_instruction(token, KonadoProgram.INVALID_PC)
	return KonadoVirtualMachine.Result.COMPLETED


func _textbox_show(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	return _textbox(host, instruction, token, true)


func _textbox_hide(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	return _textbox(host, instruction, token, false)


func _wait_signal(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	host._waiting_signal_name = String(instruction.value(&"name"))
	host._set_waiting_token(token)
	return KonadoVirtualMachine.Result.WAITING


func _camera_move_async(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	if host.camera_controller == null:
		return _failed("camera.move.async：camera_controller 未配置")
	var accepted := (
		host
		. camera_controller
		. move_to_marker_async(
			String(instruction.value(&"camera")),
			float(instruction.value(&"duration")),
			String(instruction.value(&"transition")),
		)
	)
	return (
		KonadoVirtualMachine.Result.COMPLETED
		if accepted
		else _failed(host.camera_controller.get_last_error())
	)


func _camera_reset_async(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	if host.camera_controller == null:
		return _failed("camera.reset.async：camera_controller 未配置")
	var accepted := host.camera_controller.reset_camera_async(
		float(instruction.value(&"duration")), String(instruction.value(&"transition"))
	)
	return (
		KonadoVirtualMachine.Result.COMPLETED
		if accepted
		else _failed(host.camera_controller.get_last_error())
	)


func _camera_shake_async(
	host: KonadoDialogueManager, instruction: KonadoInstruction, _token: Dictionary
) -> int:
	if host.camera_controller == null:
		return _failed("camera.shake.async：camera_controller 未配置")
	var accepted := host.camera_controller.shake_camera_async(float(instruction.value(&"duration")))
	return (
		KonadoVirtualMachine.Result.COMPLETED
		if accepted
		else _failed(host.camera_controller.get_last_error())
	)


func _camera_stop_async(
	host: KonadoDialogueManager, _instruction: KonadoInstruction, _token: Dictionary
) -> int:
	if host.camera_controller == null:
		return _failed("camera.stop.async：camera_controller 未配置")
	if host.camera_controller.finish_async_operations():
		return KonadoVirtualMachine.Result.COMPLETED
	return _failed(host.camera_controller.get_last_error())


func _condition_target(host: KonadoDialogueManager, instruction: KonadoInstruction) -> Dictionary:
	var variable_name := String(instruction.value(&"variable"))
	var persistent := bool(instruction.value(&"persistent"))
	var left := _condition_variable(host, variable_name, persistent)
	if not bool(left.get("ok", false)):
		return left
	var encoded_target := instruction.value(&"target")
	if encoded_target is Dictionary and encoded_target.get("kind") == "variable":
		var target_name := String(encoded_target.get("name", ""))
		var target_persistent := bool(encoded_target.get("persistent", false))
		var right := _condition_variable(host, target_name, target_persistent)
		if not bool(right.get("ok", false)):
			return right
		encoded_target = right["value"]
	var comparison := host._compare_values(
		left["value"], encoded_target, int(instruction.value(&"operator"))
	)
	if not bool(comparison.get("ok", false)):
		return {
			"ok": false,
			"reason": String(comparison.get("reason", "条件左右值类型不兼容")),
		}
	return {
		"ok": true,
		"pc": instruction.true_pc() if bool(comparison.value) else instruction.false_pc(),
	}


func _condition_variable(host: KonadoDialogueManager, name: String, persistent: bool) -> Dictionary:
	var exists := (
		host.variable_store != null and host.variable_store.has(name)
		if persistent
		else host._temp_variables.has(name)
	)
	if exists:
		return {"ok": true, "value": host._read_variable(name, persistent)}
	var scope := "持久" if persistent else "临时"
	var prefix := "%" if persistent else "$"
	return {
		"ok": false,
		"reason": "找不到%s变量 '%s%s'" % [scope, prefix, name],
	}


func _jump_script(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	var path := String(instruction.value(&"path"))
	var shot := load(path) as KonadoShot
	if shot == null:
		push_error("Konado: 无法加载 jump 目标：%s" % path)
		return KonadoVirtualMachine.Result.FAILED
	return (
		KonadoVirtualMachine.Result.COMPLETED
		if host._transition_to_shot(token, shot)
		else KonadoVirtualMachine.Result.FAILED
	)


func _camera_move(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.camera_controller == null:
		return _failed("camera.move：camera_controller 未配置")
	var accepted := host.camera_controller.move_to_marker(
		String(instruction.value(&"camera")),
		float(instruction.value(&"duration")),
		host._complete_instruction.bind(token),
		String(instruction.value(&"transition"))
	)
	if not accepted:
		return _failed(host.camera_controller.get_last_error())
	host._set_waiting_token(token)
	return KonadoVirtualMachine.Result.WAITING


func _camera_reset(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.camera_controller == null:
		return _failed("camera.reset：camera_controller 未配置")
	var accepted := host.camera_controller.reset_camera(
		true,
		float(instruction.value(&"duration")),
		host._complete_instruction.bind(token),
		String(instruction.value(&"transition"))
	)
	if not accepted:
		return _failed(host.camera_controller.get_last_error())
	host._set_waiting_token(token)
	return KonadoVirtualMachine.Result.WAITING


func _camera_shake(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.camera_controller == null:
		return _failed("camera.shake：camera_controller 未配置")
	var accepted := host.camera_controller.shake_camera(
		float(instruction.value(&"duration")), host._complete_instruction.bind(token)
	)
	if not accepted:
		return _failed(host.camera_controller.get_last_error())
	host._set_waiting_token(token)
	return KonadoVirtualMachine.Result.WAITING


func screen_text(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary
) -> int:
	if host.screen_text == null:
		return KonadoVirtualMachine.Result.FAILED
	var screen_text := host.screen_text
	host._await_signal(screen_text.screen_text_hidden, token)
	screen_text.display(instruction.value(&"lines"), "center", true)
	return KonadoVirtualMachine.Result.WAITING


func _textbox(
	host: KonadoDialogueManager, instruction: KonadoInstruction, token: Dictionary, show: bool
) -> int:
	if host.dialogue_box == null:
		return KonadoVirtualMachine.Result.FAILED
	var completion := (
		host.dialogue_box.on_dialogue_show_completed
		if show
		else host.dialogue_box.on_dialogue_hide_completed
	)
	host._await_signal(completion, token)
	if show:
		host.dialogue_box.show_dialogue_box_with_duration(float(instruction.value(&"duration")))
	else:
		host.dialogue_box.dismiss_dialogue_box_with_duration(float(instruction.value(&"duration")))
	return KonadoVirtualMachine.Result.WAITING
