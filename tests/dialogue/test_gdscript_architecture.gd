extends SceneTree

var _failures := 0


class FakeActor:
	extends KND_Actor

	var requested_statuses: Array[String] = []
	var last_transition_duration := -1.0
	var next_result := true

	func apply_character_status(
		status_name: String, transition_duration: float = 0.0, completion: Callable = Callable()
	) -> void:
		requested_statuses.append(status_name)
		last_transition_duration = transition_duration
		if completion.is_valid():
			completion.call(next_result)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_actor_commands()
	_test_analyzer_control_flow()
	_test_dialogue_services()
	_test_acting_interface_state_change()
	_test_save_system_contract()
	await _test_actor_state_transition()
	if _failures == 0:
		print("PASS: GDScript architecture tests")
	quit(_failures)


func _test_actor_commands() -> void:
	var compiler := KS_Compiler.new()
	var cases := [
		{
			"source": "actor show kona idle at 2",
			"type": KND_Dialogue.Type.DISPLAY_ACTOR,
			"property": "character_name",
			"value": "kona",
		},
		{
			"source": "actor exit kona",
			"type": KND_Dialogue.Type.EXIT_ACTOR,
			"property": "exit_actor",
			"value": "kona",
		},
		{
			"source": "actor change kona happy",
			"type": KND_Dialogue.Type.ACTOR_CHANGE_STATE,
			"property": "change_state",
			"value": "happy",
		},
		{
			"source": "actor move kona 3",
			"type": KND_Dialogue.Type.MOVE_ACTOR,
			"property": "target_move_chara",
			"value": "kona",
		},
		{
			"source": "actor motion kona wave",
			"type": KND_Dialogue.Type.ACTOR_MOTION,
			"property": "motion_name",
			"value": "wave",
		},
	]

	for actor_case: Dictionary in cases:
		var dialogue := compiler.compile_line(actor_case.source, 1, "architecture-test.ks")
		_expect(dialogue != null, "actor command compiles: %s" % actor_case.source)
		if dialogue == null:
			continue
		_expect_equal(
			dialogue.dialog_type, actor_case.type, "actor command emits the expected dialogue type"
		)
		_expect_equal(
			dialogue.get(actor_case.property),
			actor_case.value,
			"actor command preserves its payload"
		)


func _test_actor_state_transition() -> void:
	var host := Control.new()
	var visual := ColorRect.new()
	visual.modulate = Color(0.8, 0.7, 0.6, 0.65)
	host.add_child(visual)
	get_root().add_child(host)
	await process_frame

	var applied_statuses: Array[String] = []
	var events: Array[String] = []
	var completions: Array[bool] = []
	var controller := KND_ActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return visual,
		func(status_name: String) -> bool:
			applied_statuses.append(status_name)
			return not status_name.is_empty()
	)
	controller.transition_started.connect(
		func(status_name: String) -> void: events.append("started:" + status_name)
	)
	controller.status_applied.connect(
		func(status_name: String) -> void: events.append("applied:" + status_name)
	)
	controller.transition_finished.connect(
		func(status_name: String, succeeded: bool) -> void:
			events.append("finished:%s:%s" % [status_name, succeeded])
	)

	controller.request("idle", 0.0, func(succeeded: bool) -> void: completions.append(succeeded))
	_expect_equal(
		events,
		["started:idle", "applied:idle", "finished:idle:true"],
		"immediate status changes preserve signal order"
	)
	_expect_equal(completions, [true], "immediate status changes complete exactly once")
	_expect(not controller.is_transitioning(), "immediate status changes leave no active request")
	_expect_approx(visual.modulate.a, 0.65, "immediate status changes preserve alpha")

	events.clear()
	completions.clear()
	controller.request("happy", 0.1, func(succeeded: bool) -> void: completions.append(succeeded))
	_expect(controller.is_transitioning(), "animated status changes expose active state")
	await create_timer(0.25).timeout
	_expect_equal(
		events,
		["started:happy", "applied:happy", "finished:happy:true"],
		"animated status changes preserve signal order"
	)
	_expect_equal(completions, [true], "animated status changes complete exactly once")
	_expect(not controller.is_transitioning(), "animated status changes clear active state")
	_expect_approx(visual.modulate.a, 0.65, "animated status changes restore alpha")
	_expect_equal(host.get_child_count(), 1, "status transitions do not duplicate visual nodes")

	events.clear()
	completions.clear()
	controller.request("sad", 1.0, func(succeeded: bool) -> void: completions.append(succeeded))
	controller.request("angry", 0.0, func(succeeded: bool) -> void: completions.append(succeeded))
	_expect_equal(
		completions, [false, true], "superseded and replacement requests each complete exactly once"
	)
	_expect(events.has("finished:sad:false"), "superseded status changes report failed completion")
	_expect(
		events.has("finished:angry:true"), "replacement status changes report successful completion"
	)
	_expect_equal(applied_statuses.back(), "angry", "only the replacement status is applied")
	_expect_approx(visual.modulate.a, 0.65, "cancelling a transition restores alpha")
	_expect_equal(host.get_child_count(), 1, "cancelling transitions leaves no temporary nodes")

	completions.clear()
	controller.request("", 0.0, func(succeeded: bool) -> void: completions.append(succeeded))
	_expect_equal(completions, [false], "invalid status changes fail without hanging")

	var no_visual_completions: Array[bool] = []
	var no_visual_controller := KND_ActorStateTransitionController.new(
		host, func() -> CanvasItem: return null, func(_status_name: String) -> bool: return true
	)
	no_visual_controller.request(
		"voice_only", 1.0, func(succeeded: bool) -> void: no_visual_completions.append(succeeded)
	)
	_expect_equal(
		no_visual_completions,
		[true],
		"non-visual character scenes fall back to immediate status changes"
	)

	host.queue_free()
	await process_frame


func _test_acting_interface_state_change() -> void:
	var acting_interface := KND_ActingInterface.new()
	var actor := FakeActor.new()
	acting_interface.actor_nodes["Kona"] = actor
	acting_interface.actor_dict["Kona"] = {"id": "Kona", "state": "idle"}
	var completion_count := [0]
	acting_interface.character_state_changed.connect(func() -> void: completion_count[0] += 1)

	acting_interface.change_actor_state("Kona", "happy")
	_expect_equal(actor.requested_statuses, ["happy"], "acting interface forwards target status")
	_expect_approx(
		actor.last_transition_duration,
		acting_interface.actor_state_fade_duration,
		"acting interface forwards configured transition duration"
	)
	_expect_equal(
		acting_interface.actor_dict["Kona"]["state"],
		"happy",
		"successful state changes persist the target state"
	)
	_expect_equal(completion_count[0], 1, "successful state changes complete exactly once")

	actor.next_result = false
	acting_interface.change_actor_state("Kona", "missing")
	_expect_equal(
		acting_interface.actor_dict["Kona"]["state"],
		"happy",
		"failed state changes roll back persisted actor state"
	)
	_expect_equal(completion_count[0], 2, "failed state changes still release dialogue flow")

	actor.next_result = true
	acting_interface.enable_actor_state_fade = false
	acting_interface.change_actor_state("Kona", "idle")
	_expect_approx(
		actor.last_transition_duration,
		0.0,
		"disabling state fades uses the immediate transition path"
	)
	_expect_equal(completion_count[0], 3, "immediate state changes complete exactly once")

	actor.free()
	acting_interface.free()


func _test_dialogue_services() -> void:
	var manager := KND_DialogueManager.new()
	manager.variable_store = KND_VariableStore.new()
	manager.variable_store.set_value("score", 10)
	manager._temp_variables["speaker"] = "Kona"

	_expect_equal(
		manager._interpolate_variables("Score: %score / $speaker"),
		"Score: 10 / Kona",
		"dialogue service interpolates persistent and temporary variables"
	)
	_expect(not manager.save_game(1), "save facade fails safely without a save system")

	var required_properties := [
		"start_dialogue_shot",
		"chara_list",
		"background_list",
		"bgm_list",
		"voice_list",
		"soundeffect_list",
		"save_system",
		"_auto_play_button",
		"_settings_button",
	]
	var available_properties: Array[StringName] = []
	for property: Dictionary in manager.get_property_list():
		available_properties.append(property.name)
	for property_name: String in required_properties:
		_expect(
			available_properties.has(property_name),
			"dialogue manager exposes normalized serialized property: %s" % property_name
		)
	_expect(
		not available_properties.has("_autoPlayButton"),
		"dialogue manager no longer exposes the legacy autoplay property"
	)
	_expect(
		not available_properties.has("_settingsButton"),
		"dialogue manager no longer exposes the legacy settings property"
	)
	manager.free()


func _test_analyzer_control_flow() -> void:
	var script := KS_AST.ScriptNode.new()
	var show_actor := _actor_node("show", "kona", 1)
	var choice := KS_AST.ChoiceGroupNode.new()
	choice.line = 2
	var left_option := KS_AST.ChoiceOption.new()
	left_option.branch_target = "left"
	var right_option := KS_AST.ChoiceOption.new()
	right_option.branch_target = "right"
	choice.options = [left_option, right_option]
	var left_branch := KS_AST.BranchNode.new()
	left_branch.branch_id = "left"
	left_branch.body = [_actor_node("exit", "kona", 4), KS_AST.EndNode.new()]
	var right_branch := KS_AST.BranchNode.new()
	right_branch.branch_id = "right"
	right_branch.body = [_actor_node("change", "kona", 7), KS_AST.EndNode.new()]
	script.statements = [show_actor, choice, left_branch, right_branch]

	var analyzer := KS_Analyzer.new()
	analyzer.analyze(script, "control-flow.ks")
	_expect_equal(
		analyzer.get_warnings().size(),
		0,
		"mutually exclusive branches receive independent actor state"
	)

	var conditional_script := KS_AST.ScriptNode.new()
	var conditional := KS_AST.IfElseNode.new()
	conditional.line = 1
	conditional.if_body = [_actor_node("show", "kona", 2)]
	conditional_script.statements = [conditional, _actor_node("change", "kona", 4)]
	analyzer.analyze(conditional_script, "conditional.ks")
	_expect_equal(
		analyzer.get_warnings().size(),
		1,
		"actor use after a conditional show reports one possible-path warning"
	)
	_expect(
		analyzer.get_warnings()[0].contains("部分路径"),
		"conditional actor warning distinguishes partial-path availability"
	)


func _actor_node(action: String, actor_name: String, line: int) -> KS_AST.ActorNode:
	var actor := KS_AST.ActorNode.new()
	actor.action = action
	actor.actor_name = actor_name
	actor.line = line
	return actor


func _test_save_system_contract() -> void:
	var save_system := KND_SaveSystem.new()
	save_system.save_dir = "user://konado_architecture_tests"
	var manager := KND_DialogueManager.new()
	save_system.dialogue_manager = manager
	save_system.save_strategy = {
		"include_dialogue_state": false,
		"include_variables": false,
		"include_audio_state": false,
		"include_actor_state": false,
		"include_background_state": false,
	}
	_expect(save_system.save_game(0), "save system writes a valid snapshot")
	_expect(save_system.delete_save(0), "save system reports successful deletion as true")
	_expect(not FileAccess.file_exists(save_system._get_save_path(0)), "deleted save is absent")
	save_system.dialogue_manager = null
	manager.free()
	save_system.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: " + message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if is_equal_approx(actual, expected):
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])
