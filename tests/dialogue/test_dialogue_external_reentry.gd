extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"

const CAMERA_CONTROLLER_SCRIPT := preload(
	"res://addons/konado/runtime/camera/konado_camera_controller.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_line_start_reentry_replaces_program_safely()
	await _test_line_end_reentry_does_not_advance_old_program()
	await _test_wait_signal_replacement_ignores_old_signal()
	await _test_voice_wait_contracts()
	await _test_camera_cancellation_preserves_configured_offset()
	if _failures == 0:
		print("PASS: atomic external reentry tests")
	quit(_failures)


func _test_line_start_reentry_replaces_program_safely() -> void:
	var manager := await _create_manager()
	var replaced := [false]
	manager.dialogue_line_start.connect(
		func(_id: String) -> void:
			if replaced[0]:
				return
			replaced[0] = true
			manager.set_shot(_compile_shot('"Kona" "new" [id=new]\nend'))
			manager.start_dialogue()
	)
	manager.set_shot(_compile_shot('"Kona" "old" [id=old]\nend'))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:new", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(manager.dialogue_box.dialogue_text, "new", "new Program owns output")
	_expect_equal(manager.get_execution_history().size(), 0, "old instruction was never committed")
	await _free_node(manager)


func _test_line_end_reentry_does_not_advance_old_program() -> void:
	var manager := await _create_manager()
	var replaced := [false]
	manager.dialogue_line_end.connect(
		func(_id: String) -> void:
			if replaced[0]:
				return
			replaced[0] = true
			manager.set_shot(_compile_shot('"Kona" "new" [id=new]\nend'))
			manager.start_dialogue()
	)
	manager.set_shot(_compile_shot('"Kona" "old" [id=old]\n"Kona" "stale"\nend'))
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.WAITING)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:new", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(manager.dialogue_box.dialogue_text, "new", "line-end reentry is isolated")
	await _free_node(manager)


func _test_wait_signal_replacement_ignores_old_signal() -> void:
	var manager := await _create_manager()
	manager.set_shot(_compile_shot("waitsignal old [id=wait]\nend"))
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.WAITING)
	manager.set_shot(_compile_shot('"Kona" "replacement" [id=new]\nend'))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:new", KonadoDialogueManager.DialogState.WAITING
	)
	manager.emit_wait_signal("old")
	await process_frame
	_expect_equal(
		manager._current_instruction().stable_key(),
		"ks:id:new",
		"an old external signal cannot commit into a replacement Program",
	)
	await _free_node(manager)


func _test_voice_wait_contracts() -> void:
	var audio := KonadoAudioController.new()
	var player := AudioStreamPlayer.new()
	audio.add_child(player)
	audio.voice_player = player
	root.add_child(audio)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 8000.0
	stream.buffer_length = 0.02
	var result: Array[bool] = []
	_record_voice_result.bind(audio, stream, result).call_deferred()
	await _wait_for_condition(
		func() -> bool: return not audio._voice_waiters.is_empty(),
		"waitable voice registers its completion",
	)
	audio.stop_voice()
	await _wait_for_condition(func() -> bool: return not result.is_empty(), "voice waiter settles")
	_expect(not result[0], "waitable voice reports interruption")
	await _free_node(audio)


func _record_voice_result(
	audio: KonadoAudioController, stream: AudioStream, result: Array[bool]
) -> void:
	result.append(await audio.play_voice_and_wait(stream))


func _test_camera_cancellation_preserves_configured_offset() -> void:
	var camera := Camera2D.new()
	camera.offset = Vector2(12.0, 8.0)
	var manager := CAMERA_CONTROLLER_SCRIPT.new()
	manager.add_child(camera)
	manager.active_camera = camera
	root.add_child(manager)
	manager.shake_camera_async(1.0)
	await process_frame
	manager.cancel_pending_operations()
	_expect_equal(camera.offset, Vector2(12.0, 8.0), "camera cancellation restores base offset")
	await _free_node(manager)
