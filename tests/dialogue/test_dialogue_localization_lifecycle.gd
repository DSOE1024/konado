extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_locale_reload_does_not_duplicate_action_callbacks()
	await _test_locale_reload_restarts_active_typing_once()
	await _test_locale_reload_does_not_emit_typing_completion()
	await _test_locale_reload_during_dialogue_fade_uses_localized_line()
	await _test_locale_reload_preserves_running_node_identity()
	if _failures == 0:
		print("PASS: dialogue localization lifecycle tests")
	quit(_failures)


func _test_locale_reload_does_not_duplicate_action_callbacks() -> void:
	var manager := await _create_manager()
	var source_show := KND_Dialogue.new()
	source_show.dialog_type = KND_Dialogue.Type.SHOW_TEXTBOX
	source_show.node_id = "show"
	source_show.textbox_duration = 5.0
	var source_shot := _make_shot_from_dialogues([source_show])
	source_shot.ks_path = "res://tests/dialogue/source.ks"
	var localized_show := source_show.duplicate() as KND_Dialogue
	var localized_shot := _make_shot_from_dialogues([localized_show])
	localized_shot.ks_path = "res://tests/dialogue/source.zh_Hant.ks"
	var service := FakeLocalizedScriptService.new()
	service.localized_shot = localized_shot
	root.add_child(service)
	manager._i18n_service = service
	manager.start_dialogue_shot = source_shot
	manager.init_dialogue()
	manager.start_dialogue()
	await process_frame
	await process_frame
	var connection_count_before := (
		manager._konado_dialogue_box.on_dialogue_show_completed.get_connections().size()
	)
	manager.reload_localized_script("zh_Hant")
	await process_frame
	var connection_count_after := (
		manager._konado_dialogue_box.on_dialogue_show_completed.get_connections().size()
	)

	_expect_equal(
		connection_count_before,
		1,
		"the active localized action starts with one completion callback",
	)
	_expect_equal(
		connection_count_after,
		1,
		"reloading the locale does not bind the active action completion callback twice",
	)
	await _free_node(manager)
	await _free_node(service)


func _test_locale_reload_does_not_emit_typing_completion() -> void:
	var manager := await _create_manager()
	manager._typing_interval = 1.0
	var source_line := _make_dialogue("line", "Source")
	var source_shot := _make_shot_from_dialogues([source_line])
	source_shot.ks_path = "res://tests/dialogue/source.ks"
	var localized_line := _make_dialogue("line", "Localized")
	var localized_shot := _make_shot_from_dialogues([localized_line])
	localized_shot.ks_path = "res://tests/dialogue/source.zh_Hant.ks"
	var service := FakeLocalizedScriptService.new()
	service.localized_shot = localized_shot
	root.add_child(service)
	manager._i18n_service = service
	manager.start_dialogue_shot = source_shot
	manager.init_dialogue()
	manager.start_dialogue()
	await process_frame
	await process_frame
	await _wait_for_condition(
		func() -> bool:
			return (
				manager._konado_dialogue_box.typing_tween != null
				and manager._konado_dialogue_box.typing_tween.is_running()
			),
		"the source line starts its typewriter animation",
	)
	manager._konado_dialogue_box.skip_typing_anim()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)
	var completion_count := [0]
	manager._konado_dialogue_box.typing_completed.connect(func() -> void: completion_count[0] += 1)
	manager.reload_localized_script("zh_Hant")
	await process_frame
	await process_frame

	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		"Localized",
		"locale reload refreshes the active dialogue text",
	)
	_expect_equal(
		manager._konado_dialogue_box.dialogue_label.visible_ratio,
		1.0,
		"locale reload immediately displays a completed localized line",
	)
	_expect_equal(
		completion_count[0],
		0,
		"locale reload does not emit a synthetic typing completion",
	)
	await _free_node(manager)
	await _free_node(service)


func _test_locale_reload_restarts_active_typing_once() -> void:
	var manager := await _create_manager()
	manager._typing_interval = 0.02
	var source_line := _make_dialogue("line", "Source text still typing")
	var source_shot := _make_shot_from_dialogues([source_line])
	source_shot.ks_path = "res://tests/dialogue/source.ks"
	var localized_line := _make_dialogue("line", "Localized")
	var localized_shot := _make_shot_from_dialogues([localized_line])
	localized_shot.ks_path = "res://tests/dialogue/source.zh_Hant.ks"
	var service := FakeLocalizedScriptService.new()
	service.localized_shot = localized_shot
	root.add_child(service)
	manager._i18n_service = service
	var completion_count := [0]
	manager._konado_dialogue_box.typing_completed.connect(func() -> void: completion_count[0] += 1)
	manager.start_dialogue_shot = source_shot
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_condition(
		func() -> bool:
			return (
				manager._konado_dialogue_box.typing_tween != null
				and manager._konado_dialogue_box.typing_tween.is_running()
			),
		"the source line is typing before an active locale reload",
	)

	manager.reload_localized_script("zh_Hant")
	_expect_equal(
		manager._konado_dialogue_box.typing_completed.get_connections().size(),
		2,
		"active locale reload keeps one manager callback and one test observer",
	)
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)

	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		"Localized",
		"active locale reload replaces the text being typed",
	)
	_expect_equal(
		completion_count[0],
		1,
		"the replacement typewriter emits exactly one completion event",
	)
	await _free_node(manager)
	await _free_node(service)


func _test_locale_reload_during_dialogue_fade_uses_localized_line() -> void:
	var manager := await _create_manager()
	manager._konado_dialogue_box.fade_duration = 0.15
	var source_line := _make_dialogue("line", "Source")
	var source_shot := _make_shot_from_dialogues([source_line])
	source_shot.ks_path = "res://tests/dialogue/source.ks"
	var localized_line := _make_dialogue("line", "Localized during fade")
	var localized_shot := _make_shot_from_dialogues([localized_line])
	localized_shot.ks_path = "res://tests/dialogue/source.zh_Hant.ks"
	var service := FakeLocalizedScriptService.new()
	service.localized_shot = localized_shot
	root.add_child(service)
	manager._i18n_service = service
	manager.start_dialogue_shot = source_shot
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_condition(
		func() -> bool:
			return (
				manager._konado_dialogue_box.fade_tween != null
				and manager._konado_dialogue_box.fade_tween.is_running()
				and not manager._typing_completed_callback.is_valid()
			),
		"the dialogue box is fading in before a locale reload",
	)

	manager.reload_localized_script("zh_Hant")
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)

	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		"Localized during fade",
		"a fade completion reads the current localized line instead of captured source text",
	)
	await _free_node(manager)
	await _free_node(service)


func _test_locale_reload_preserves_running_node_identity() -> void:
	var manager := await _create_manager()
	var source_show := KND_Dialogue.new()
	source_show.dialog_type = KND_Dialogue.Type.SHOW_TEXTBOX
	source_show.node_id = "source_show"
	source_show.next_id = "source_line"
	source_show.textbox_duration = 5.0
	var source_line := _make_dialogue("source_line", "Source")
	var source_shot := _make_shot_from_dialogues([source_show, source_line])
	source_shot.ks_path = "res://tests/dialogue/source.ks"

	var localized_show := source_show.duplicate() as KND_Dialogue
	localized_show.node_id = "localized_show"
	localized_show.next_id = "localized_line"
	var localized_line := _make_dialogue("localized_line", "Localized after remap")
	var localized_shot := _make_shot_from_dialogues([localized_show, localized_line])
	localized_shot.ks_path = "res://tests/dialogue/source.zh_Hant.ks"

	var service := FakeLocalizedScriptService.new()
	service.localized_shot = source_shot
	root.add_child(service)
	manager._i18n_service = service
	manager.start_dialogue_shot = source_shot
	manager.init_dialogue()
	manager.start_dialogue()
	await process_frame
	await process_frame
	_expect_equal(
		manager._konado_dialogue_box.on_dialogue_show_completed.get_connections().size(),
		1,
		"the source action has one in-flight completion callback before locale remapping",
	)

	service.localized_shot = localized_shot
	service.restore_node_id = localized_show.node_id
	_expect(
		manager.reload_localized_script("zh_Hant"),
		"an active node can be restored by its position in a localized graph",
	)
	_expect_equal(
		manager.cur_node_id,
		source_show.node_id,
		"the in-flight callback keeps a stable runtime node identity",
	)
	_expect(
		manager.cur_dialogue_shot.find_node(localized_show.node_id) != null,
		"the localized node remains addressable by its canonical ID",
	)

	manager._konado_dialogue_box.on_dialogue_show_completed.emit()
	await _wait_for_node_and_state(
		manager, localized_line.node_id, KND_DialogueManager.DialogState.PAUSED
	)
	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		localized_line.dialog_content,
		"the completed action advances into the localized graph without getting stuck",
	)
	await _free_node(manager)
	await _free_node(service)
