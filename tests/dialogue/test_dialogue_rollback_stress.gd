extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"

## 回退链路的压力与不变量测试：循环回退不漂移、绕路回退与直线播放状态一致、
## Backlog 跳转风暴下状态有界、以及快照恢复失败时的原子安全停机。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_rewind_cycles_do_not_drift()
	await _test_rollback_detour_matches_straight_playthrough()
	await _test_backlog_jump_storm_stays_bounded_and_consistent()
	await _test_failed_restore_enters_safe_off_state()
	if _failures == 0:
		print("PASS: dialogue rollback stress tests")
	quit(_failures)


## 反复「前进 → 回退」不应产生任何累积漂移：角色位置、镜头变换与变量每次都回到同一基准。
func _test_rewind_cycles_do_not_drift() -> void:
	var manager := await _create_manager()
	_setup_characters(manager)
	var camera := _attach_camera_marker(manager, Vector2(900.0, 640.0))
	manager.set_shot(
		_compile_shot(
			(
				"actor show Kona 正常 at 1\n"
				+ "set %love = 0\n"
				+ '"Kona" "L0" [id=l0]\n'
				+ "actor move Kona 3\n"
				+ "add %love 1\n"
				+ "asyncam move cam1 linear 1.0\n"
				+ '"Kona" "L1" [id=l1]\n'
				+ "end"
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:l0", KonadoDialogueManager.DialogState.WAITING
	)
	var actor_baseline := _actor_position(manager)
	var camera_baseline := camera.position
	var love_baseline := manager.variable_store.get_int("love")
	for cycle: int in range(20):
		await _finish_current_dialogue(manager)
		await _wait_for_instruction_and_state(
			manager, "ks:id:l1", KonadoDialogueManager.DialogState.WAITING
		)
		_expect_equal(
			manager.variable_store.get_int("love"), 1, "cycle %d applies the change" % cycle
		)
		_expect(manager.timeline.step_back(), "cycle %d rewinds" % cycle)
		_expect_equal(
			manager.dialogue_box.dialogue_text, "L0", "cycle %d lands on the same line" % cycle
		)
		_expect_equal(
			_actor_position(manager), actor_baseline, "cycle %d restores the actor" % cycle
		)
		_expect_equal(camera.position, camera_baseline, "cycle %d restores the camera" % cycle)
		_expect_equal(
			manager.variable_store.get_int("love"),
			love_baseline,
			"cycle %d restores the variables" % cycle,
		)
	await _free_node(manager)


## 中途回退并改选的旅程，最终状态必须与一次直线播放完全相同（变量、结局与镜头一致；
## 副作用次数按可重放策略计数）。
func _test_rollback_detour_matches_straight_playthrough() -> void:
	var straight := await _play_with_detour(false)
	var detour := await _play_with_detour(true)
	_expect_equal(detour, straight, "a rollback detour lands on the same final state")


func _play_with_detour(with_detour: bool) -> Dictionary:
	var manager := await _create_manager()
	manager.set_shot(
		_compile_shot(
			(
				"set %love = 0\n"
				+ '"Kona" "L0" [id=l0]\n'
				+ 'choice "Tea" -> tea [id=drink]\n'
				+ 'choice "Coffee" -> coffee\n'
				+ "branch tea\n"
				+ "\tadd %love 2\n"
				+ "\tsignal reward\n"
				+ '\t"Kona" "tea" [id=tea_line]\n'
				+ "\tend\n"
				+ "branch coffee\n"
				+ "\tadd %love 5\n"
				+ '\t"Kona" "coffee" [id=coffee_line]\n'
				+ "\tend"
			)
		)
	)
	var emissions: Array[String] = []
	manager.custom_signal.connect(func(content: String) -> void: emissions.append(content))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:l0", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:drink", KonadoDialogueManager.DialogState.WAITING
	)
	if with_detour:
		manager._on_option_triggered(
			manager._current_instruction().value(&"options")[1], manager._playback_generation
		)
		await _wait_for_instruction_and_state(
			manager, "ks:id:coffee_line", KonadoDialogueManager.DialogState.WAITING
		)
		_expect_equal(
			manager.variable_store.get_int("love"), 5, "the detour branch applied its change"
		)
		_expect(manager.timeline.step_back(), "the detour rewinds to the choice")
		_expect_equal(
			manager.variable_store.get_int("love"), 0, "the detour branch is fully undone"
		)
	manager._on_option_triggered(
		manager._current_instruction().value(&"options")[0], manager._playback_generation
	)
	await _wait_for_instruction_and_state(
		manager, "ks:id:tea_line", KonadoDialogueManager.DialogState.WAITING
	)
	var result := {
		"text": manager.dialogue_box.dialogue_text,
		"love": manager.variable_store.get_int("love"),
		"emissions": emissions.size(),
		"camera": manager.camera_controller.capture_state(),
	}
	await _free_node(manager)
	return result


## Backlog 跳转风暴：随机跳转 120 次后，状态必须始终自洽（行号与变量一一对应）、
## 各种缓存保持在预算内，且停在任意一行都不会卡死。
func _test_backlog_jump_storm_stays_bounded_and_consistent() -> void:
	var manager := await _create_manager()
	var lines := 30
	var source := "set %love = 0\n"
	for index: int in range(lines):
		source += '"Kona" "L%d" [id=l%d]\n' % [index, index]
		source += "add %love 1\n"
	source += "end\n"
	manager.set_shot(_compile_shot(source))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:l0", KonadoDialogueManager.DialogState.WAITING
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240911
	for step: int in range(120):
		var entries := manager.dialogue_history.entries(0, false)
		var action := rng.randi_range(0, 2)
		if action == 0 or entries.is_empty():
			if _is_at_last_line(manager, lines):
				continue
			await _finish_current_dialogue(manager)
		elif action == 1:
			manager.timeline.step_back()
		else:
			var pick := rng.randi_range(0, entries.size() - 1)
			manager.timeline.rollback_to_entry(int(entries[pick].get("serial", 0)))
		await _expect_consistent_line_state(manager, step)
	await _free_node(manager)


## 当前可显示行必须与变量一一对应：第 k 行的 %love 只能是 k（每次重放都精确重建）。
func _expect_consistent_line_state(manager: KonadoDialogueManager, step: int) -> void:
	for _frame: int in range(60):
		if manager.dialogue_state == KonadoDialogueManager.DialogState.WAITING:
			break
		await process_frame
	_expect(
		manager.dialogue_state == KonadoDialogueManager.DialogState.WAITING,
		"step %d leaves the dialogue waiting on a line" % step,
	)
	var instruction := manager._current_instruction()
	var key := instruction.stable_key() if instruction != null else ""
	_expect(key.begins_with("ks:id:l"), "step %d stays on a displayable line" % step)
	var line := int(key.trim_prefix("ks:id:l"))
	_expect_equal(
		manager.variable_store.get_int("love"), line, "step %d keeps variables in step" % step
	)
	_expect(
		manager.timeline._snapshots.size() <= 128, "step %d keeps the snapshot count bounded" % step
	)
	_expect(
		manager.timeline._snapshots.bytes_used() <= 4 * 1024 * 1024,
		"step %d keeps the snapshot bytes bounded" % step,
	)
	await process_frame


func _is_at_last_line(manager: KonadoDialogueManager, lines: int) -> bool:
	var instruction := manager._current_instruction()
	if instruction == null:
		return true
	return instruction.stable_key() == "ks:id:l%d" % (lines - 1)


## 快照恢复失败必须原子停机：不留下半还原画面，且管理器随后仍可重新开始。
func _test_failed_restore_enters_safe_off_state() -> void:
	var manager := await _create_manager()
	_setup_characters(manager)
	manager.set_shot(
		_compile_shot(
			"actor show Kona 正常 at 1\n" + '"Kona" "L0" [id=l0]\n' + '"Kona" "L1" [id=l1]\n' + "end"
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:l0", KonadoDialogueManager.DialogState.WAITING
	)
	_expect(manager.stage_controller.get_actor("Kona") != null, "the actor is on stage")
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:l1", KonadoDialogueManager.DialogState.WAITING
	)
	# 故障注入：让目标行的快照指纹失配，模拟“快照已失效”的恢复失败。
	var snapshots: Dictionary = manager.timeline._snapshots._snapshots
	_expect(not snapshots.is_empty(), "the rewind has line snapshots to corrupt")
	for snapshot_key: Variant in snapshots:
		var state: Dictionary = snapshots[snapshot_key]
		if state.get("execution", {}) is Dictionary:
			state["execution"]["program_fingerprint"] = "corrupted-by-test"
	_expect(not manager.timeline.step_back(), "a corrupted snapshot refuses the rewind")
	_expect_equal(
		manager.dialogue_state,
		KonadoDialogueManager.DialogState.OFF,
		"a failed restore stops the dialogue safely",
	)
	_expect(
		manager.stage_controller.get_actor("Kona") == null,
		"the safe stop clears the stage instead of leaving a half-restored scene",
	)
	_expect_equal(
		manager.camera_controller.capture_state().get("position", Vector2.ZERO),
		Vector2.ZERO,
		"the camera is neutralized",
	)
	# 安全停机是按设计做的完整拆除（含清空 current_shot），恢复方式是重新装载镜头再开始。
	manager.set_shot(_compile_shot('"Kona" "L0" [id=l0]\nend'))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:l0", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(manager.dialogue_box.dialogue_text, "L0", "the manager restarts after the stop")
	await _free_node(manager)


func _setup_characters(manager: KonadoDialogueManager) -> void:
	manager.character_list = load("res://sample/demo/character_list.tres")
	manager.stage_controller.character_list = manager.character_list


func _attach_camera_marker(manager: KonadoDialogueManager, marker_position: Vector2) -> Camera2D:
	var controller := manager.camera_controller
	var camera := controller.active_camera
	_expect(camera != null, "the default template exposes an active camera")
	camera.position = Vector2(120.0, 80.0)
	var marker := KonadoCameraMarker.new()
	marker.marker_id = "cam1"
	marker.position = marker_position
	if is_instance_valid(controller.marker_root):
		controller.marker_root.add_child(marker)
	else:
		controller.add_child(marker)
	controller.refresh_camera_markers()
	return camera


func _actor_position(manager: KonadoDialogueManager) -> int:
	for actor: Dictionary in manager.stage_controller.capture_state().get("actors", []):
		if String(actor.get("id", "")) == "Kona":
			return int(actor.get("position", -1))
	return -1
