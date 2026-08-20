extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_set_shot_and_complete_dialogue()
	await _test_visibility_commands_are_atomic()
	await _test_replacement_cancels_stale_typing()
	await _test_stop_cancels_all_pending_callbacks()
	await _test_committed_variable_can_rollback_while_waiting()
	await _test_checkpoint_restores_committed_boundary()
	if _failures == 0:
		print("PASS: atomic dialogue lifecycle tests")
	quit(_failures)


func _test_set_shot_and_complete_dialogue() -> void:
	var manager := await _create_manager()
	var selected := _make_shot("selected")
	manager.set_shot(selected)
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.WAITING)
	_expect_equal(manager.start_dialogue_shot, selected, "SetShot stores the selected source")
	_expect_equal(
		manager.dialogue_box.dialogue_text,
		"selected",
		"Program dialogue reaches the dialogue box",
	)
	await _finish_current_dialogue(manager)
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.OFF)
	_expect(not manager._shot_active, "HALT closes the session exactly once")
	await _free_node(manager)


func _test_visibility_commands_are_atomic() -> void:
	var manager := await _create_manager()
	manager.set_shot(_make_visibility_shot("visibility", "Kona", "line", 0.0))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:line_visibility", KonadoDialogueManager.DialogState.WAITING
	)
	_expect(manager.dialogue_box.is_dialogue_box_visible(), "showtextbox commits first")
	await _finish_current_dialogue(manager)
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.OFF)
	_expect(
		not manager.dialogue_box.is_dialogue_box_visible(),
		"hidetextbox finishes before HALT",
	)
	_expect(manager.get_execution_history().size() >= 3, "visibility actions enter VM history")
	await _free_node(manager)


func _test_replacement_cancels_stale_typing() -> void:
	var manager := await _create_manager()
	manager.typing_interval = 1.0
	manager.set_shot(_make_shot("old text that must not finish"))
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.WAITING)
	manager.set_shot(_compile_shot('"Kona" "replacement" [id=replacement]\nend'))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:replacement", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		manager.dialogue_box.dialogue_text,
		"replacement",
		"a replaced instruction cannot publish stale text",
	)
	_expect_equal(
		manager.dialogue_box.typing_completed.get_connections().size(),
		1,
		"replacement owns one completion callback",
	)
	await _free_node(manager)


func _test_stop_cancels_all_pending_callbacks() -> void:
	var manager := await _create_manager()
	manager.typing_interval = 1.0
	manager.set_shot(_make_shot("pending"))
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.WAITING)
	manager.stop_dialogue()
	_expect_equal(manager.dialogue_state, KonadoDialogueManager.DialogState.OFF, "stop is final")
	_expect(manager._active_token.is_empty(), "stop invalidates the active transaction")
	_expect_equal(manager._pending_connections.size(), 0, "stop disconnects awaited signals")
	_expect_equal(
		manager.dialogue_box.typing_completed.get_connections().size(),
		0,
		"stop disconnects the typewriter callback",
	)
	await _free_node(manager)


func _test_committed_variable_can_rollback_while_waiting() -> void:
	var manager := await _create_manager()
	var source := 'set $score = 7 [id=set_score]\n"Kona" "pause" [id=pause]\nend'
	manager.set_shot(_compile_shot(source))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:pause", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(manager._temp_variables.get("score"), 7, "variable instruction committed")
	_expect(manager.can_rollback(), "waiting transaction can be cancelled for rollback")
	_expect(manager.rollback(), "rollback restores the previous committed boundary")
	await process_frame
	_expect_equal(
		manager._temp_variables.get("score"),
		7,
		"rollback resumes by deterministically re-executing the restored instruction",
	)
	await _free_node(manager)


func _test_checkpoint_restores_committed_boundary() -> void:
	var manager := await _create_manager()
	(
		manager
		. set_shot(
			_compile_shot(
				'set $score = 1\n"Kona" "first" [id=first]\nset $score = 2\n"Kona" "second" [id=second]\nend',
				"",
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:first", KonadoDialogueManager.DialogState.WAITING
	)
	var checkpoint := manager.create_checkpoint("first-line")
	_expect(not checkpoint.is_empty(), "checkpoint is created at a valid instruction")
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:second", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(manager._temp_variables.get("score"), 2, "execution advances after checkpoint")
	_expect(manager.restore_checkpoint(checkpoint), "checkpoint restore succeeds")
	await _wait_for_instruction_and_state(
		manager, "ks:id:first", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(manager._temp_variables.get("score"), 1, "checkpoint restores logical state")
	await _free_node(manager)
