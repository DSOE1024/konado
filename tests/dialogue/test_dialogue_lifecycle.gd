extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"


class VariableConfigHost:
	extends Control

	var manager: KonadoDialogueManager

	func _ready() -> void:
		manager.variable_store.set_value("love", 0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_auto_start_waits_for_parent_configuration()
	await _test_missing_condition_variable_reports_its_name()
	await _test_nested_condition_choice_reaches_branch()
	await _test_set_shot_and_complete_dialogue()
	await _test_visibility_commands_are_atomic()
	await _test_screen_text_completion_lifecycle()
	await _test_replacement_clears_pending_screen_text()
	await _test_replacement_cancels_stale_typing()
	await _test_stop_cancels_all_pending_callbacks()
	await _test_committed_variable_can_rollback_while_waiting()
	await _test_checkpoint_restores_committed_boundary()
	if _failures == 0:
		print("PASS: atomic dialogue lifecycle tests")
	quit(_failures)


func _test_auto_start_waits_for_parent_configuration() -> void:
	var host := VariableConfigHost.new()
	var manager := DIALOGUE_MANAGER_SCENE.instantiate() as KonadoDialogueManager
	manager.require_visible_in_tree = false
	manager.enable_overlay_log = false
	manager.auto_show_dialogue_box = false
	manager.typing_interval = 0.001
	manager.dialogue_box.enable_typing_effect_audio = false
	manager.start_dialogue_shot = _compile_shot(
		(
			"if %love <= 0:\n"
			+ '\t"Kona" "configured" [id=configured]\n'
			+ "else:\n"
			+ '\t"Kona" "wrong" [id=wrong]\n'
			+ "endif\nend"
		)
	)
	host.manager = manager
	host.add_child(manager)
	root.add_child(host)
	await _wait_for_instruction_and_state(
		manager, "ks:id:configured", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		manager.dialogue_box.dialogue_text,
		"configured",
		"automatic playback observes variables configured by the parent ready callback",
	)
	await _free_node(host)


func _test_missing_condition_variable_reports_its_name() -> void:
	var manager := await _create_manager()
	manager.set_shot(_compile_shot("if %missing == 1:\n\tend\nendif"))
	var result := manager._executor._condition_target(manager, manager._current_instruction())
	_expect(not bool(result.get("ok", false)), "an undefined condition variable is rejected")
	_expect(
		String(result.get("reason", "")).contains("%missing"),
		"condition diagnostics identify the undefined variable instead of only naming the opcode",
	)
	await _free_node(manager)


func _test_nested_condition_choice_reaches_branch() -> void:
	var manager := await _create_manager()
	manager.set_shot(
		_compile_shot(
			(
				'choice "Right" -> right [id=main_choice]\n'
				+ "branch right\n"
				+ "\tset $right = 5\n"
				+ "\tif $right == 5:\n"
				+ '\t\tchoice "Back" -> no [id=nested_choice]\n'
				+ "\tendif\n"
				+ "\tend\n"
				+ "branch no\n"
				+ '\t"Kona" "returned" [id=returned]\n'
				+ "\tend"
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:main_choice", KonadoDialogueManager.DialogState.WAITING
	)
	var main_option: Dictionary = manager._current_instruction().value(&"options")[0]
	manager._on_option_triggered(main_option, manager._playback_generation)
	await _wait_for_instruction_and_state(
		manager, "ks:id:nested_choice", KonadoDialogueManager.DialogState.WAITING
	)
	var nested_option: Dictionary = manager._current_instruction().value(&"options")[0]
	manager._on_option_triggered(nested_option, manager._playback_generation)
	await _wait_for_instruction_and_state(
		manager, "ks:id:returned", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		manager.dialogue_box.dialogue_text,
		"returned",
		"a choice nested in a conditional branch resolves its compiled target",
	)
	await _free_node(manager)


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


func _test_screen_text_completion_lifecycle() -> void:
	var manager := await _create_manager()
	manager.screen_text.fade_duration = 0.0
	manager.screen_text.line_fade_duration = 0.0
	var events: Array[String] = []
	manager.screen_text.display_finished.connect(func() -> void: events.append("display_finished"))
	manager.screen_text.screen_text_hidden.connect(
		func() -> void: events.append("screen_text_hidden")
	)
	manager.set_shot(
		_compile_shot(
			(
				'screentext {\n    "Opening"\n} [id=overlay]\n'
				+ '"Kona" "After overlay" [id=after_overlay]\nend'
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:overlay", KonadoDialogueManager.DialogState.WAITING
	)
	await _wait_for_condition(
		func() -> bool: return manager.screen_text._is_waiting_input,
		"screen text waits for the final acknowledgement",
	)
	manager.screen_text._on_click_advance()
	manager.screen_text.skip_display()
	manager.screen_text.skip_display()
	await _wait_for_instruction_and_state(
		manager, "ks:id:after_overlay", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		events,
		["display_finished", "screen_text_hidden"],
		"screen text completes and hides exactly once before the next instruction",
	)
	_expect(not manager.screen_text.visible, "the following instruction starts without an overlay")
	await _finish_current_dialogue(manager)
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.OFF)

	manager.screen_text.next_line_indicator = null
	manager.screen_text.display(["Manual overlay"])
	await _wait_for_condition(
		func() -> bool: return manager.screen_text._is_waiting_input,
		"screen text remains interactive without an optional next-line indicator",
	)
	manager.screen_text._on_click_advance()
	await process_frame
	_expect(manager.screen_text.visible, "direct display calls keep their existing visible default")
	_expect_equal(events.count("display_finished"), 2, "direct display completion emits once")
	_expect_equal(events.count("screen_text_hidden"), 1, "direct display does not auto-hide")
	manager.screen_text.hide_screen_text()
	manager.screen_text.show_screen_text()
	await process_frame
	manager.screen_text.hide_screen_text()
	await _wait_for_condition(
		func() -> bool: return not manager.screen_text.visible,
		"an interrupted hide can be shown again and hidden explicitly",
	)
	await _free_node(manager)


func _test_replacement_clears_pending_screen_text() -> void:
	var manager := await _create_manager()
	manager.screen_text.fade_duration = 0.0
	manager.screen_text.line_fade_duration = 0.0
	manager.set_shot(_compile_shot('screentext {\n    "Old overlay"\n}\nend'))
	manager.start_dialogue()
	await _wait_for_condition(
		func() -> bool: return manager.screen_text._is_waiting_input,
		"the original screen text starts before replacement",
	)
	manager.set_shot(_compile_shot('"Kona" "Replacement" [id=replacement]\nend'))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:replacement", KonadoDialogueManager.DialogState.WAITING
	)
	_expect(
		not manager.screen_text.visible,
		"replacing a shot clears its uncommitted screen text overlay",
	)
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
