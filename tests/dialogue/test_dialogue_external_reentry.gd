extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"


class FakeAchievementManager:
	extends Node

	signal operation_called

	func unlock_achievement(_achievement_id: String) -> bool:
		operation_called.emit()
		return true

	func increment_progress(_key: String, _amount: float = 1.0) -> void:
		operation_called.emit()

	func set_flag(_key: String, _value: bool = true) -> void:
		operation_called.emit()


class RejectingAudioInterface:
	extends KND_AudioInterface

	func _did_voice_playback_start() -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_voice_signal_reentry_cannot_continue_previous_line()
	await _test_variable_signal_reentry_cannot_advance_replacement()
	await _test_achievement_signal_reentry_cannot_advance_replacement()
	await _test_initialize_cleanup_reentry_cannot_override_replacement()
	await _test_stop_cleanup_reentry_cannot_override_replacement()
	await _test_stop_cleanup_reentry_can_restart_same_shot()
	await _test_interrupted_voice_does_not_emit_stale_completion()
	await _test_waitable_voice_reports_natural_completion()
	await _test_waitable_voice_reports_interruption()
	await _test_waitable_voice_reports_replacement()
	await _test_waitable_voice_reports_start_failure()
	await _test_bgm_loop_connection_does_not_accumulate()
	await _test_camera_cancellation_preserves_configured_offset()
	await process_frame
	await process_frame
	await create_timer(0.05).timeout
	if _failures == 0:
		print("PASS: dialogue external reentry tests")
	quit(_failures)


func _test_voice_signal_reentry_cannot_continue_previous_line() -> void:
	var manager := await _create_manager()
	var voice := DialogVoice.new()
	voice.voice_name = "old_voice"
	voice.voice = AudioStreamGenerator.new()
	var voice_list := DialogVoiceList.new()
	voice_list.voices = [voice]
	manager.voice_list = voice_list

	var old_line := _make_dialogue("old_line", "stale text")
	old_line.voice_id = voice.voice_name
	var replacement := _make_pending_action_shot("replacement")
	var replaced := [false]
	manager._audio_interface.finish_playvoice.connect(
		func() -> void:
			if replaced[0]:
				return
			replaced[0] = true
			_start_replacement(manager, replacement)
	)

	manager.start_dialogue_shot = _make_shot_from_dialogues([old_line])
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_replacement_action(manager, "replacement")

	_expect_equal(
		manager._konado_dialogue_box.dialogue_text,
		"",
		"a voice callback replacement is not overwritten by the previous dialogue text",
	)
	_expect_equal(
		manager._konado_dialogue_box.typing_completed.get_connections().size(),
		0,
		"a voice callback replacement does not inherit the previous typing callback",
	)
	await _free_node(manager)


func _test_variable_signal_reentry_cannot_advance_replacement() -> void:
	var manager := await _create_manager()
	manager.variable_store.set_value("score", 0)
	var replacement := _make_pending_action_shot("replacement")
	var replaced := [false]
	manager.variable_store.variable_changed.connect(
		func(_name: String, _value: Variant) -> void:
			if replaced[0]:
				return
			replaced[0] = true
			_start_replacement(manager, replacement)
	)

	var variable_command := KND_Dialogue.new()
	variable_command.dialog_type = KND_Dialogue.Type.SET_VARIABLE
	variable_command.node_id = "set_variable"
	variable_command.variable_name = "score"
	variable_command.variable_operation = KND_VariableStore.Operation.SET
	variable_command.variable_operand = "1"
	variable_command.is_persistent = true
	manager.start_dialogue_shot = _make_shot_from_dialogues([variable_command])
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_replacement_action(manager, "replacement")

	_expect(
		manager._shot_active,
		"a variable callback replacement remains active after the previous command returns",
	)
	await _free_node(manager)


func _test_achievement_signal_reentry_cannot_advance_replacement() -> void:
	var manager := await _create_manager()
	var achievement_manager := FakeAchievementManager.new()
	root.add_child(achievement_manager)
	manager.achievement_mgr = achievement_manager
	var replacement := _make_pending_action_shot("replacement")
	var replaced := [false]
	achievement_manager.operation_called.connect(
		func() -> void:
			if replaced[0]:
				return
			replaced[0] = true
			_start_replacement(manager, replacement)
	)

	var achievement_command := KND_Dialogue.new()
	achievement_command.dialog_type = KND_Dialogue.Type.ACHIEVEMENT_UNLOCK
	achievement_command.node_id = "unlock"
	achievement_command.achievement_id = "test"
	manager.start_dialogue_shot = _make_shot_from_dialogues([achievement_command])
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_replacement_action(manager, "replacement")

	_expect(
		manager._shot_active,
		"an achievement callback replacement remains active after the previous command returns",
	)
	await _free_node(manager)
	await _free_node(achievement_manager)


func _test_initialize_cleanup_reentry_cannot_override_replacement() -> void:
	var manager := await _create_manager()
	var replacement := _make_pending_action_shot("replacement")
	var stale_actor := Node.new()
	manager._acting_interface._chara_controler.add_child(stale_actor)
	stale_actor.tree_exited.connect(func() -> void: _start_replacement(manager, replacement))

	manager.start_dialogue_shot = _make_shot("old")
	manager.init_dialogue()
	await _wait_for_replacement_action(manager, "replacement")

	_expect(
		manager._shot_active,
		"an initialization cleanup callback cannot let the old initialization close its replacement",
	)
	await _free_node(manager)


func _test_stop_cleanup_reentry_cannot_override_replacement() -> void:
	var manager := await _create_manager()
	var replacement := _make_pending_action_shot("replacement")
	var replaced := [false]
	manager._acting_interface.background_change_finished.connect(
		func() -> void:
			if replaced[0]:
				return
			replaced[0] = true
			_start_replacement(manager, replacement)
	)

	manager.start_dialogue_shot = _make_shot("old")
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)
	manager.stop_dialogue()
	await _wait_for_replacement_action(manager, "replacement")

	_expect(
		manager._shot_active,
		"a stop cleanup callback cannot let the old stop close its replacement",
	)
	await _free_node(manager)


func _test_stop_cleanup_reentry_can_restart_same_shot() -> void:
	var manager := await _create_manager()
	var restarted := [false]
	var start_count := [0]
	manager.shot_start.connect(func() -> void: start_count[0] += 1)
	manager._acting_interface.background_change_finished.connect(
		func() -> void:
			if restarted[0]:
				return
			restarted[0] = true
			manager.start_dialogue()
	)

	manager.start_dialogue_shot = _make_shot("restart")
	manager.init_dialogue()
	manager.start_dialogue()
	await _wait_for_state(manager, KND_DialogueManager.DialogState.PAUSED)
	manager.stop_dialogue()
	await _wait_for_condition(
		func() -> bool:
			return (
				manager._shot_active
				and manager.dialogue_state != KND_DialogueManager.DialogState.OFF
			),
		"a stop cleanup callback can restart the initialized shot",
	)

	_expect_equal(start_count[0], 2, "a direct restart emits exactly one new shot_start")
	_expect(
		manager._konado_dialogue_box.is_dialogue_box_visible(),
		"the previous stop does not hide a directly restarted shot",
	)
	manager.stop_dialogue()
	await _free_node(manager)


func _test_interrupted_voice_does_not_emit_stale_completion() -> void:
	var manager := await _create_manager()
	var audio := AudioStreamGenerator.new()
	var completion_count := [0]
	manager._audio_interface.voice_finish_playing.connect(func() -> void: completion_count[0] += 1)

	manager._audio_interface.play_voice(audio)
	manager._audio_interface.stop_voice()
	manager._audio_interface.voice_player.finished.emit()
	_expect_equal(
		completion_count[0],
		0,
		"an interrupted voice does not emit a stale completion event",
	)

	manager._audio_interface.play_voice(audio)
	manager._audio_interface.voice_player.stop()
	manager._audio_interface.voice_player.finished.emit()
	_expect_equal(
		completion_count[0],
		1,
		"a naturally completed voice emits exactly one completion event",
	)
	manager._audio_interface.stop_voice()
	manager._audio_interface.voice_player.stream = null
	await _free_node(manager)


func _test_waitable_voice_reports_natural_completion() -> void:
	var manager := await _create_manager()
	var results: Array[bool] = []
	_capture_voice_result(manager._audio_interface, AudioStreamGenerator.new(), results)
	manager._audio_interface.voice_player.stop()
	manager._audio_interface.voice_player.finished.emit()
	await _wait_for_condition(
		func() -> bool: return results.size() == 1,
		"the waitable voice API resolves after natural completion",
	)
	_expect_equal(results, [true], "natural voice completion returns true")
	manager._audio_interface.voice_player.stream = null
	await _free_node(manager)


func _test_waitable_voice_reports_interruption() -> void:
	var manager := await _create_manager()
	var results: Array[bool] = []
	_capture_voice_result(manager._audio_interface, AudioStreamGenerator.new(), results)
	manager._audio_interface.stop_voice()
	await _wait_for_condition(
		func() -> bool: return results.size() == 1,
		"the waitable voice API resolves after stop_voice",
	)
	_expect_equal(results, [false], "stopped voice playback returns false")
	manager._audio_interface.voice_player.stream = null
	await _free_node(manager)


func _test_waitable_voice_reports_replacement() -> void:
	var manager := await _create_manager()
	var first_results: Array[bool] = []
	var second_results: Array[bool] = []
	_capture_voice_result(manager._audio_interface, AudioStreamGenerator.new(), first_results)
	_capture_voice_result(manager._audio_interface, AudioStreamGenerator.new(), second_results)
	await _wait_for_condition(
		func() -> bool: return first_results.size() == 1,
		"replacing a voice resolves the previous waiter",
	)
	manager._audio_interface.voice_player.stop()
	manager._audio_interface.voice_player.finished.emit()
	await _wait_for_condition(
		func() -> bool: return second_results.size() == 1,
		"the replacement voice resolves after natural completion",
	)
	_expect_equal(first_results, [false], "replaced voice playback returns false")
	_expect_equal(second_results, [true], "the replacement voice returns true when it finishes")
	manager._audio_interface.voice_player.stream = null
	await _free_node(manager)


func _test_waitable_voice_reports_start_failure() -> void:
	var audio_interface := RejectingAudioInterface.new()
	var player := AudioStreamPlayer.new()
	audio_interface.voice_player = player
	audio_interface.add_child(player)
	root.add_child(audio_interface)
	var results: Array[bool] = []

	_capture_voice_result(audio_interface, AudioStreamGenerator.new(), results)
	await _wait_for_condition(
		func() -> bool: return results.size() == 1,
		"the waitable voice API resolves when the player rejects playback",
	)
	_expect_equal(results, [false], "voice playback that cannot start returns false")
	_expect(
		not audio_interface._voice_playing,
		"a rejected voice does not leave the audio interface in a playing state",
	)
	audio_interface.voice_player.stream = null
	await _free_node(audio_interface)


func _capture_voice_result(
	audio_interface: KND_AudioInterface, audio: AudioStream, results: Array[bool]
) -> void:
	results.append(await audio_interface.play_voice_and_wait(audio))


func _test_bgm_loop_connection_does_not_accumulate() -> void:
	var manager := await _create_manager()
	var audio := AudioStreamGenerator.new()

	manager._audio_interface.play_bgm(audio, "first")
	var first_count := manager._audio_interface.bgm_player.finished.get_connections().size()
	manager._audio_interface.play_bgm(audio, "second")
	var second_count := manager._audio_interface.bgm_player.finished.get_connections().size()

	_expect_equal(first_count, 1, "BGM playback installs one loop callback")
	_expect_equal(second_count, 1, "replaying BGM does not accumulate loop callbacks")
	manager._audio_interface.stop_bgm()
	await _free_node(manager)


func _test_camera_cancellation_preserves_configured_offset() -> void:
	var camera_manager := KonadoCameraManager.new()
	var camera := Camera2D.new()
	var background_container := Node.new()
	var configured_offset := Vector2(12.0, -8.0)
	camera.offset = configured_offset
	camera_manager.add_child(camera)
	camera_manager.add_child(background_container)
	camera_manager.current = camera
	camera_manager.bg_container = background_container
	root.add_child(camera_manager)
	await process_frame

	camera_manager.shake_cam(1.0)
	await process_frame
	camera_manager.cancel_pending_operations()
	_expect_equal(
		camera.offset,
		configured_offset,
		"cancelling a synchronous camera shake restores the configured offset",
	)

	camera_manager.async_shake_cam(1.0)
	await process_frame
	camera_manager.async_stop_all()
	_expect_equal(
		camera.offset,
		configured_offset,
		"stopping asynchronous camera operations restores the configured offset",
	)
	await _free_node(camera_manager)


func _make_pending_action_shot(node_id: String) -> KND_Shot:
	var show := KND_Dialogue.new()
	show.dialog_type = KND_Dialogue.Type.SHOW_TEXTBOX
	show.node_id = node_id
	show.textbox_duration = 5.0
	return _make_shot_from_dialogues([show])


func _start_replacement(manager: KND_DialogueManager, replacement: KND_Shot) -> void:
	manager.set_shot(replacement)
	manager.init_dialogue()
	manager.start_dialogue()


func _wait_for_replacement_action(manager: KND_DialogueManager, node_id: String) -> void:
	await _wait_for_condition(
		func() -> bool:
			return (
				manager.cur_node_id == node_id
				and manager.dialogue_state == KND_DialogueManager.DialogState.PLAYING
			),
		"the replacement action remains in progress",
	)
