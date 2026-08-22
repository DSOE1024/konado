extends SceneTree

const ACTOR_SCENE := preload(
	"res://addons/konado/templates/default/character/character_template.tscn"
)
const MOTION_LAYER_SCENE := preload(
	"res://addons/konado/templates/default/character/konado_actor_motion_layer.tscn"
)
const BACKGROUND_TRANSITION_LAYER_SCRIPT := preload(
	"res://addons/konado/runtime/stage/background/konado_background_transition_layer.gd"
)
const STAGE_TREE_BUILDER := preload(
	"res://addons/konado/runtime/stage/konado_stage_tree_builder.gd"
)

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var detached_motion_layer := MOTION_LAYER_SCENE.instantiate() as KonadoActorMotionLayer
	detached_motion_layer.animation_player = null
	detached_motion_layer.motion_node = null
	detached_motion_layer.framing_layer = null
	detached_motion_layer.mount_node = null
	_expect(
		detached_motion_layer.set_framing_profile(null),
		"a convention-based custom motion layer resolves its framing nodes before entering SceneTree",
	)
	_expect_equal(
		detached_motion_layer.get_mount_node().name,
		"CharacterMount",
		"a detached motion layer resolves its character mount by the documented node path",
	)
	detached_motion_layer.free()

	var actor := ACTOR_SCENE.instantiate() as KonadoActor
	get_root().add_child(actor)
	await process_frame
	_expect(actor.has_actor_framing(&"medium"), "default actor exposes built-in framing presets")
	_expect(actor.restore_actor_framing(&"medium"), "built-in medium framing can be restored")
	_expect_equal(actor.get_actor_framing(), &"medium", "actor commits the restored framing")
	_expect(
		actor.motion_layer.framing_layer.scale.is_equal_approx(Vector2(1.3, 1.3)),
		"medium framing applies an actor-local scale",
	)
	var framing_layer := actor.motion_layer.framing_layer
	framing_layer.size = Vector2(800.0, 600.0)
	framing_layer._on_resized()
	_expect(
		framing_layer.pivot_offset.is_equal_approx(
			framing_layer.size * framing_layer.framing_pivot
		),
		"normalized framing pivots remain correct after viewport resizing",
	)
	_expect(actor.set_motion_layer_scene(MOTION_LAYER_SCENE), "motion layer can be replaced")
	_expect_equal(
		actor.get_actor_framing(),
		&"medium",
		"replacing a motion layer preserves the logical framing",
	)
	_expect_equal(
		actor.motion_layer.get_current_framing_id(),
		&"medium",
		"a motion layer keeps preconfigured framing when it enters SceneTree",
	)
	var replacement_completion: Array[Variant] = []
	_expect(
		actor.apply_actor_framing(
			&"close",
			1.0,
			"linear",
			func(ok: bool, reason: String): replacement_completion.assign([ok, reason])
		),
		"framing can start before a motion-layer replacement",
	)
	_expect(
		actor.set_motion_layer_scene(MOTION_LAYER_SCENE), "an active motion layer can be replaced"
	)
	_expect_equal(
		replacement_completion,
		[true, "motion_layer_replaced"],
		"motion-layer replacement settles an in-flight framing request",
	)

	var completions: Array[Dictionary] = []
	_expect(
		actor.apply_actor_framing(
			&"close",
			1.0,
			"ease_in_out",
			func(ok: bool, reason: String): completions.append({"ok": ok, "reason": reason}),
		),
		"animated framing request is accepted",
	)
	_expect(
		actor.apply_actor_framing(
			&"full",
			0.0,
			"linear",
			func(ok: bool, reason: String): completions.append({"ok": ok, "reason": reason}),
		),
		"replacement framing request is accepted",
	)
	_expect_equal(completions.size(), 2, "superseded and replacement requests both complete")
	if completions.size() == 2:
		_expect(
			not completions[0].ok and completions[0].reason == "superseded",
			"superseded framing has a stable cancellation result",
		)
		_expect(completions[1].ok, "replacement framing completes successfully")
	var reentrant_results: Array[Dictionary] = []
	var reentrant_completion := func(inner_ok: bool, inner_reason: String) -> void:
		(
			reentrant_results
			. append(
				{
					"request": "reentrant",
					"ok": inner_ok,
					"reason": inner_reason,
				}
			)
		)
	var first_completion := func(ok: bool, reason: String) -> void:
		reentrant_results.append({"request": "first", "ok": ok, "reason": reason})
		if reason == "superseded":
			actor.apply_actor_framing(&"full", 0.0, "linear", reentrant_completion)
	_expect(
		actor.apply_actor_framing(&"medium", 1.0, "linear", first_completion),
		"a framing request can start before a reentrant supersession",
	)
	var outer_completion := func(ok: bool, reason: String) -> void:
		reentrant_results.append({"request": "outer", "ok": ok, "reason": reason})
	_expect(
		actor.apply_actor_framing(&"close", 1.0, "linear", outer_completion),
		"the outer superseding request remains accepted when a callback reenters",
	)
	_expect_equal(
		actor.get_actor_framing(),
		&"full",
		"the newest reentrant framing request owns the logical actor state",
	)
	_expect_equal(
		actor.motion_layer.get_current_framing_id(),
		&"full",
		"the newest reentrant framing request owns the rendered actor state",
	)
	_expect(
		(
			reentrant_results.size() == 3
			and not bool(reentrant_results[0].ok)
			and not bool(reentrant_results[1].ok)
			and bool(reentrant_results[2].ok)
		),
		"reentrant supersession terminates every accepted request exactly once",
	)
	var restore_completion := func(_ok: bool, reason: String) -> void:
		if reason == "restored":
			actor.apply_actor_framing(&"full", 0.0, "linear")
	_expect(
		actor.apply_actor_framing(&"medium", 1.0, "linear", restore_completion),
		"framing can start before an immediate restore",
	)
	_expect(actor.restore_actor_framing(&"close"), "immediate framing restore is accepted")
	_expect_equal(
		actor.get_actor_framing(),
		&"full",
		"a reentrant request remains the logical owner after an immediate restore",
	)
	_expect_equal(
		actor.motion_layer.get_current_framing_id(),
		&"full",
		"a reentrant request remains the rendered owner after an immediate restore",
	)
	var layer_replacement_completion := func(_ok: bool, reason: String) -> void:
		if reason == "motion_layer_replaced":
			actor.apply_actor_framing(&"full", 0.0, "linear")
	_expect(
		actor.apply_actor_framing(&"medium", 1.0, "linear", layer_replacement_completion),
		"framing can start before a reentrant motion-layer replacement",
	)
	_expect(
		not actor.set_motion_layer_scene(MOTION_LAYER_SCENE),
		"a motion-layer replacement cannot overwrite a newer reentrant framing request",
	)
	_expect_equal(
		actor.get_actor_framing(),
		&"full",
		"aborting a stale motion-layer replacement preserves the newer logical framing",
	)
	_expect_equal(
		actor.motion_layer.get_current_framing_id(),
		&"full",
		"aborting a stale motion-layer replacement preserves the newer rendered framing",
	)
	var preserved_character := KonadoCharacterSceneBase.new()
	actor.motion_layer.get_mount_node().add_child(preserved_character)
	actor._status_node = preserved_character
	var visual_reentry_completion := func(_ok: bool, reason: String) -> void:
		if reason == "motion_layer_replaced":
			actor.apply_actor_framing(&"full", 0.0, "linear")
	_expect(
		actor.apply_actor_framing(&"medium", 1.0, "linear", visual_reentry_completion),
		"framing can restart before testing transactional visual preservation",
	)
	_expect(
		not actor.set_motion_layer_scene(MOTION_LAYER_SCENE),
		"reentrant ownership aborts a stale motion-layer replacement",
	)
	_expect(
		(
			actor._status_node == preserved_character
			and is_instance_valid(preserved_character)
			and preserved_character.get_parent() == actor.motion_layer.get_mount_node()
		),
		"aborting a stale motion-layer replacement preserves the active character scene",
	)
	var committed_framing := actor.get_actor_framing()
	_expect(
		not actor.apply_actor_framing(&"close", NAN, "linear"),
		"direct actor calls reject non-finite durations",
	)
	_expect(
		not actor.apply_actor_framing(&"close", -0.5, "linear"),
		"direct actor calls only reserve -1 for preset-default duration",
	)
	_expect(
		not actor.apply_actor_framing(&"close", 0.2, "elastic"),
		"direct actor calls reject unknown transitions",
	)
	_expect_equal(
		actor.get_actor_framing(),
		committed_framing,
		"rejected direct calls preserve the committed framing",
	)

	var invalid_profile := KonadoActorFramingProfile.new()
	var duplicate_a := KonadoActorFramingPreset.new()
	var duplicate_b := KonadoActorFramingPreset.new()
	duplicate_a.preset_id = &"duplicate"
	duplicate_b.preset_id = &"duplicate"
	invalid_profile.presets = [duplicate_a, duplicate_b]
	_expect(
		not actor.set_framing_profile(invalid_profile),
		"invalid framing profiles are rejected transactionally",
	)
	_expect(
		actor.has_actor_framing(&"full"),
		"rejecting a framing profile preserves the previous working profile",
	)
	var missing_default_profile := KonadoActorFramingProfile.new()
	var only_custom := KonadoActorFramingPreset.new()
	only_custom.preset_id = &"custom"
	missing_default_profile.presets = [only_custom]
	_expect(
		not actor.set_framing_profile(missing_default_profile),
		"a profile must explicitly contain its configured default preset",
	)
	var mutable_profile := KonadoActorFramingProfile.create_builtin()
	var profile_changes := [0]
	mutable_profile.changed.connect(func(): profile_changes[0] += 1)
	mutable_profile.get_preset(&"medium").scale = 1.31
	_expect_equal(
		profile_changes[0],
		1,
		"editing a preset relays a profile change for Inspector persistence and tool observers",
	)
	var appended_preset := KonadoActorFramingPreset.new()
	appended_preset.preset_id = &"insert"
	mutable_profile.presets.append(appended_preset)
	_expect(
		mutable_profile.has_preset(&"insert"),
		"in-place resource array edits are immediately visible to framing lookups",
	)
	var non_finite_profile := KonadoActorFramingProfile.create_builtin()
	non_finite_profile.get_preset(&"medium").offset = Vector2(NAN, 0.0)
	_expect(
		not actor.set_framing_profile(non_finite_profile),
		"non-finite framing transforms are rejected before reaching Tween",
	)

	var stage := KonadoStageController.new()
	get_root().add_child(stage)
	await process_frame
	var actor_a := ACTOR_SCENE.instantiate() as KonadoActor
	var actor_b := ACTOR_SCENE.instantiate() as KonadoActor
	actor_a.name = "A"
	actor_b.name = "B"
	stage._actor_layer.add_child(actor_a)
	stage._actor_layer.add_child(actor_b)
	await process_frame
	stage.actor_instances["A"] = actor_a
	stage.actor_instances["B"] = actor_b
	stage.actor_states["A"] = {"framing": "default"}
	stage.actor_states["B"] = {"framing": "default"}
	var actor_without_state := ACTOR_SCENE.instantiate() as KonadoActor
	actor_without_state.name = "WithoutState"
	stage._actor_layer.add_child(actor_without_state)
	await process_frame
	_expect(
		not stage.set_actor_framing("WithoutState", &"close", 0.0, "linear", false),
		"a discovered actor without logical stage state is rejected safely",
	)
	_expect_equal(
		stage.get_last_failure().get("code"),
		"stage.actor_state_missing",
		"missing logical actor state exposes a stable failure code",
	)
	var background_camera := Camera2D.new()
	stage._background.add_child(background_camera)
	background_camera.position = Vector2(320.0, 180.0)
	background_camera.zoom = Vector2(1.5, 1.5)
	var actor_layer_transform: Transform2D = stage._actor_layer.get_global_transform()
	var background_position: Vector2 = stage._background.position
	var background_scale: Vector2 = stage._background.scale
	_expect(
		stage.set_actor_framing("A", &"close", 0.0, "linear", false),
		"one actor accepts an independent framing",
	)
	_expect_equal(actor_b.get_actor_framing(), &"default", "one actor does not frame another")
	_expect_equal(
		stage._background.position,
		background_position,
		"actor framing does not move the fixed background",
	)
	_expect_equal(
		stage._background.scale,
		background_scale,
		"actor framing does not scale the fixed background",
	)
	_expect(
		stage._background.is_ancestor_of(background_camera),
		"the default global camera remains owned by the background hierarchy",
	)
	_expect(
		not stage._background.is_ancestor_of(stage._actor_layer),
		"the actor layer remains a stable stage sibling of the background layer",
	)
	_expect_equal(
		stage._actor_layer.get_global_transform(),
		actor_layer_transform,
		"actor-local framing does not mutate the shared actor layer transform",
	)
	actor_a.restore_actor_framing(&"default")
	stage.actor_states["A"]["framing"] = "default"
	_expect(
		not stage.set_actor_framings({"A": "close", "B": "missing"}, 0.0, "linear", false),
		"batch framing rejects an invalid member",
	)
	_expect_equal(actor_a.get_actor_framing(), &"default", "failed batch does not partially apply")
	_expect(
		not stage.set_actor_framings({"A": 42}, 0.0, "linear", false),
		"batch framing rejects non-string preset values at its public boundary",
	)
	_expect_equal(
		stage.get_last_failure().get("code"),
		"stage.actor_framing_batch_invalid",
		"invalid batch types expose a stable failure code",
	)
	_expect(
		stage.set_actor_framings({"A": "close", "B": "medium"}, 0.0, "linear", false),
		"valid multi-actor framing batch is accepted",
	)
	_expect_equal(actor_a.get_actor_framing(), &"close", "batch updates the first actor")
	_expect_equal(actor_b.get_actor_framing(), &"medium", "batch updates the second actor")
	var stage_events: Array[Dictionary] = []
	stage.actor_framing_changed.connect(
		func(actor_id: String, preset_id: String, succeeded: bool, reason: String) -> void:
			(
				stage_events
				. append(
					{
						"actor_id": actor_id,
						"preset_id": preset_id,
						"succeeded": succeeded,
						"reason": reason,
					}
				)
			)
	)
	var first_request := stage._operation_tracker().begin_request()
	var second_request := stage._operation_tracker().begin_request()
	stage.set_actor_framing("A", &"medium", 1.0, "linear", false, first_request)
	stage.set_actor_framing("A", &"full", 0.0, "linear", false, second_request)
	_expect(
		(
			stage_events.size() == 2
			and not bool(stage_events[0].succeeded)
			and stage_events[0].reason == "superseded"
			and bool(stage_events[1].succeeded)
		),
		"stage observers receive one terminal event for superseded and replacement requests",
	)
	var captured_actors: Array = stage.capture_state().get("actors", [])
	var captured_actor_a := false
	for item: Dictionary in captured_actors:
		if item.id == "A" and item.framing == "full":
			captured_actor_a = true
			break
	_expect(captured_actor_a, "stage snapshots persist the accepted actor framing")
	stage_events.clear()
	var cancelled_request := stage._operation_tracker().begin_request()
	_expect(
		stage.set_actor_framing("A", &"close", 1.0, "linear", false, cancelled_request),
		"a non-blocking framing transition starts before a runtime boundary",
	)
	stage.cancel_pending_operations()
	_expect_equal(
		actor_a.motion_layer.get_current_framing_id(),
		&"close",
		"runtime cancellation settles rendering to the accepted logical framing",
	)
	_expect(
		actor_a.motion_layer.framing_layer.scale.is_equal_approx(Vector2(1.65, 1.65)),
		"runtime cancellation cannot leave a framing transition on an intermediate frame",
	)
	_expect_equal(
		stage.actor_states["A"].framing,
		"close",
		"runtime cancellation preserves the accepted framing in stage state",
	)
	_expect(
		(
			stage_events.size() == 1
			and not bool(stage_events[0].succeeded)
			and stage_events[0].reason == "runtime_cancelled"
		),
		"runtime cancellation emits one stable terminal event without resuming the instruction",
	)

	var hierarchy_host := Control.new()
	var misplaced_parent := Control.new()
	hierarchy_host.add_child(misplaced_parent)
	get_root().add_child(hierarchy_host)
	var misplaced_background := ColorRect.new()
	var misplaced_effect := ColorRect.new()
	misplaced_parent.add_child(misplaced_background)
	misplaced_parent.add_child(misplaced_effect)
	var repaired_nodes := (
		STAGE_TREE_BUILDER
		. ensure(
			hierarchy_host,
			{"background": misplaced_background, "effect_layer": misplaced_effect},
			BACKGROUND_TRANSITION_LAYER_SCRIPT,
		)
	)
	_expect(
		(
			repaired_nodes.background.get_parent() == hierarchy_host
			and repaired_nodes.effect_layer.get_parent() == hierarchy_host
		),
		"stage hierarchy repair reparents every top-level visual layer",
	)
	_expect(
		(
			(
				repaired_nodes.background.get_index()
				< repaired_nodes.background_transition_layer.get_index()
			)
			and (
				repaired_nodes.background_transition_layer.get_index()
				< repaired_nodes.actor_layer.get_index()
			)
			and repaired_nodes.actor_layer.get_index() < repaired_nodes.effect_layer.get_index()
		),
		"stage hierarchy repair restores the stable visual layer order",
	)

	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	var program := (
		compiler
		. compile_string(
			(
				"actor show Kona normal at 3 [framing=medium]\n"
				+ "actor framing Kona close [duration=0.4] [transition=ease_in_out] [wait=false]\n"
				+ "end"
			),
			"res://actor-framing-test.ks",
		)
	)
	if program == null:
		push_error("actor framing compiler diagnostics: %s" % [compiler.get_diagnostics()])
	_expect(program != null, "actor framing syntax compiles with typed parameters")
	if program != null:
		_expect_equal(
			program.instruction_at(1).opcode(),
			KonadoOpcode.Type.ACTOR_FRAMING,
			"actor framing emits its dedicated opcode",
		)
		_expect(
			not bool(program.instruction_at(1).value(&"wait")),
			"non-blocking framing intent survives compilation",
		)

	actor.queue_free()
	stage.queue_free()
	hierarchy_host.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: actor framing tests")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (actual=%s expected=%s)" % [message, actual, expected])
