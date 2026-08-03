extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_set_shot_initialization()
	await _test_set_shot_localization_fallback()
	await _test_dialogue_box_transitions(KND_DialogueBox.TypewriterMode.TRADITIONAL)
	await _test_dialogue_box_transitions(KND_DialogueBox.TypewriterMode.FADE_IN_TYPEWRITER)
	await _test_immediate_dialogue_content(KND_DialogueBox.TypewriterMode.TRADITIONAL)
	await _test_immediate_dialogue_content(KND_DialogueBox.TypewriterMode.FADE_IN_TYPEWRITER)
	await _test_consecutive_dialogue_lines()
	await _test_restart_during_fade()
	await _test_restart_disconnects_stale_typing_callback()
	await _test_stale_typing_callback_cannot_hide_replacement_connection()
	await _test_stop_fades_and_clears_content_once()
	await _test_hide_textbox(0.0)
	await _test_hide_textbox(0.01)
	await _test_implicit_end_restarts_without_stale_content()
	await _test_stale_autoplay_timer_cannot_advance_new_shot()
	await _test_manual_advance_invalidates_pending_autoplay_for_node()
	await _test_disabling_autoplay_cancels_pending_advance()
	await _test_reinitialization_disconnects_action_callbacks()
	await _test_manager_exit_invalidates_delayed_callbacks()
	await _test_line_start_reentry_cannot_execute_replaced_command()
	await _test_line_end_reentry_cannot_continue_previous_flow()
	await _test_line_end_cannot_reenter_current_advance()
	await _test_skipping_typing_emits_line_end_once()
	await _test_screen_text_hide_cancels_pending_display()
	await _test_screen_text_replacement_cancels_previous_activity()
	await _test_destroyed_choice_button_callback_is_safe()
	await _test_shot_end_can_stop_a_replacement_shot()
	await _test_hide_then_show_preserves_content()
	if _failures == 0:
		print("PASS: dialogue lifecycle tests")
	quit(_failures)


func _test_set_shot_initialization() -> void:
	var manager := await _create_manager()
	var configured := _make_shot("configured")
	var selected := _make_shot("selected")
	manager.start_dialogue_shot = configured
	manager.set_shot(selected)
	manager.init_dialogue()

	_expect(
		manager.start_dialogue_shot == selected,
		"set_shot stores the selected shot as the initialization source",
	)
	_expect_equal(
		manager.cur_dialogue_shot.dialogues[0].dialog_content,
		"selected",
		"SetShot -> InitDialogue preserves the selected shot",
	)
	await _free_node(manager)


func _test_set_shot_localization_fallback() -> void:
	var i18n := root.get_node_or_null("KND_I18n")
	_expect(i18n != null, "KND_I18n is available for localized SetShot")
	if i18n == null:
		return
	var log_path := ProjectSettings.globalize_path(KND_Logger.LOG_FILE_PATH)
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	var original_locale: String = i18n.get_locale()
	i18n.set_locale("zh_Hans", false)

	var manager := DIALOGUE_MANAGER_SCENE.instantiate() as KND_DialogueManager
	manager.init_onstart = false
	manager.check_visable = false
	manager.enable_overlay_log = true
	manager._konado_dialogue_box.enable_typing_effect_audio = false
	root.add_child(manager)
	for _frame in range(5):
		await process_frame

	var warning_capture := WarningCapture.new()
	OS.add_logger(warning_capture)
	var source_path := "res://tests/i18n/fixtures/story.ks"
	var shot := load(source_path) as KND_Shot
	manager.set_shot(shot)
	await process_frame
	await process_frame

	_expect(manager.start_dialogue_shot != null, "SetShot loads the default script fallback")
	if manager.start_dialogue_shot != null:
		_expect_equal(
			manager.start_dialogue_shot.ks_path,
			source_path,
			"SetShot preserves the default script when no localized variant exists",
		)
	_expect_equal(
		warning_capture.fallback_warnings.size(),
		0,
		"automatic SetShot localization does not warn for a normal default-script fallback",
	)
	_expect(
		not manager.error_tooltip_panel.visible,
		"automatic localization fallback does not open the runtime error overlay",
	)
	_expect(
		not _read_text_file(log_path).contains("KND_I18n:"),
		"automatic localization fallback does not pollute the persistent log",
	)

	var diagnostic_shot: KND_Shot = i18n.load_localized_script(source_path, "zh_Hans", true)
	await process_frame
	await process_frame
	_expect(
		diagnostic_shot != null, "explicit fallback diagnostics still return the default script"
	)
	_expect_equal(
		warning_capture.fallback_warnings.size(),
		1,
		"developers can still request an explicit localization fallback warning",
	)
	_expect(
		not manager.error_tooltip_panel.visible,
		"nonfatal warnings are not presented as broken runtime errors",
	)
	var warning_log := _read_text_file(log_path)
	_expect(
		warning_log.contains("Konado runtime warning."),
		"nonfatal warnings retain their warning severity in the persistent log",
	)
	_expect(
		warning_log.contains("KND_I18n:"),
		"explicit localization fallback warnings remain available in the persistent log",
	)
	OS.remove_logger(warning_capture)
	i18n.set_locale(original_locale, false)
	await _free_node(manager)
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)


func _read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _test_dialogue_box_transitions(mode: int) -> void:
	var box := DIALOGUE_BOX_SCENE.instantiate() as KND_DialogueBox
	box.typewriter_mode = mode
	box.fade_duration = 0.01
	box.enable_typing_effect_audio = false
	root.add_child(box)
	await process_frame
	var typing_completion_count := [0]
	box.typing_completed.connect(func() -> void: typing_completion_count[0] += 1)

	box.show_dialogue_box(func() -> void: box.dialogue_text = "first")
	await create_timer(0.04).timeout
	_expect(box.is_dialogue_box_visible(), "show marks the dialogue box as visible")

	box.hide_dialogue_box()
	await create_timer(0.04).timeout
	_expect(not box.is_dialogue_box_visible(), "fade-out marks the dialogue box as hidden")
	_expect(not box.visible, "fade-out hides the dialogue box")
	if mode == KND_DialogueBox.TypewriterMode.FADE_IN_TYPEWRITER:
		_expect(not box.typewriter_text.is_playing(), "fade-out stops hidden typewriter playback")

	box.show()
	_expect(box.is_dialogue_box_visible(), "direct Control.show remains compatible")
	box.hide_dialogue_box_with_duration(0.0)
	_expect(not box.is_dialogue_box_visible(), "the API can hide a directly shown dialogue box")

	box.show_dialogue_box(func() -> void: box.dialogue_text = "second")
	await create_timer(0.04).timeout
	_expect(box.is_dialogue_box_visible(), "a hidden dialogue box can be shown again")
	_expect(box.character_name_label.visible, "show restores the character name")
	if mode == KND_DialogueBox.TypewriterMode.FADE_IN_TYPEWRITER:
		_expect(box.typewriter_text.visible, "show restores fade typewriter text")
		_expect(
			not box.dialogue_label.visible, "fade typewriter mode keeps the legacy label hidden"
		)
	else:
		_expect(box.dialogue_label.visible, "show restores traditional dialogue text")
		_expect_equal(box.dialogue_label.text, "second", "show updates traditional dialogue text")
	box.skip_typing_anim()
	await process_frame
	_expect_equal(
		typing_completion_count[0],
		1,
		"skipping a typewriter animation emits completion exactly once",
	)

	await _free_node(box)


func _test_immediate_dialogue_content(mode: int) -> void:
	var box := DIALOGUE_BOX_SCENE.instantiate() as KND_DialogueBox
	box.typewriter_mode = mode as KND_DialogueBox.TypewriterMode
	box.typing_interval = 1.0
	box.enable_typing_effect_audio = false
	root.add_child(box)
	await process_frame
	var completion_count := [0]
	box.typing_completed.connect(func() -> void: completion_count[0] += 1)
	box.dialogue_text = "Animated"
	box.set_dialogue_content_immediately("Localized")
	await process_frame
	await process_frame

	_expect_equal(box.dialogue_text, "Localized", "immediate content replaces the active text")
	if mode == KND_DialogueBox.TypewriterMode.FADE_IN_TYPEWRITER:
		_expect(
			not box.typewriter_text.is_playing(),
			"immediate fade-typewriter content is fully displayed without playback",
		)
	else:
		_expect_equal(
			box.dialogue_label.visible_ratio,
			1.0,
			"immediate traditional content is fully visible",
		)
	_expect_equal(
		completion_count[0],
		0,
		"immediate content does not emit a synthetic typing completion",
	)
	await _free_node(box)


func _test_consecutive_dialogue_lines() -> void:
	var manager := await _create_manager()
	var first := _make_dialogue("first", "first")
	var second := _make_dialogue("second", "second")
	first.next_id = second.node_id
	manager.start_dialogue_shot = _make_shot_from_dialogues([first, second])
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)
	manager._process_next()
	await create_timer(0.06).timeout

	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		"second",
		"consecutive dialogue lines update an already visible dialogue box",
	)
	await _free_node(manager)


func _test_restart_during_fade() -> void:
	var manager := await _create_manager()
	manager.start_dialogue_shot = _make_shot("first")
	manager.init_dialogue()
	manager.start_dialogue()
	await create_timer(0.06).timeout

	manager.stop_dialogue()
	manager.start_dialogue_shot = _make_shot("second")
	manager.init_dialogue()
	manager.start_dialogue()
	await create_timer(0.08).timeout

	_expect(
		manager._konado_dialogue_box.is_dialogue_box_visible(),
		"restart cancels an unfinished fade-out and shows the dialogue box",
	)
	_expect(
		manager._konado_dialogue_box.dialogue_label.visible,
		"restart restores the dialogue label",
	)
	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		"second",
		"restart loads the new dialogue text",
	)
	await _free_node(manager)


func _test_restart_disconnects_stale_typing_callback() -> void:
	var manager := await _create_manager()
	manager._typing_interval = 1.0
	manager.start_dialogue_shot = _make_shot("first")
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_typing_connection_count(
		manager,
		1,
		"the active line owns exactly one typing completion callback",
	)

	manager.stop_dialogue()
	_expect_equal(
		manager._konado_dialogue_box.typing_completed.get_connections().size(),
		0,
		"stopping dialogue disconnects the previous line callback",
	)
	manager.start_dialogue_shot = _make_shot("second")
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_typing_connection_count(
		manager,
		1,
		"restarting dialogue does not accumulate typing callbacks",
	)
	await _free_node(manager)


func _test_stale_typing_callback_cannot_hide_replacement_connection() -> void:
	var manager := await _create_manager()
	manager._playback_generation = 2
	manager._shot_active = true
	var replacement_callback := func() -> void: pass
	manager._typing_completed_callback = replacement_callback
	manager._konado_dialogue_box.typing_completed.connect(replacement_callback)

	(
		manager
		. isfinishtyping(
			false,
			0.0,
			1,
			manager._node_generation,
			manager.cur_node_id,
		)
	)
	_expect_equal(
		manager._typing_completed_callback,
		replacement_callback,
		"a stale typing callback cannot erase replacement callback bookkeeping",
	)
	manager._invalidate_playback_callbacks()
	_expect(
		not manager._konado_dialogue_box.typing_completed.is_connected(replacement_callback),
		"replacement typing callbacks remain disconnectable after stale signal reentry",
	)
	await _free_node(manager)


func _test_stop_fades_and_clears_content_once() -> void:
	var manager := await _create_manager()
	var shot_end_count := [0]
	var shot_start_count := [0]
	manager.shot_end.connect(func() -> void: shot_end_count[0] += 1)
	manager.shot_start.connect(func() -> void: shot_start_count[0] += 1)
	manager.start_dialogue_shot = _make_shot("content to clear")
	manager.init_dialogue()
	manager.start_dialogue()
	manager.start_dialogue()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)

	manager.stop_dialogue()
	manager.stop_dialogue()
	_expect_equal(shot_start_count[0], 1, "repeated StartDialogue starts an active shot only once")
	_expect(
		manager._konado_dialogue_box.visible,
		"stopping keeps the dialogue box mounted while its fade-out is running",
	)
	await create_timer(0.05).timeout
	_expect_equal(shot_end_count[0], 1, "repeated StopDialogue emits shot_end only once")
	_expect(
		not manager._konado_dialogue_box.visible,
		"the dialogue box is hidden after the stop fade completes",
	)
	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		"",
		"the completed stop fade clears the previous shot text",
	)
	_expect_equal(
		manager._konado_dialogue_box.character_name,
		"",
		"the completed stop fade clears the previous shot speaker",
	)
	await _free_node(manager)


func _test_hide_textbox(duration: float) -> void:
	var manager := await _create_manager()
	var first := _make_dialogue("first", "first")
	var hide := KND_Dialogue.new()
	hide.dialog_type = KND_Dialogue.Type.HIDE_TEXTBOX
	hide.node_id = "hide"
	hide.next_id = "second"
	hide.textbox_duration = duration
	var second := _make_dialogue("second", "second")
	first.next_id = hide.node_id
	manager.start_dialogue_shot = _make_shot_from_dialogues([first, hide, second])
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)
	manager._process_next()
	await create_timer(0.08).timeout

	_expect_equal(
		manager.cur_node_id,
		"second",
		"hidetextbox advances to the following dialogue",
	)
	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		"second",
		"the dialogue following hidetextbox updates its text",
	)
	_expect(
		manager._konado_dialogue_box.dialogue_label.visible,
		"the dialogue following hidetextbox restores the dialogue label",
	)
	await _free_node(manager)


func _test_implicit_end_restarts_without_stale_content() -> void:
	var manager := await _create_manager()
	manager._konado_dialogue_box.fade_duration = 0.08
	var first_shot := _make_visibility_shot("first", "Old actor", "Old script text", 0.02)
	var second_shot := _make_visibility_shot("second", "New actor", "New script text", 0.08)
	var shot_end_count := [0]
	var restarted := [false]
	manager.shot_end.connect(
		func() -> void:
			shot_end_count[0] += 1
			# 用户代码可能会在结束回调中再次调用 StopDialogue；该调用必须安全且无重复信号。
			manager.stop_dialogue()
			if shot_end_count[0] == 1:
				manager.set_shot(second_shot)
				manager.init_dialogue()
				manager.start_dialogue()
				restarted[0] = true
	)

	manager.start_dialogue_shot = first_shot
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_node_and_state(manager, "line_first", KND_DialogueManager.DialogState.PAUSED)
	manager._process_next()
	await _wait_for_condition(
		func() -> bool: return restarted[0],
		"an implicit script ending emits shot_end and permits a restart from its handler",
	)
	await process_frame

	_expect_equal(shot_end_count[0], 1, "reentrant StopDialogue emits shot_end only once")
	_expect(
		manager._konado_dialogue_box.dialogue_text != "Old script text",
		"the next shot never exposes the previous shot text while its textbox fades in",
	)
	_expect(
		manager._konado_dialogue_box.character_name != "Old actor",
		"the next shot never exposes the previous shot speaker while its textbox fades in",
	)
	await _wait_for_node_and_state(manager, "line_second", KND_DialogueManager.DialogState.PAUSED)
	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		"New script text",
		"the restarted shot displays its own text",
	)
	_expect_equal(
		manager._konado_dialogue_box.character_name,
		"New actor",
		"the restarted shot displays its own speaker",
	)
	await _free_node(manager)


func _test_stale_autoplay_timer_cannot_advance_new_shot() -> void:
	var manager := await _create_manager()
	manager.autoplay = true
	manager.autoplayspeed = 0.12
	manager.start_dialogue_shot = _make_shot("old autoplay line")
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)

	manager.autoplay = false
	var new_first := _make_dialogue("new_first", "new first")
	var new_second := _make_dialogue("new_second", "new second")
	new_first.next_id = new_second.node_id
	manager.set_shot(_make_shot_from_dialogues([new_first, new_second]))
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_node_and_state(manager, "new_first", KND_DialogueManager.DialogState.PAUSED)
	await create_timer(0.18).timeout

	_expect_equal(
		manager.cur_node_id,
		"new_first",
		"an autoplay timer created by the previous shot cannot advance the replacement shot",
	)
	await _free_node(manager)


func _test_manual_advance_invalidates_pending_autoplay_for_node() -> void:
	var manager := await _create_manager()
	manager.autoplay = true
	manager.autoplayspeed = 0.12
	var first := _make_dialogue("first", "first")
	var second := _make_dialogue("second", "second")
	first.next_id = second.node_id
	manager.start_dialogue_shot = _make_shot_from_dialogues([first, second])
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_node_and_state(manager, first.node_id, KND_DialogueManager.DialogState.PAUSED)

	manager._typing_interval = 1.0
	manager._process_next()
	await _wait_for_condition(
		func() -> bool:
			return (
				manager.cur_node_id == second.node_id
				and manager.dialogue_state == KND_DialogueManager.DialogState.PLAYING
				and manager._konado_dialogue_box.typing_tween != null
				and manager._konado_dialogue_box.typing_tween.is_running()
			),
		"manual advance starts the next node before the previous autoplay timer expires",
	)
	await create_timer(0.18).timeout

	_expect_equal(
		manager.cur_node_id,
		second.node_id,
		"the previous node autoplay timer cannot advance a manually entered node",
	)
	_expect_equal(
		manager.dialogue_state,
		KND_DialogueManager.DialogState.PLAYING,
		"the previous node autoplay timer cannot skip the new node's typewriter",
	)
	_expect(
		(
			manager._konado_dialogue_box.typing_tween != null
			and manager._konado_dialogue_box.typing_tween.is_running()
		),
		"the manually entered node keeps typing after the stale timer deadline",
	)
	await _free_node(manager)


func _test_disabling_autoplay_cancels_pending_advance() -> void:
	var manager := await _create_manager()
	manager.autoplay = true
	manager.autoplayspeed = 0.12
	var first := _make_dialogue("first", "first")
	var second := _make_dialogue("second", "second")
	first.next_id = second.node_id
	manager.start_dialogue_shot = _make_shot_from_dialogues([first, second])
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)

	manager.start_autoplay(false)
	await create_timer(0.18).timeout

	_expect_equal(
		manager.cur_node_id,
		"first",
		"disabling autoplay cancels a pending advance in the current shot",
	)
	await _free_node(manager)


func _test_reinitialization_disconnects_action_callbacks() -> void:
	var manager := await _create_manager()
	var show := KND_Dialogue.new()
	show.dialog_type = KND_Dialogue.Type.SHOW_TEXTBOX
	show.node_id = "old_show"
	show.textbox_duration = 1.0
	manager.start_dialogue_shot = _make_shot_from_dialogues([show])
	manager.init_dialogue()
	manager.start_dialogue()
	await process_frame
	await process_frame

	var new_first := _make_dialogue("replacement", "replacement")
	var new_second := _make_dialogue("replacement_next", "replacement next")
	new_first.next_id = new_second.node_id
	manager.set_shot(_make_shot_from_dialogues([new_first, new_second]))
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_node_and_state(manager, "replacement", KND_DialogueManager.DialogState.PAUSED)
	manager._konado_dialogue_box.on_dialogue_show_completed.emit()
	await process_frame

	_expect_equal(
		manager.cur_node_id,
		"replacement",
		"a completion signal from a cancelled action cannot advance the replacement shot",
	)
	await _free_node(manager)


func _test_manager_exit_invalidates_delayed_callbacks() -> void:
	var capture := RuntimeErrorCapture.new()
	OS.add_logger(capture)
	var manager := await _create_manager()
	manager.autoplay = true
	manager.autoplayspeed = 0.05
	manager.start_dialogue_shot = _make_shot("delayed")
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)
	manager.queue_free()
	await process_frame
	await create_timer(0.08).timeout
	OS.remove_logger(capture)

	_expect_equal(
		capture.errors,
		[],
		"delayed playback callbacks never access a dialogue manager after it leaves the tree",
	)


func _test_line_start_reentry_cannot_execute_replaced_command() -> void:
	var manager := await _create_manager()
	var old_screen_text := KND_Dialogue.new()
	old_screen_text.dialog_type = KND_Dialogue.Type.SCREEN_TEXT
	old_screen_text.node_id = "old_screen_text"
	old_screen_text.text_content = ["stale screen text"]
	var replacement := _make_shot("replacement")
	manager.dialogue_line_start.connect(
		func(node_id: String) -> void:
			if node_id != "old_screen_text":
				return
			manager.set_shot(replacement)
			manager.init_dialogue()
			manager.start_dialogue()
	)
	manager.start_dialogue_shot = _make_shot_from_dialogues([old_screen_text])
	manager.init_dialogue()
	manager.start_dialogue()
	await create_timer(0.08).timeout

	_expect(
		not manager._screen_text.visible,
		"a command replaced from dialogue_line_start cannot mutate the replacement shot UI",
	)
	_expect_equal(
		manager.cur_node_id,
		"start",
		"dialogue_line_start replacement remains on the replacement shot",
	)
	await _free_node(manager)


func _test_line_end_reentry_cannot_continue_previous_flow() -> void:
	var manager := await _create_manager()
	manager.start_dialogue_shot = _make_shot("old")
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)
	var replacement_first := _make_dialogue("replacement_first", "replacement first")
	var replacement_second := _make_dialogue("replacement_second", "replacement second")
	replacement_first.next_id = replacement_second.node_id
	var replacement := _make_shot_from_dialogues([replacement_first, replacement_second])
	manager.dialogue_line_end.connect(
		func(node_id: String) -> void:
			if node_id != "start":
				return
			manager.set_shot(replacement)
			manager.init_dialogue()
			manager.start_dialogue()
	)
	manager._process_next()
	await process_frame

	_expect_equal(
		manager.cur_node_id,
		"replacement_first",
		"dialogue_line_end replacement is not advanced by the previous shot",
	)
	await _free_node(manager)


func _test_line_end_cannot_reenter_current_advance() -> void:
	var manager := await _create_manager()
	var first := _make_dialogue("first", "first")
	var second := _make_dialogue("second", "second")
	first.next_id = second.node_id
	manager.start_dialogue_shot = _make_shot_from_dialogues([first, second])
	var ended_nodes: Array[String] = []
	manager.dialogue_line_end.connect(
		func(node_id: String) -> void:
			ended_nodes.append(node_id)
			manager._process_next()
	)
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_node_and_state(manager, first.node_id, KND_DialogueManager.DialogState.PAUSED)

	manager._process_next()
	await _wait_for_condition(
		func() -> bool: return manager.cur_node_id == second.node_id,
		"line-end reentry still advances exactly once to the intended node",
	)

	_expect_equal(
		ended_nodes,
		[first.node_id],
		"line-end reentry cannot emit the same node completion more than once",
	)
	await _free_node(manager)


func _test_skipping_typing_emits_line_end_once() -> void:
	var manager := await _create_manager()
	manager._typing_interval = 1.0
	var first := _make_dialogue("first", "Typing")
	var second := _make_dialogue("second", "Next")
	first.next_id = second.node_id
	manager.start_dialogue_shot = _make_shot_from_dialogues([first, second])
	var ended_nodes: Array[String] = []
	manager.dialogue_line_end.connect(func(node_id: String) -> void: ended_nodes.append(node_id))
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_condition(
		func() -> bool:
			return (
				manager.dialogue_state == KND_DialogueManager.DialogState.PLAYING
				and manager._konado_dialogue_box.typing_tween != null
				and manager._konado_dialogue_box.typing_tween.is_running()
			),
		"the first line starts typing before it is skipped",
	)

	manager._process_next()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)
	_expect_equal(
		ended_nodes,
		[],
		"skipping the typewriter does not report the dialogue node as ended",
	)

	manager._process_next()
	await _wait_for_condition(
		func() -> bool: return manager.cur_node_id == second.node_id,
		"advancing after the skip enters the next dialogue node",
	)
	_expect_equal(
		ended_nodes,
		[first.node_id],
		"the completed dialogue node emits dialogue_line_end exactly once",
	)
	await _free_node(manager)


func _test_screen_text_hide_cancels_pending_display() -> void:
	var manager := await _create_manager()
	manager._screen_text.fade_duration = 0.0
	manager._screen_text.display(["stale screen text"])
	manager._screen_text.hide_screen_text()
	await process_frame
	await process_frame

	_expect(
		not manager._screen_text.visible,
		"hiding screen text cancels a display still waiting for its first layout frame",
	)
	await _free_node(manager)


func _test_screen_text_replacement_cancels_previous_activity() -> void:
	var manager := await _create_manager()
	var screen_text := manager._screen_text
	screen_text.fade_duration = 0.1
	screen_text.line_fade_duration = 0.1
	screen_text.display(["old screen text"])
	await process_frame
	await create_timer(0.12).timeout
	var old_line_tween: Tween = screen_text._line_tween
	_expect(
		old_line_tween != null and old_line_tween.is_running(),
		"the original screen text owns an active line animation",
	)

	screen_text.display(["localized replacement"])
	_expect(
		old_line_tween == null or not old_line_tween.is_running(),
		"replacing screen text cancels the previous line animation immediately",
	)
	await create_timer(0.25).timeout

	_expect_equal(
		screen_text._current_lines,
		["localized replacement"],
		"only the replacement screen text remains after prior callbacks would have completed",
	)
	_expect_equal(
		screen_text._line_labels.size(),
		1,
		"the replacement keeps exactly its own line labels",
	)
	if not screen_text._line_labels.is_empty():
		_expect_equal(
			screen_text._line_labels[0].text,
			"localized replacement",
			"the remaining screen text label belongs to the replacement",
		)

	screen_text.hide_screen_text()
	var old_hide_tween: Tween = screen_text._fade_tween
	screen_text.display(["replacement during hide"])
	_expect(
		old_hide_tween == null or not old_hide_tween.is_running(),
		"replacing screen text cancels a pending hide animation immediately",
	)
	await create_timer(0.25).timeout
	_expect(screen_text.visible, "a pending hide cannot conceal the replacement screen text")
	_expect_equal(
		screen_text._current_lines,
		["replacement during hide"],
		"a pending hide cannot clear the replacement screen text",
	)
	await _free_node(manager)


func _test_destroyed_choice_button_callback_is_safe() -> void:
	var capture := RuntimeErrorCapture.new()
	OS.add_logger(capture)
	var manager := await _create_manager()
	var choice_node := KND_Dialogue.new()
	choice_node.dialog_type = KND_Dialogue.Type.SHOW_CHOICE
	choice_node.node_id = "choice"
	var first_target := _make_dialogue("first_target", "first")
	var second_target := _make_dialogue("second_target", "second")
	manager.cur_dialogue_shot = _make_shot_from_dialogues(
		[choice_node, first_target, second_target]
	)
	manager.cur_node_id = choice_node.node_id
	manager._shot_active = true
	var stale_choice := KND_DialogueChoice.new()
	stale_choice.choice_text = "stale"
	stale_choice.next_id = first_target.node_id
	var choices: Array[KND_DialogueChoice] = [stale_choice]
	manager._konado_choice_interface.display_options(
		choices, manager, 32, manager._playback_generation
	)
	var choice_button := manager._konado_choice_interface._choice_container.get_child(0) as Button
	choice_button.pressed.emit()
	var first_choice := KND_DialogueChoice.new()
	first_choice.choice_text = "first"
	first_choice.next_id = first_target.node_id
	var second_choice := KND_DialogueChoice.new()
	second_choice.choice_text = "second"
	second_choice.next_id = second_target.node_id
	var replacement_choices: Array[KND_DialogueChoice] = [first_choice, second_choice]
	manager._konado_choice_interface.display_options(
		replacement_choices, manager, 32, manager._playback_generation
	)
	await process_frame
	await process_frame
	_expect_equal(
		manager.cur_node_id,
		choice_node.node_id,
		"rebuilding options invalidates a click deferred by the previous presentation",
	)

	var first_button := manager._konado_choice_interface._choice_container.get_child(0) as Button
	var second_button := manager._konado_choice_interface._choice_container.get_child(1) as Button
	first_button.pressed.emit()
	second_button.pressed.emit()
	await process_frame
	await process_frame
	OS.remove_logger(capture)

	_expect_equal(
		capture.errors,
		[],
		"a delayed choice callback does not access a button after the choices are rebuilt",
	)
	_expect_equal(
		manager.cur_node_id,
		first_target.node_id,
		"only the first choice pressed in one presentation can advance the dialogue",
	)
	await _free_node(manager)


func _test_shot_end_can_stop_a_replacement_shot() -> void:
	var manager := await _create_manager()
	var shot_end_count := [0]
	var replacement := _make_shot("replacement")
	manager.shot_end.connect(
		func() -> void:
			shot_end_count[0] += 1
			if shot_end_count[0] != 1:
				return
			manager.set_shot(replacement)
			manager.init_dialogue()
			manager.start_dialogue()
			manager.stop_dialogue()
	)
	manager.start_dialogue_shot = _make_shot("first")
	manager.init_dialogue()
	manager.start_dialogue()
	manager.stop_dialogue()
	await process_frame

	_expect_equal(
		shot_end_count[0],
		2,
		"a replacement shot can be stopped synchronously from the previous shot_end handler",
	)
	_expect(
		not manager._shot_active and manager.dialogue_state == KND_DialogueManager.DialogState.OFF,
		"the synchronously stopped replacement shot reaches a complete off state",
	)
	await _free_node(manager)


func _test_hide_then_show_preserves_content() -> void:
	var box := DIALOGUE_BOX_SCENE.instantiate() as KND_DialogueBox
	box.enable_typing_effect_audio = false
	root.add_child(box)
	await process_frame
	box.character_name = "Kona"
	box.dialogue_text = "Preserved content"
	box.show_dialogue_box_with_duration(0.0)
	box.hide_dialogue_box_with_duration(0.0)
	box.show_dialogue_box_with_duration(0.0)

	_expect_equal(
		box.character_name,
		"Kona",
		"hiding and showing the dialogue box preserves the current speaker",
	)
	_expect_equal(
		box.dialogue_text,
		"Preserved content",
		"hiding and showing the dialogue box preserves the current text",
	)
	await _free_node(box)
