extends SceneTree

var _failures := 0


class FakeActor:
	extends KND_Actor

	var requested_statuses: Array[String] = []
	var last_transition_duration := -1.0
	var next_result := true
	var before_status_applied := Callable()
	var delay_next_move := false
	var delay_next_status := false
	var validation_result := true
	var validation_count := 0
	var validation_results: Array[bool] = []
	var before_status_validation := Callable()
	var fake_move_in_progress := false

	func apply_character_status(
		status_name: String, transition_duration: float = 0.0, completion: Callable = Callable()
	) -> void:
		requested_statuses.append(status_name)
		last_transition_duration = transition_duration
		var hook := before_status_applied
		before_status_applied = Callable()
		if hook.is_valid():
			hook.call()
		if delay_next_status:
			delay_next_status = false
			_finish_fake_status.call_deferred(status_name, completion, next_result)
			return
		_finish_fake_status(status_name, completion, next_result)

	func _finish_fake_status(status_name: String, completion: Callable, succeeded: bool) -> void:
		if succeeded:
			actor_status_applied.emit(status_name)
		if completion.is_valid():
			completion.call(succeeded)

	func set_stage_position(_target_h_division: int, _target_position: int) -> bool:
		if fake_move_in_progress:
			return false
		if not delay_next_move:
			return true
		delay_next_move = false
		fake_move_in_progress = true
		_emit_fake_move.call_deferred()
		return true

	func _emit_fake_move() -> void:
		fake_move_in_progress = false
		actor_moved.emit()

	func _is_stage_position_moving() -> bool:
		return fake_move_in_progress

	func _can_apply_character_status(_status_name: String) -> bool:
		validation_count += 1
		var hook := before_status_validation
		before_status_validation = Callable()
		if hook.is_valid():
			hook.call()
		if not validation_results.is_empty():
			return validation_results.pop_front()
		return validation_result


class DeferredLegacyActor:
	extends KND_Actor

	var saved_completion := Callable()

	func apply_character_status(
		_status_name: String, _transition_duration: float = 0.0, completion: Callable = Callable()
	) -> void:
		saved_completion = completion

	func _can_apply_character_status(_status_name: String) -> bool:
		return true


class FakeActingInterface:
	extends KND_ActingInterface

	func _init() -> void:
		_chara_controler = Control.new()
		add_child(_chara_controler)
		_konado_actor_template = (
			load("res://addons/konado/template/default/character/character_template.tscn")
			as PackedScene
		)

	func apply_background_tint_to_characters() -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_actor_commands()
	_test_analyzer_control_flow()
	_test_script_protection()
	_test_dialogue_services()
	_test_actor_status_validation_reentry()
	_test_acting_interface_state_change()
	_test_new_actor_state_transaction()
	await _test_existing_actor_state_transaction()
	await _test_repeated_move_command()
	await _test_actor_state_request_lifecycle()
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


func _test_actor_status_validation_reentry() -> void:
	var actor := FakeActor.new()
	actor._status_node = Node.new()
	actor.add_child(actor._status_node)
	var results: Array[String] = []

	actor.before_status_validation = func() -> void:
		actor.validation_result = false
		actor._try_apply_character_status(
			"invalid_inner",
			0.0,
			func(succeeded: bool) -> void: results.append("inner:%s" % succeeded)
		)
		actor.validation_result = true
	var invalid_reentry_accepted := actor._try_apply_character_status(
		"outer", 0.0, func(succeeded: bool) -> void: results.append("outer:%s" % succeeded)
	)
	_expect_equal(
		results,
		["inner:false", "outer:true"],
		"invalid validation reentry does not steal actor request ownership"
	)
	_expect(invalid_reentry_accepted, "the outer request remains accepted after invalid reentry")

	results.clear()
	actor.before_status_validation = func() -> void:
		actor._try_apply_character_status(
			"replacement",
			0.0,
			func(succeeded: bool) -> void: results.append("replacement:%s" % succeeded)
		)
	var stale_outer_accepted := actor._try_apply_character_status(
		"stale_outer", 0.0, func(succeeded: bool) -> void: results.append("outer:%s" % succeeded)
	)
	_expect_equal(
		results,
		["replacement:true", "outer:false"],
		"valid validation reentry supersedes the older actor request"
	)
	_expect(not stale_outer_accepted, "the superseded outer request reports rejection")
	actor.free()


func _test_acting_interface_state_change() -> void:
	var acting_interface := KND_ActingInterface.new()
	var actor := FakeActor.new()
	actor._status_node = Node.new()
	actor.add_child(actor._status_node)
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
	_expect_equal(actor.validation_count, 1, "successful state changes validate exactly once")
	_expect_equal(
		acting_interface._actor_state_requests.size(),
		0,
		"synchronous state changes release their lifecycle coordinator"
	)

	actor.validation_results = [false, true]
	actor.next_result = false
	acting_interface.change_actor_state("Kona", "missing")
	_expect_equal(
		acting_interface.actor_dict["Kona"]["state"],
		"happy",
		"failed state changes preserve the last applied actor state"
	)
	_expect_equal(completion_count[0], 2, "failed state changes still release dialogue flow")
	_expect_equal(actor.validation_count, 2, "rejected state changes do not validate twice")

	actor.next_result = true
	acting_interface.enable_actor_state_fade = false
	acting_interface.change_actor_state("Kona", "idle")
	_expect_approx(
		actor.last_transition_duration,
		0.0,
		"disabling state fades uses the immediate transition path"
	)
	_expect_equal(completion_count[0], 3, "immediate state changes complete exactly once")

	actor.before_status_applied = func() -> void:
		acting_interface.change_actor_state("Kona", "newer")
	acting_interface.change_actor_state("Kona", "stale")
	_expect_equal(
		acting_interface.actor_dict["Kona"]["state"],
		"newer",
		"reentrant state changes cannot be overwritten by stale completions"
	)
	_expect_equal(completion_count[0], 5, "reentrant state changes complete both requests once")

	actor.free()
	acting_interface.free()


func _test_existing_actor_state_transaction() -> void:
	var acting_interface := FakeActingInterface.new()
	var actor := FakeActor.new()
	actor._status_node = Node.new()
	actor.add_child(actor._status_node)
	acting_interface.actor_nodes["Kona"] = actor
	acting_interface.actor_dict["Kona"] = {"id": "Kona", "h_division": 5, "pos": 3, "state": "idle"}

	actor.next_result = false
	acting_interface._update_existing_character(actor, "Kona", 4, 2, "missing")
	_expect_equal(
		acting_interface.actor_dict["Kona"],
		{"id": "Kona", "h_division": 4, "pos": 2, "state": "idle"},
		"failed reused states preserve the committed status while keeping valid position updates"
	)

	actor.next_result = true
	acting_interface._update_existing_character(actor, "Kona", 4, 2, "happy")
	_expect_equal(
		acting_interface.actor_dict["Kona"]["state"],
		"happy",
		"successful reused states commit their target status"
	)

	actor.before_status_applied = func() -> void:
		acting_interface._update_existing_character(actor, "Kona", 4, 2, "newer")
	acting_interface._update_existing_character(actor, "Kona", 4, 2, "stale")
	_expect_equal(
		acting_interface.actor_dict["Kona"]["state"],
		"newer",
		"reentrant reused-state updates cannot be overwritten by stale requests"
	)

	actor.validation_result = false
	actor.slot = Control.new()
	actor.add_child(actor.slot)
	actor.use_tween = true
	actor.animation_time = 1.0
	actor.h_division = 5
	actor.h_character_position = 3
	actor.delay_next_move = true
	var shown_count := [0]
	acting_interface.character_shown.connect(func() -> void: shown_count[0] += 1)
	acting_interface._update_existing_character(actor, "Kona", 4, 2, "invalid")
	acting_interface._update_existing_character(actor, "Kona", 5, 3, "newer")
	_expect_equal(
		shown_count[0],
		0,
		"repeated upserts wait for an already accepted movement instead of completing early"
	)
	await process_frame
	_expect_equal(shown_count[0], 2, "one movement completion releases both waiting upserts")
	_expect_equal(
		acting_interface.actor_dict["Kona"]["state"],
		"newer",
		"a valid replacement state remains committed while both updates wait for movement"
	)

	actor.validation_result = true
	actor.validation_count = 0
	actor.delay_next_status = true
	acting_interface._update_existing_character(actor, "Kona", 5, 3, "async")
	_expect_equal(shown_count[0], 2, "asynchronous states keep reused actor flow pending")
	_expect_equal(
		acting_interface._actor_state_requests.size(),
		1,
		"asynchronous state changes retain one lifecycle coordinator while pending"
	)
	_expect_equal(
		acting_interface.actor_dict["Kona"]["state"],
		"newer",
		"asynchronous states are not persisted before they are applied"
	)
	_expect_equal(actor.validation_count, 1, "state requests validate exactly once")
	await process_frame
	_expect_equal(shown_count[0], 3, "asynchronous state completion releases reused actor flow")
	_expect_equal(
		acting_interface.actor_dict["Kona"]["state"],
		"async",
		"asynchronous reused states persist after successful application"
	)
	_expect_equal(
		acting_interface._actor_state_requests.size(),
		0,
		"asynchronous state changes release their lifecycle coordinator after completion"
	)

	actor.free()
	acting_interface.free()


func _test_repeated_move_command() -> void:
	var acting_interface := FakeActingInterface.new()
	var actor := FakeActor.new()
	acting_interface.actor_nodes["Kona"] = actor
	actor.actor_moved.connect(acting_interface._on_character_moved)
	actor.delay_next_move = true
	var moved_count := [0]
	acting_interface.character_moved.connect(func() -> void: moved_count[0] += 1)

	acting_interface.move_actor("Kona", 2)
	acting_interface.move_actor("Kona", 2)
	_expect_equal(
		moved_count[0],
		0,
		"repeating a move to its in-progress target does not emit premature completion"
	)
	await process_frame
	_expect_equal(moved_count[0], 1, "the active move emits one completion when it actually ends")

	actor.free()
	acting_interface.free()


func _test_actor_state_request_lifecycle() -> void:
	var acting_interface := FakeActingInterface.new()
	get_root().add_child(acting_interface)
	await process_frame

	var changed_actor := DeferredLegacyActor.new()
	changed_actor._status_node = Node.new()
	changed_actor.add_child(changed_actor._status_node)
	acting_interface._chara_controler.add_child(changed_actor)
	changed_actor.slot = Control.new()
	changed_actor.add_child(changed_actor.slot)
	acting_interface.actor_nodes["Changed"] = changed_actor
	acting_interface.actor_dict["Changed"] = {"id": "Changed", "state": "idle"}
	var changed_count := [0]
	acting_interface.character_state_changed.connect(func() -> void: changed_count[0] += 1)
	acting_interface.change_actor_state("Changed", "happy")
	var changed_completion := changed_actor.saved_completion
	acting_interface.delete_all_actor(true)
	_expect_equal(
		changed_count[0],
		1,
		"deleting an actor completes a pending state command instead of hanging dialogue flow"
	)
	_expect_equal(
		acting_interface._actor_state_requests.size(),
		0,
		"actor deletion releases the pending state lifecycle coordinator"
	)
	changed_completion.call(true)
	_expect_equal(
		changed_count[0],
		1,
		"late custom state completions are ignored after the actor leaves the tree"
	)
	_expect(
		not acting_interface.actor_dict.has("Changed"),
		"late custom state completions cannot restore deleted actor data"
	)

	var reused_actor := DeferredLegacyActor.new()
	reused_actor._status_node = Node.new()
	reused_actor.add_child(reused_actor._status_node)
	acting_interface._chara_controler.add_child(reused_actor)
	reused_actor.slot = Control.new()
	reused_actor.add_child(reused_actor.slot)
	acting_interface.actor_nodes["Reused"] = reused_actor
	acting_interface.actor_dict["Reused"] = {
		"id": "Reused", "h_division": 5, "pos": 3, "state": "idle"
	}
	var shown_count := [0]
	acting_interface.character_shown.connect(func() -> void: shown_count[0] += 1)
	acting_interface._update_existing_character(reused_actor, "Reused", 5, 3, "happy")
	var reused_completion := reused_actor.saved_completion
	acting_interface.delete_all_actor(true)
	_expect_equal(
		shown_count[0], 1, "deleting a reused actor releases a pending show command exactly once"
	)
	reused_completion.call(true)
	_expect_equal(
		shown_count[0], 1, "late reused-actor completions cannot finish the same command twice"
	)

	acting_interface.queue_free()
	await process_frame
	reused_completion.call(true)


func _test_new_actor_state_transaction() -> void:
	var acting_interface := FakeActingInterface.new()
	var character_scene := load("res://sample/demo/sample_character.tscn") as PackedScene
	var shown_count := [0]
	acting_interface.character_shown.connect(func() -> void: shown_count[0] += 1)
	acting_interface.show_character("Kona", 5, 3, "missing", character_scene)
	_expect(
		not acting_interface.actor_dict.has("Kona"),
		"failed initial states never enter the persisted actor dictionary"
	)
	_expect(
		not acting_interface.actor_nodes.has("Kona"),
		"failed initial states never enter the live actor cache"
	)
	_expect_equal(
		acting_interface.get_chara_node("Kona"),
		null,
		"failed initial actors are removed immediately and cannot shadow a retry"
	)
	_expect_equal(shown_count[0], 1, "failed initial states still release dialogue flow once")

	acting_interface.show_character("InvalidLayer", 5, 3, "介绍正常", character_scene, character_scene)
	_expect(
		not acting_interface.actor_dict.has("InvalidLayer"),
		"invalid motion layers never enter the persisted actor dictionary"
	)
	_expect(
		not acting_interface.actor_nodes.has("InvalidLayer"),
		"invalid motion layers never enter the live actor cache"
	)
	_expect_equal(shown_count[0], 2, "invalid motion layers still release dialogue flow once")

	acting_interface.show_character("Kona", 5, 3, "介绍正常", character_scene)
	_expect(
		acting_interface.actor_dict.has("Kona"),
		"a valid retry after failed initialization commits actor data"
	)
	_expect(
		acting_interface.actor_nodes.has("Kona"),
		"a valid retry after failed initialization enters the live actor cache"
	)
	var retry_actor := acting_interface.get_chara_node("Kona") as KND_Actor
	_expect(retry_actor != null, "a valid retry creates a live actor node")
	if retry_actor:
		_expect_equal(
			(retry_actor._status_node as KND_CharacterSceneBase).current_status_name,
			"介绍正常",
			"a retry applies its own initial state instead of retaining failed data"
		)
	acting_interface.free()


func _test_dialogue_services() -> void:
	var manager := KND_DialogueManager.new()
	manager.variable_store = KND_VariableStore.new()
	manager.variable_store.set_value("score", 10)
	manager.variable_store.set_value("好感度", 42)
	manager._temp_variables["speaker"] = "Kona"
	manager._temp_variables["奖金"] = 100

	_expect_equal(
		manager._interpolate_variables("Score: %score / $speaker"),
		"Score: 10 / Kona",
		"dialogue service interpolates persistent and temporary variables"
	)
	_expect_equal(
		manager._interpolate_variables("好感：%好感度 / 奖金：$奖金"),
		"好感：42 / 奖金：100",
		"dialogue service interpolates Unicode variable names"
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


func _test_script_protection() -> void:
	var dialogue := KND_Dialogue.new()
	dialogue.node_id = "opening"
	dialogue.dialog_type = KND_Dialogue.Type.ORDINARY_DIALOG
	dialogue.character_id = "Kona"
	dialogue.dialog_content = "Only the runtime should recover this dialogue."
	var dialogues: Array[KND_Dialogue] = [dialogue]
	var key := PackedByteArray()
	key.resize(KND_ScriptProtection.KEY_SIZE)
	for index in range(key.size()):
		key[index] = index

	var protected := KND_ScriptProtection.protect(
		dialogues, key, "res://tests/dialogue/protected.ks"
	)
	_expect(protected.get("ok", false), "script protection encrypts compiled dialogue nodes")
	if not protected.get("ok", false):
		return
	_expect(
		not _contains_bytes(protected["ciphertext"], dialogue.dialog_content.to_utf8_buffer()),
		"protected payload does not contain plaintext dialogue bytes"
	)
	var encryption_key := KND_ScriptProtection._derive_subkey(
		key,
		KND_ScriptProtection.ENCRYPTION_KEY_CONTEXT,
		protected["iv"],
		"res://tests/dialogue/protected.ks"
	)
	var authentication_key := KND_ScriptProtection._derive_subkey(
		key,
		KND_ScriptProtection.AUTHENTICATION_KEY_CONTEXT,
		protected["iv"],
		"res://tests/dialogue/protected.ks"
	)
	_expect(
		encryption_key != authentication_key,
		"script protection derives independent encryption and authentication keys"
	)

	var restored := KND_ScriptProtection.unprotect(
		protected["version"],
		protected["serialized_size"],
		protected["iv"],
		protected["wrapped_key"],
		protected["ciphertext"],
		protected["mac"],
		"res://tests/dialogue/protected.ks"
	)
	_expect(restored.get("ok", false), "script protection restores valid dialogue payloads")
	if restored.get("ok", false):
		var restored_dialogues: Array[KND_Dialogue] = restored["dialogues"]
		_expect_equal(restored_dialogues.size(), 1, "script protection preserves node count")
		_expect_equal(
			restored_dialogues[0].dialog_content,
			dialogue.dialog_content,
			"script protection preserves dialogue content"
		)

	var tampered_mac: PackedByteArray = protected["mac"].duplicate()
	tampered_mac[0] ^= 1
	var tampered := KND_ScriptProtection.unprotect(
		protected["version"],
		protected["serialized_size"],
		protected["iv"],
		protected["wrapped_key"],
		protected["ciphertext"],
		tampered_mac,
		"res://tests/dialogue/protected.ks"
	)
	_expect(not tampered.get("ok", false), "script protection rejects modified payloads")

	var tampered_size := KND_ScriptProtection.unprotect(
		protected["version"],
		protected["serialized_size"] + 1,
		protected["iv"],
		protected["wrapped_key"],
		protected["ciphertext"],
		protected["mac"],
		"res://tests/dialogue/protected.ks"
	)
	_expect(
		not tampered_size.get("ok", false), "script protection authenticates serialized metadata"
	)

	var tampered_ciphertext: PackedByteArray = protected["ciphertext"].duplicate()
	tampered_ciphertext[0] ^= 1
	var tampered_payload := KND_ScriptProtection.unprotect(
		protected["version"],
		protected["serialized_size"],
		protected["iv"],
		protected["wrapped_key"],
		tampered_ciphertext,
		protected["mac"],
		"res://tests/dialogue/protected.ks"
	)
	_expect(not tampered_payload.get("ok", false), "script protection rejects modified ciphertext")

	var wrong_path := KND_ScriptProtection.unprotect(
		protected["version"],
		protected["serialized_size"],
		protected["iv"],
		protected["wrapped_key"],
		protected["ciphertext"],
		protected["mac"],
		"res://tests/dialogue/renamed.ks"
	)
	_expect(not wrong_path.get("ok", false), "script protection authenticates the source path")

	var wrong_version := KND_ScriptProtection.unprotect(
		protected["version"] + 1,
		protected["serialized_size"],
		protected["iv"],
		protected["wrapped_key"],
		protected["ciphertext"],
		protected["mac"],
		"res://tests/dialogue/protected.ks"
	)
	_expect(not wrong_version.get("ok", false), "script protection rejects unsupported formats")

	var oversized_payload := KND_ScriptProtection.unprotect(
		protected["version"],
		KND_ScriptProtection.MAX_SERIALIZED_SIZE + 1,
		protected["iv"],
		protected["wrapped_key"],
		protected["ciphertext"],
		protected["mac"],
		"res://tests/dialogue/protected.ks"
	)
	_expect(
		not oversized_payload.get("ok", false),
		"script protection rejects oversized serialized metadata"
	)

	var invalid_padding := PackedByteArray()
	invalid_padding.resize(KND_ScriptProtection.BLOCK_SIZE)
	invalid_padding[invalid_padding.size() - 2] = 1
	invalid_padding[invalid_padding.size() - 1] = 2
	_expect(
		KND_ScriptProtection._remove_pkcs7_padding(invalid_padding).is_empty(),
		"script protection rejects malformed PKCS#7 padding"
	)

	var shot := KND_Shot.new()
	shot.ks_path = "res://tests/dialogue/protected.ks"
	shot.dialogues = dialogues
	_expect(shot.protect_script_for_export(key), "KND_Shot accepts export-time protection")
	_expect(shot.is_script_protected(), "KND_Shot records protected export state")
	var runtime_dialogues := shot.dialogues
	_expect_equal(runtime_dialogues.size(), 1, "KND_Shot decrypts on first runtime access")
	_expect_equal(
		runtime_dialogues[0].dialog_content,
		dialogue.dialog_content,
		"KND_Shot transparently restores dialogue content"
	)
	_expect(not shot.is_script_protected(), "KND_Shot clears encrypted buffers after restoration")


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


func _contains_bytes(haystack: PackedByteArray, needle: PackedByteArray) -> bool:
	if needle.is_empty():
		return true
	if needle.size() > haystack.size():
		return false
	for start in range(haystack.size() - needle.size() + 1):
		var matches := true
		for offset in range(needle.size()):
			if haystack[start + offset] == needle[offset]:
				continue
			matches = false
			break
		if matches:
			return true
	return false
