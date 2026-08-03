extends RefCounted

## Owns the transient lifetime of one dialogue playback generation.
##
## Signals, timers and UI state must never outlive the shot that created them.
## Keeping that policy here prevents the dialogue graph executor from growing
## another independent cleanup path for every asynchronous command.

var _host_ref: WeakRef
var _pending_advance_connections: Array[Dictionary] = []


func _init(host: Variant) -> void:
	assert(host != null, "KND_DialoguePlaybackSession requires a dialogue manager host.")
	_host_ref = weakref(host)


func _get_host() -> Variant:
	return _host_ref.get_ref() if _host_ref != null else null


func invalidate() -> int:
	var host := _get_host()
	if host == null:
		_disconnect_pending_advance_connections()
		return -1
	host._playback_generation += 1
	disconnect_typing_completed()
	_disconnect_pending_advance_connections()
	return host._playback_generation


func is_current(generation: int) -> bool:
	var host := _get_host()
	return (
		host != null
		and is_instance_valid(host)
		and generation == host._playback_generation
		and host._shot_active
	)


func initialize(callback: Callable = Callable()) -> void:
	var host := _get_host()
	if host == null:
		return
	if host.start_dialogue_shot == null:
		push_error("未设置对话镜头")
		return
	var initialization_generation := invalidate()
	host._shot_active = false
	host.dialogue_state = host.DialogState.OFF
	host.justenter = true
	var localized_shot: KND_Shot = host._load_localized_shot(host.start_dialogue_shot)
	if localized_shot != null:
		host.start_dialogue_shot = localized_shot
	# Do not expose a startable half-initialized graph to cleanup callbacks.
	host.cur_dialogue_shot = null
	host.cur_node_id = ""
	host._acting_interface.chara_list = host.chara_list
	host._acting_interface.delete_all_actor(true)
	if not _generation_matches(host, initialization_generation):
		return
	reset_transient_interfaces()
	if not _generation_matches(host, initialization_generation):
		return
	if not host._services()._set_current_shot(host.start_dialogue_shot):
		return
	print_rich(
		(
			"[color=yellow]初始化对话 [/color]"
			+ "justenter: "
			+ str(host.justenter)
			+ " 当前节点ID: "
			+ str(host.cur_node_id)
			+ " 当前状态: "
			+ str(host.dialogue_state)
		)
	)
	print("---------------------------------------------")
	if callback.is_valid():
		callback.call()


func set_shot(new_shot: KND_Shot) -> void:
	var host := _get_host()
	if host == null:
		return
	if new_shot == null:
		push_error("无法设置空的对话镜头")
		return
	invalidate()
	host._shot_active = false
	host.dialogue_state = host.DialogState.OFF
	var localized_shot: KND_Shot = host._load_localized_shot(new_shot)
	if localized_shot != null:
		new_shot = localized_shot
	host.start_dialogue_shot = new_shot
	host._services()._set_current_shot(host.start_dialogue_shot)


func start() -> void:
	var host := _get_host()
	if host == null:
		return
	if host.cur_dialogue_shot == null or host.cur_node_id.is_empty():
		push_error("对话尚未初始化，请先调用 init_dialogue")
		return
	if host._shot_active:
		return
	# Every accepted start owns a new generation. This also lets an in-progress
	# stop detect a direct restart made from one of its cleanup callbacks.
	invalidate()
	if host._konado_choice_interface:
		host._konado_choice_interface.show()
	if host._acting_interface:
		host._acting_interface.show()
	host._shot_active = true
	host._dialogue_goto_state(host.DialogState.PLAYING)
	print_rich("[color=yellow]开始对话 [/color]")
	host.shot_start.emit()


func connect_auto_advance(s: Signal, playback_generation: int, from_motion: bool = false) -> void:
	var host := _get_host()
	if host == null or s.is_null() or not is_current(playback_generation):
		return
	var node_generation: int = host._node_generation
	var node_id: String = host.cur_node_id
	var callback: Callable
	if from_motion:
		callback = _on_motion_finished.bind(s, playback_generation, node_generation, node_id)
	else:
		callback = _on_action_finished.bind(s, playback_generation, node_generation, node_id)
	if s.is_connected(callback):
		return
	s.connect(callback, CONNECT_ONE_SHOT)
	_pending_advance_connections.append({"signal": s, "callback": callback})


func on_typing_finished(
	wait_voice: bool,
	wait_voice_time: float,
	playback_generation: int,
	node_generation: int,
	node_id: String
) -> void:
	var host := _get_host()
	if host == null:
		return
	if not host._is_node_current(playback_generation, node_generation, node_id):
		return
	# A stale callback may still be completing the signal emission that started
	# before a replacement shot installed its own callback. It must never clear
	# the replacement callback's bookkeeping.
	host._typing_completed_callback = Callable()
	host._dialogue_goto_state(host.DialogState.PAUSED)
	if host.autoplay:
		if wait_voice:
			print("等待音频播放完成")
			var timer = host.get_tree().create_timer(wait_voice_time)
			timer.timeout.connect(
				func():
					var current_host := _get_host()
					if (
						current_host != null
						and current_host._is_node_current(
							playback_generation, node_generation, node_id
						)
						and current_host.dialogue_state == current_host.DialogState.PAUSED
					):
						if current_host.autoplay:
							current_host._process_next()
			)
		else:
			await host.get_tree().create_timer(host.autoplayspeed).timeout
			var current_host := _get_host()
			if (
				current_host != null
				and current_host.autoplay
				and current_host.dialogue_state == current_host.DialogState.PAUSED
				and current_host._is_node_current(playback_generation, node_generation, node_id)
			):
				current_host._process_next()
				print("触发打字完成信号")
		return

	var current: KND_Dialogue = host._current_dialogue()
	if current == null:
		print("当前对话为空，无法获取下一句")
		return
	var next_dialogue: KND_Dialogue = host.cur_dialogue_shot.find_node(current.next_id)
	if next_dialogue != null and next_dialogue.dialog_type == KND_Dialogue.Type.SHOW_CHOICE:
		print("选项自动下一个")
		await host.get_tree().create_timer(0.05).timeout
		var current_host := _get_host()
		if (
			current_host != null
			and current_host.dialogue_state == current_host.DialogState.PAUSED
			and current_host._is_node_current(playback_generation, node_generation, node_id)
		):
			current_host._process_next()
	print("触发打字完成信号")


func process_next() -> void:
	var host := _get_host()
	if host == null or not host._shot_active or host._is_emitting_line_end:
		return
	print_rich("[color=yellow]判断状态[/color]")
	match host.dialogue_state:
		host.DialogState.OFF:
			print("对话关闭状态，无需做任何操作")
		host.DialogState.PLAYING:
			if host.cur_dialogue_type == KND_Dialogue.Type.ORDINARY_DIALOG:
				host._konado_dialogue_box.skip_typing_anim()
			else:
				print("对话播放状态，等待播放完成")
		host.DialogState.PAUSED:
			_advance_paused_node(host)


func continue_after_command(
	playback_generation: int, node_generation: int, node_id: String, defer_one_frame: bool = false
) -> void:
	var host := _get_host()
	if host == null or not host._is_node_current(playback_generation, node_generation, node_id):
		return
	host._dialogue_goto_state(host.DialogState.PAUSED)
	if defer_one_frame:
		await host.get_tree().process_frame
		host = _get_host()
	if (
		host != null
		and host.dialogue_state == host.DialogState.PAUSED
		and host._is_node_current(playback_generation, node_generation, node_id)
	):
		host._process_next()


func _advance_paused_node(host: Variant) -> void:
	var playback_generation: int = host._playback_generation
	var node_generation: int = host._node_generation
	var completed_node_id: String = host.cur_node_id
	host._is_emitting_line_end = true
	host.dialogue_line_end.emit(completed_node_id)
	if not is_instance_valid(host):
		return
	host._is_emitting_line_end = false
	if not host._is_node_current(playback_generation, node_generation, completed_node_id):
		return
	host._audio_interface.stop_voice()
	if host._screen_text and host._screen_text.visible:
		host._screen_text.reset_screen_text()
	print("对话播放完成，开始播放下一个")
	var current: KND_Dialogue = host._current_dialogue()
	if (
		current == null
		or current.next_id.is_empty()
		or host.cur_dialogue_shot.find_node(current.next_id) == null
	):
		# 未显式写 end 的自然结尾也必须执行完整镜头清理并发出 shot_end。
		stop()
		return
	host._goto_next_node()
	host._dialogue_goto_state(host.DialogState.PLAYING)


func on_option_triggered(choice: KND_DialogueChoice, playback_generation: int) -> void:
	var host := _get_host()
	if host == null:
		return
	if playback_generation < 0:
		playback_generation = host._playback_generation
	if not is_current(playback_generation):
		return
	host._konado_choice_interface._choice_container.hide()
	var node_generation: int = host._node_generation
	var completed_node_id: String = host.cur_node_id
	host._is_emitting_line_end = true
	host.dialogue_line_end.emit(completed_node_id)
	if not is_instance_valid(host):
		return
	host._is_emitting_line_end = false
	if not host._is_node_current(playback_generation, node_generation, completed_node_id):
		return
	print_rich('[color=green]玩家选择: "%s" -> %s[/color]' % [choice.choice_text, choice.next_id])
	if choice.next_id.is_empty():
		print_rich("[color=yellow]选项没有跳转目标，停止对话[/color]")
		stop()
		return
	var target: KND_Dialogue = host.cur_dialogue_shot.find_node(choice.next_id)
	if target == null:
		printerr("选项目标节点不存在: %s，停止对话" % choice.next_id)
		stop()
		return
	host.cur_node_id = choice.next_id
	host._dialogue_goto_state(host.DialogState.PLAYING)


func stop() -> void:
	var host := _get_host()
	if host == null:
		return
	if not host._shot_active and host.dialogue_state == host.DialogState.OFF:
		return
	var should_emit_shot_end: bool = host._shot_active
	host._shot_active = false
	var stop_generation := invalidate()
	host._dialogue_goto_state(host.DialogState.OFF)
	if host._acting_interface:
		host._acting_interface.delete_all_actor()
		if not _generation_matches(host, stop_generation):
			_finish_stop(host, should_emit_shot_end)
			return
		host._acting_interface.clean_background(
			KND_ActingInterface.BackgroundTransitionEffectsType.ALPHA_FADE_EFFECT
		)
		if not _generation_matches(host, stop_generation):
			_finish_stop(host, should_emit_shot_end)
			return
	reset_transient_interfaces(false)
	if not _generation_matches(host, stop_generation):
		_finish_stop(host, should_emit_shot_end)
		return
	print_rich("[color=yellow]关闭对话[/color]")
	if host._konado_dialogue_box:
		host._konado_dialogue_box.hide_dialogue_box(true)
	_finish_stop(host, should_emit_shot_end)


func _finish_stop(host: Variant, should_emit_shot_end: bool) -> void:
	if should_emit_shot_end and host != null and is_instance_valid(host):
		host.shot_end.emit()


func reset_transient_interfaces(reset_dialogue_box: bool = true) -> void:
	var host := _get_host()
	if host == null:
		return
	host.option_triggered = false
	host._waiting_signal_name = ""
	if host._konado_choice_interface:
		host._konado_choice_interface.init_dialog_box()
	if reset_dialogue_box and host._konado_dialogue_box:
		host._konado_dialogue_box.reset_dialogue_box()
	if host._screen_text:
		host._screen_text.reset_screen_text()
	if host._audio_interface:
		host._audio_interface.stop_voice()
	if host._konado_cam_manager:
		host._konado_cam_manager.cancel_pending_operations()


func disconnect_typing_completed() -> void:
	var host := _get_host()
	if host == null:
		return
	if (
		host._konado_dialogue_box != null
		and host._typing_completed_callback.is_valid()
		and host._konado_dialogue_box.typing_completed.is_connected(host._typing_completed_callback)
	):
		host._konado_dialogue_box.typing_completed.disconnect(host._typing_completed_callback)
	host._typing_completed_callback = Callable()


func _on_action_finished(
	s: Signal, playback_generation: int, node_generation: int, node_id: String
) -> void:
	_forget_advance_connection(
		s, _on_action_finished.bind(s, playback_generation, node_generation, node_id)
	)
	var host := _get_host()
	if host == null or not host._is_node_current(playback_generation, node_generation, node_id):
		return
	if host._konado_cam_manager:
		host._konado_cam_manager.get_all_konado_cameras()
	else:
		printerr("刷新镜头群失败")
	host._dialogue_goto_state(host.DialogState.PAUSED)
	print("触发自动下一个信号")
	host._process_next()


func _on_motion_finished(
	_actor_id: String,
	_motion_name: String,
	s: Signal,
	playback_generation: int,
	node_generation: int,
	node_id: String
) -> void:
	_forget_advance_connection(
		s,
		_on_motion_finished.bind(s, playback_generation, node_generation, node_id),
	)
	var host := _get_host()
	if host == null or not host._is_node_current(playback_generation, node_generation, node_id):
		return
	host._dialogue_goto_state(host.DialogState.PAUSED)
	print("触发演员动作自动下一个信号")
	host._process_next()


func _forget_advance_connection(s: Signal, callback: Callable) -> void:
	for index in range(_pending_advance_connections.size() - 1, -1, -1):
		var connection := _pending_advance_connections[index]
		if connection["signal"] == s and connection["callback"] == callback:
			_pending_advance_connections.remove_at(index)
			return


func _disconnect_pending_advance_connections() -> void:
	for connection in _pending_advance_connections:
		var s: Signal = connection["signal"]
		var callback: Callable = connection["callback"]
		if not s.is_null() and s.is_connected(callback):
			s.disconnect(callback)
	_pending_advance_connections.clear()


func _generation_matches(host: Variant, generation: int) -> bool:
	return host != null and is_instance_valid(host) and host._playback_generation == generation
