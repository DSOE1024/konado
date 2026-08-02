extends SceneTree

const DIALOGUE_MANAGER_SCENE := preload("res://addons/konado/template/default/konado_dialogue.tscn")
const DIALOGUE_BOX_SCENE := preload("res://addons/konado/template/default/knd_dialogue_box.tscn")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_set_shot_initialization()
	await _test_dialogue_box_transitions(KND_DialogueBox.TypewriterMode.TRADITIONAL)
	await _test_dialogue_box_transitions(KND_DialogueBox.TypewriterMode.FADE_IN_TYPEWRITER)
	await _test_consecutive_dialogue_lines()
	await _test_restart_during_fade()
	await _test_restart_disconnects_stale_typing_callback()
	await _test_hide_textbox(0.0)
	await _test_hide_textbox(0.01)
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
	await create_timer(0.04).timeout
	_expect_equal(
		manager._konado_dialogue_box.typing_completed.get_connections().size(),
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
	await create_timer(0.04).timeout
	_expect_equal(
		manager._konado_dialogue_box.typing_completed.get_connections().size(),
		1,
		"restarting dialogue does not accumulate typing callbacks",
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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	printerr("ASSERTION FAILED: " + message)
	_failures += 1


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])
