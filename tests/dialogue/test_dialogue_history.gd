extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_records_committed_lines_in_order()
	await _test_pending_entry_is_exposed_before_advance()
	await _test_clear_resets_committed_and_pending()
	await _test_history_is_bounded()
	await _test_stop_discards_pending_entry()
	await _test_rollback_keeps_history_in_sync()
	await _test_panel_renders_committed_entries()
	await _test_records_choice_options_and_selection()
	await _test_records_screen_text_lines()
	await _test_keep_policy_preserves_history()
	if _failures == 0:
		print("PASS: dialogue history tests")
	quit(_failures)


func _test_records_committed_lines_in_order() -> void:
	var manager := await _create_manager()
	manager.set_shot(
		_compile_shot(
			(
				'"Kona" "one" [id=one]\n'
				+ '"Kona" "two" [id=two]\n'
				+ '"Kona" "three" [id=three]\n'
				+ "end"
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:one", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:two", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:three", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.OFF)
	var history := manager.dialogue_history.entries(0, false)
	_expect_equal(history.size(), 3, "every advanced dialogue line is recorded once")
	_expect_equal(history[0]["text"], "one", "first line text")
	_expect_equal(history[1]["text"], "two", "second line text")
	_expect_equal(history[2]["text"], "three", "third line text")
	_expect_equal(history[0]["speaker"], "Kona", "speaker is resolved for history")
	_expect_equal(history[2]["instruction_id"], "ks:id:three", "stable instruction id is kept")
	_expect(history[0]["serial"] < history[1]["serial"], "serial increases per commit")
	_expect(history[1]["serial"] < history[2]["serial"], "serial increases per commit")
	await _free_node(manager)


func _test_pending_entry_is_exposed_before_advance() -> void:
	var manager := await _create_manager()
	manager.set_shot(_make_shot("solo"))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:start", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(manager.dialogue_history.size(), 0, "pending line is not committed yet")
	var pending := manager.dialogue_history.entries(0, true)
	_expect_equal(pending.size(), 1, "pending line is exposed for the backlog UI")
	_expect(bool(pending[0].get("pending", false)), "pending line is marked as pending")
	_expect_equal(pending[0]["text"], "solo", "pending line keeps its displayed text")
	await _finish_current_dialogue(manager)
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.OFF)
	_expect_equal(manager.dialogue_history.size(), 1, "advancing commits the line")
	await _free_node(manager)


func _test_clear_resets_committed_and_pending() -> void:
	var manager := await _create_manager()
	manager.set_shot(_make_shot("clear me"))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:start", KonadoDialogueManager.DialogState.WAITING
	)
	manager.dialogue_history.clear()
	_expect_equal(
		manager.dialogue_history.entries(0, true).size(),
		0,
		"clear drops pending and committed",
	)
	await _finish_current_dialogue(manager)
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.OFF)
	_expect_equal(manager.dialogue_history.size(), 0, "cleared line cannot commit on advance")
	await _free_node(manager)


func _test_history_is_bounded() -> void:
	var manager := await _create_manager()
	manager.max_dialogue_history_entries = 2
	manager.set_shot(
		_compile_shot(
			(
				'"Kona" "one" [id=one]\n'
				+ '"Kona" "two" [id=two]\n'
				+ '"Kona" "three" [id=three]\n'
				+ "end"
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:one", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:two", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:three", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.OFF)
	var history := manager.dialogue_history.entries(0, false)
	_expect_equal(history.size(), 2, "history respects max_entries")
	_expect_equal(history[0]["text"], "two", "oldest committed entry is evicted")
	_expect_equal(history[1]["text"], "three", "newest committed entry is retained")
	await _free_node(manager)


func _test_stop_discards_pending_entry() -> void:
	var manager := await _create_manager()
	manager.set_shot(_make_shot("cancelled"))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:start", KonadoDialogueManager.DialogState.WAITING
	)
	manager.stop_dialogue()
	await process_frame
	_expect_equal(
		manager.dialogue_history.entries(0, true).size(), 0, "stopping discards the pending line"
	)
	await _free_node(manager)


func _test_rollback_keeps_history_in_sync() -> void:
	var manager := await _create_manager()
	manager.set_shot(
		_compile_shot('"Kona" "one" [id=one]\nset $n = 1 [id=set]\n"Kona" "two" [id=two]\nend')
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:one", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:two", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		manager.dialogue_history.entries(0, false).size(),
		1,
		"committed dialogue is recorded before the following variable",
	)
	_expect(manager.rollback(), "rollback of a non-dialogue commit is allowed")
	await _wait_for_instruction_and_state(
		manager, "ks:id:two", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		manager.dialogue_history.entries(0, false).size(),
		1,
		"rollback of a non-dialogue commit keeps committed dialogue",
	)
	_expect(manager.rollback(2), "rollback across the dialogue commit is allowed")
	await _wait_for_instruction_and_state(
		manager, "ks:id:one", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		manager.dialogue_history.entries(0, false).size(),
		0,
		"rolling back the dialogue commit trims the history",
	)
	await _free_node(manager)


func _test_panel_renders_committed_entries() -> void:
	var manager := await _create_manager()
	manager.set_shot(_make_shot("panel line"))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:start", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.OFF)
	var panel := manager.backlog_panel
	_expect(panel != null, "default template exposes a backlog panel")
	if panel != null:
		panel.open_panel()
		_expect(panel.visible, "backlog panel opens")
		_expect_equal(
			panel.entry_container.get_child_count(), 1, "backlog panel renders committed entry"
		)
		_expect(not panel.empty_label.visible, "empty hint is hidden when entries exist")
		panel.close_panel()
		_expect(not panel.visible, "backlog panel closes")
	await _free_node(manager)


func _test_records_choice_options_and_selection() -> void:
	var manager := await _create_manager()
	manager.set_shot(
		_compile_shot(
			(
				'"Kona" "pick" [id=ask]\n'
				+ 'choice "Tea" -> tea [id=drink]\n'
				+ 'choice "Coffee" -> coffee\n'
				+ "branch tea\n"
				+ '\t"Kona" "tea" [id=tea_line]\n'
				+ "\tend\n"
				+ "branch coffee\n"
				+ '\t"Kona" "coffee" [id=coffee_line]\n'
				+ "\tend"
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:ask", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:drink", KonadoDialogueManager.DialogState.WAITING
	)
	var options: Array = manager._current_instruction().value(&"options", [])
	_expect_equal(options.size(), 2, "choice instruction exposes both options")
	manager._on_option_triggered(options[1], manager._playback_generation)
	await _wait_for_instruction_and_state(
		manager, "ks:id:coffee_line", KonadoDialogueManager.DialogState.WAITING
	)
	var history := manager.dialogue_history.entries(0, false)
	_expect_equal(history.size(), 2, "dialogue and choice are both recorded")
	_expect_equal(history[0]["kind"], "dialogue", "first entry is a dialogue line")
	_expect_equal(history[1]["kind"], "choice", "second entry is a choice")
	_expect_equal(history[1]["text"], "Coffee", "the selected option is recorded")
	var recorded_options: Array = history[1]["options"]
	_expect_equal(recorded_options.size(), 2, "every presented option is recorded")
	_expect_equal(String(recorded_options[0]), "Tea", "first option text is recorded")
	_expect_equal(String(recorded_options[1]), "Coffee", "second option text is recorded")
	var panel := manager.backlog_panel
	if panel != null:
		panel.refresh()
		_expect_equal(
			panel.entry_container.get_child_count(),
			3,
			"backlog panel renders two committed entries plus the pending line",
		)
	await _free_node(manager)


func _test_records_screen_text_lines() -> void:
	var manager := await _create_manager()
	manager.screen_text.fade_duration = 0.0
	manager.screen_text.line_fade_duration = 0.0
	manager.set_shot(
		_compile_shot(
			(
				'screentext {\n    "First"\n    "Second"\n} [id=overlay]\n'
				+ '"Kona" "After" [id=after]\nend'
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:overlay", KonadoDialogueManager.DialogState.WAITING
	)
	await _wait_for_condition(
		func() -> bool: return manager.screen_text._is_waiting_input,
		"screen text waits for input",
	)
	manager.screen_text.skip_display()
	await _wait_for_instruction_and_state(
		manager, "ks:id:after", KonadoDialogueManager.DialogState.WAITING
	)
	var history := manager.dialogue_history.entries(0, false)
	_expect_equal(history.size(), 1, "screen text is recorded once")
	_expect_equal(history[0]["kind"], "screen_text", "entry kind is screen_text")
	_expect_equal(history[0]["text"], "First\nSecond", "screen text joins every line")
	var recorded_lines: Array = history[0]["lines"]
	_expect_equal(recorded_lines.size(), 2, "every screen text line is recorded")
	_expect_equal(String(recorded_lines[0]), "First", "first screen text line")
	_expect_equal(String(recorded_lines[1]), "Second", "second screen text line")
	var panel := manager.backlog_panel
	if panel != null:
		panel.refresh()
		_expect_equal(
			panel.entry_container.get_child_count(),
			2,
			"backlog panel renders the screen text block and the pending line",
		)
	await _free_node(manager)


func _test_keep_policy_preserves_history() -> void:
	var manager := await _create_manager()
	manager.dialogue_history.rollback_policy = (KonadoDialogueHistory.RollbackPolicy.KEEP)
	manager.set_shot(
		_compile_shot('"Kona" "one" [id=one]\nset $n = 1 [id=set]\n"Kona" "two" [id=two]\nend')
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:one", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:two", KonadoDialogueManager.DialogState.WAITING
	)
	_expect(manager.rollback(2), "rollback across the dialogue commit is allowed")
	await _wait_for_instruction_and_state(
		manager, "ks:id:one", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		manager.dialogue_history.entries(0, false).size(),
		1,
		"the KEEP policy retains committed dialogue after a rollback",
	)
	_expect_equal(
		manager.dialogue_history.entries(0, false)[0]["text"],
		"one",
		"the retained entry keeps its recorded text",
	)
	await _free_node(manager)
