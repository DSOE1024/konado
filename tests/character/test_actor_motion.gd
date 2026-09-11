extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"

## actor motion 必须真的播放动作层动画，而不是瞬间“播完”。

const MOTION_SCRIPT := (
	"actor show Kona 正常 at 3\n"
	+ '"Kona" "before" [id=before]\n'
	+ "actor motion Kona shake\n"
	+ '"Kona" "after" [id=after]\n'
	+ "end"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_actor_motion_plays_the_authored_animation()
	await _test_motion_layer_duration_conventions()
	if _failures == 0:
		print("PASS: actor motion tests")
	quit(_failures)


## 未指定 duration 时编译器会填 -1 哨兵：必须按动画自身时长播放，并在播完前保持等待。
func _test_actor_motion_plays_the_authored_animation() -> void:
	var manager := await _create_manager()
	_setup_characters(manager)
	manager.set_shot(_compile_shot(MOTION_SCRIPT))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:before", KonadoDialogueManager.DialogState.WAITING
	)
	await _finish_current_dialogue(manager)
	var player := _motion_player(manager)
	_expect(player != null, "the actor exposes a motion AnimationPlayer")
	await _wait_for_condition(
		func() -> bool: return player.is_playing(), "the motion animation starts playing"
	)
	_expect_equal(
		String(player.current_animation), "shake", "the requested motion is the playing animation"
	)
	_expect(
		manager.dialogue_state == KonadoDialogueManager.DialogState.WAITING,
		"the dialogue waits while the motion plays"
	)
	await _wait_for_condition(
		func() -> bool: return not player.is_playing(), "the motion animation finishes"
	)
	await _wait_for_instruction_and_state(
		manager, "ks:id:after", KonadoDialogueManager.DialogState.WAITING
	)
	await _free_node(manager)


## 动作层的 duration 约定：负数/未指定 = 使用动画自身时长；0 = 禁用动画。
func _test_motion_layer_duration_conventions() -> void:
	var layer := (
		(
			load("res://addons/konado/templates/default/character/konado_actor_motion_layer.tscn")
			. instantiate()
		)
		as KonadoActorMotionLayer
	)
	root.add_child(layer)
	await process_frame
	layer.play_motion("shake", {"duration": -1.0})
	_expect(layer.animation_player.is_playing(), "a negative duration plays the authored animation")
	layer.stop_motion()
	layer.play_motion("shake", {"duration": 0.0})
	_expect(not layer.animation_player.is_playing(), "a zero duration still skips the animation")
	layer.queue_free()
	await process_frame


func _setup_characters(manager: KonadoDialogueManager) -> void:
	manager.character_list = load("res://sample/demo/character_list.tres")
	manager.stage_controller.character_list = manager.character_list


func _motion_player(manager: KonadoDialogueManager) -> AnimationPlayer:
	var actor = manager.stage_controller.get_actor("Kona")
	if actor == null or actor.motion_layer == null:
		return null
	return actor.motion_layer.animation_player
