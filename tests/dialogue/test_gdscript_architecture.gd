extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_actor_commands()
	_test_analyzer_control_flow()
	_test_dialogue_services()
	_test_save_system_contract()
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
