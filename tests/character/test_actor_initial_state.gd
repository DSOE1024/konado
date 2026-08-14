extends SceneTree

const VALID_CHARACTER_SCENE := preload("res://sample/demo/sample_character.tscn")
const READY_DEPENDENT_CHARACTER_SCENE := preload(
	"res://tests/character/fixtures/ready_dependent_character.tscn"
)
const LAYOUT_DEPENDENT_CHARACTER_SCENE := preload(
	"res://tests/character/fixtures/layout_dependent_character.tscn"
)

var _failures := 0


class LegacyActorOverride:
	extends KND_Actor

	var legacy_override_called := false

	func set_character_scene(_scene: PackedScene, _initial_status: String = "") -> void:
		legacy_override_called = true


class LegacyMotionLayerOverride:
	extends KND_Actor

	var legacy_override_called := false

	func set_motion_layer_scene(_scene: PackedScene) -> void:
		legacy_override_called = true


class LegacyStatusOverride:
	extends KND_Actor

	var legacy_override_called := false

	func apply_character_status(
		_status_name: String, _transition_duration: float = 0.0, completion: Callable = Callable()
	) -> void:
		legacy_override_called = true
		if completion.is_valid():
			completion.call(true)


class LegacyCharacterStatusOverride:
	extends KND_CharacterSceneBase

	var legacy_override_called := false

	func apply_status(status_name: String) -> void:
		legacy_override_called = true
		current_status_name = status_name


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor_scene := (
		load("res://addons/konado/template/default/character/character_template.tscn")
		as PackedScene
	)
	var legacy_actor := LegacyActorOverride.new()
	_expect(
		legacy_actor._try_set_character_scene(VALID_CHARACTER_SCENE, "legacy"),
		"legacy void overrides remain source compatible"
	)
	_expect(legacy_actor.legacy_override_called, "the transactional entry keeps dynamic dispatch")
	legacy_actor.free()
	var legacy_motion_actor := LegacyMotionLayerOverride.new()
	_expect(
		legacy_motion_actor._try_set_motion_layer_scene(VALID_CHARACTER_SCENE),
		"legacy motion-layer void overrides remain source compatible"
	)
	_expect(
		legacy_motion_actor.legacy_override_called,
		"the motion-layer transactional entry keeps dynamic dispatch"
	)
	legacy_motion_actor.free()
	var legacy_status_actor := LegacyStatusOverride.new()
	_expect(
		legacy_status_actor._try_apply_character_status("legacy"),
		"legacy status overrides without an internal status node remain source compatible"
	)
	_expect(
		legacy_status_actor.legacy_override_called,
		"the status transactional entry keeps dynamic dispatch"
	)
	legacy_status_actor.free()
	var legacy_character_actor := KND_Actor.new()
	var legacy_character_scene := LegacyCharacterStatusOverride.new()
	_expect(
		legacy_character_actor._apply_character_status_to_node(legacy_character_scene, "legacy"),
		"legacy character-scene status overrides retain their historical acceptance semantics"
	)
	_expect(
		legacy_character_scene.legacy_override_called,
		"the character-scene compatibility path keeps public apply_status dispatch"
	)
	_expect_equal(
		legacy_character_scene.current_status_name,
		"legacy",
		"legacy character-scene overrides still receive the requested state"
	)
	legacy_character_scene.free()
	legacy_character_actor.free()
	var valid_actor := actor_scene.instantiate() as KND_Actor
	get_root().add_child(valid_actor)
	await process_frame
	var original_motion_layer := valid_actor.motion_layer
	_expect(
		not valid_actor._try_set_motion_layer_scene(VALID_CHARACTER_SCENE),
		"invalid custom motion layers report failure"
	)
	_expect_equal(
		valid_actor.motion_layer,
		original_motion_layer,
		"invalid custom motion layers preserve the working default layer"
	)
	_expect(
		original_motion_layer != null and original_motion_layer.get_parent() == valid_actor.slot,
		"the preserved default motion layer remains mounted"
	)
	_expect(
		valid_actor._try_set_character_scene(VALID_CHARACTER_SCENE, "介绍正常"),
		"valid initial states report success after entering the scene tree"
	)
	var character_scene := valid_actor._status_node as KND_CharacterSceneBase
	_expect(character_scene != null, "valid character scenes are instantiated")
	if character_scene:
		_expect_equal(
			character_scene.current_status_name,
			"介绍正常",
			"successful initial states become the committed scene status"
		)

	var invalid_actor := actor_scene.instantiate() as KND_Actor
	get_root().add_child(invalid_actor)
	await process_frame
	_expect(
		not invalid_actor._try_set_character_scene(VALID_CHARACTER_SCENE, "missing"),
		"missing initial states report failure after entering the scene tree"
	)
	_expect_equal(
		invalid_actor._status_node,
		null,
		"failed initial states discard the uncommitted candidate scene"
	)

	var committed_scene := valid_actor._status_node
	_expect(
		not valid_actor._try_set_character_scene(VALID_CHARACTER_SCENE, "missing"),
		"invalid replacement states report failure"
	)
	_expect_equal(
		valid_actor._status_node,
		committed_scene,
		"invalid replacement states preserve the committed character scene"
	)
	_expect(
		committed_scene != null and committed_scene.get_parent() != null,
		"the preserved character scene remains mounted"
	)

	var ready_actor := actor_scene.instantiate() as KND_Actor
	get_root().add_child(ready_actor)
	await process_frame
	_expect(
		ready_actor._try_set_character_scene(READY_DEPENDENT_CHARACTER_SCENE, "ready"),
		"initial state validation runs after the character scene is ready"
	)

	var layout_actor := actor_scene.instantiate() as KND_Actor
	layout_actor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	layout_actor.size = Vector2(640.0, 360.0)
	get_root().add_child(layout_actor)
	await process_frame
	_expect(
		layout_actor._try_set_character_scene(LAYOUT_DEPENDENT_CHARACTER_SCENE, "layout_ready"),
		"layout-dependent initial states are accepted"
	)
	var layout_character := layout_actor._status_node
	var initial_layout_size: Vector2 = layout_character.get("size_during_initial_status")
	_expect(
		initial_layout_size.is_equal_approx(layout_actor.slot.size),
		"candidate controls are laid out before their initial status hook runs"
	)

	valid_actor.queue_free()
	invalid_actor.queue_free()
	ready_actor.queue_free()
	layout_actor.queue_free()
	await process_frame
	character_scene = null
	valid_actor = null
	invalid_actor = null
	ready_actor = null
	layout_actor = null
	actor_scene = null
	if _failures == 0:
		print("PASS: actor initial state tests")
	quit(_failures)


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
