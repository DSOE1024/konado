extends RefCounted

## Resource, variable and persistence services used by KND_DialogueManager.
##
## The host remains responsible for playback state. This service owns operations
## that do not advance the dialogue graph, keeping the manager focused on flow.

var _host: Variant
var _variable_pattern := RegEx.create_from_string("([%$])([\\p{L}_][\\p{L}\\p{N}_-]*)")


func _init(host: Variant) -> void:
	assert(host != null, "KND_DialogueServices requires a dialogue manager host.")
	_host = host


func _display_background(
	bg_name: String, effect: KND_ActingInterface.BackgroundTransitionEffectsType
) -> void:
	if bg_name == null or bg_name.is_empty():
		_fail_background_change("背景名称为空，请检查 KS/Shot 是否已经重新导入")
		return
	if _host.background_list == null:
		_fail_background_change("背景列表未配置")
		return

	var target_background: KND_Background
	for background in _host.background_list.background_list:
		if background.background_name == bg_name:
			target_background = background
			break
	if target_background == null:
		_fail_background_change("背景没有找到：" + bg_name)
		return
	if target_background.background_scene == null:
		_fail_background_change("背景[%s]没有配置背景场景" % bg_name)
		return

	_host._acting_interface.change_background_scene(
		target_background.background_scene, bg_name, effect
	)


func _fail_background_change(message: String) -> void:
	push_error(message)
	_host._acting_interface.background_change_finished.emit()


func _actor_change_state(character_id: String, state_id: String) -> void:
	var target_character: KND_Character
	for character in _host.chara_list.characters:
		if character.chara_name == character_id:
			target_character = character
			break
	if target_character == null:
		push_error("切换角色状态失败：未找到角色[%s]" % character_id)
		_host._acting_interface.character_state_changed.emit()
		return
	_host._acting_interface.change_actor_state(target_character.chara_name, state_id)


func _display_character(dialogue: KND_Dialogue) -> void:
	var target_character: KND_Character
	for character in _host.chara_list.characters:
		if character.chara_name == dialogue.character_name:
			target_character = character
			break

	if target_character == null:
		_fail_character_display("显示角色失败：未找到角色[%s]" % dialogue.character_name)
		return
	if target_character.character_scene == null:
		_fail_character_display("显示角色失败：角色[%s]没有配置角色场景" % dialogue.character_name)
		return

	_host._acting_interface.show_character(
		dialogue.character_name,
		_host.horizontal_division,
		dialogue.actor_position.x,
		dialogue.character_state,
		target_character.character_scene,
		target_character.actor_motion_layer
	)


func _fail_character_display(message: String) -> void:
	push_error(message)
	_host._acting_interface.character_shown.emit()
	_host._acting_interface.character_created.emit()


func _exit_actor(actor_name: String) -> void:
	_host._acting_interface.delete_character(actor_name)


func _play_bgm(bgm_name: String) -> void:
	if bgm_name == null or bgm_name.is_empty():
		push_error("播放BGM失败：传入的bgm_name为空字符串或null，请检查调用参数")
		return
	if _host.bgm_list == null or _host.bgm_list.bgms == null:
		push_error("播放BGM失败：BGM列表未初始化，无法查找BGM[%s]" % bgm_name)
		return

	var target_bgm: AudioStream
	var available_names: Array[String] = []
	for index in _host.bgm_list.bgms.size():
		var bgm_data = _host.bgm_list.bgms[index]
		if bgm_data == null:
			push_error("BGM列表索引[%d]的数据为空" % index)
			continue
		available_names.append(bgm_data.bgm_name)
		if bgm_data.bgm_name == bgm_name:
			target_bgm = bgm_data.bgm

	if target_bgm:
		_host._audio_interface.play_bgm(target_bgm, bgm_name)
	else:
		push_error("播放BGM失败：未找到名称为[%s]的BGM。可用列表：%s" % [bgm_name, str(available_names)])


func _play_voice(voice_name: String) -> float:
	if voice_name == null or _host.voice_list == null or _host.voice_list.voices == null:
		_clear_voice_progress()
		return 0.0

	var target_voice: AudioStream
	for voice in _host.voice_list.voices:
		if voice.voice_name == voice_name:
			target_voice = voice.voice
			break
	if target_voice == null:
		push_error("播放配音失败：未找到名称为[%s]的语音" % voice_name)
		_clear_voice_progress()
		return 0.0

	_host._audio_interface.play_voice(target_voice)
	return target_voice.get_length()


func _clear_voice_progress() -> void:
	if _host._konado_dialogue_box:
		_host._konado_dialogue_box.clear_voice_progress()


func _play_sound_effect(effect_name: String) -> void:
	if effect_name == null:
		return
	if _host.soundeffect_list == null or _host.soundeffect_list.soundeffects == null:
		return

	for sound_effect in _host.soundeffect_list.soundeffects:
		if sound_effect.se_name == effect_name:
			_host._audio_interface.play_sound_effect(sound_effect.se)
			return
	push_error("播放音效失败：未找到名称为[%s]的音效" % effect_name)


func _handle_variable_operation(dialogue: KND_Dialogue) -> void:
	var operand := _normalize_operand(dialogue.variable_operand)
	if dialogue.is_persistent:
		if not _host.variable_store:
			printerr("持久变量存储未初始化")
			return
		_host.variable_store.apply_operation(
			dialogue.variable_name, dialogue.variable_operation, operand
		)
		print_rich(
			(
				"[color=cyan]持久变量操作: %%%s = %s[/color]"
				% [
					dialogue.variable_name,
					str(_host.variable_store.get_value(dialogue.variable_name)),
				]
			)
		)
		return

	_apply_temp_operation(dialogue.variable_name, dialogue.variable_operation, operand)
	print_rich(
		(
			"[color=magenta]临时变量操作: $%s = %s[/color]"
			% [
				dialogue.variable_name,
				str(_host._temp_variables.get(dialogue.variable_name)),
			]
		)
	)


func _normalize_operand(operand: Variant) -> Variant:
	if not operand is String:
		return operand
	var text := operand as String
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	if text.to_lower() == "true":
		return true
	if text.to_lower() == "false":
		return false
	return operand


func _apply_temp_operation(name: String, operation: int, operand: Variant) -> void:
	match operation:
		KND_VariableStore.Operation.SET:
			_host._temp_variables[name] = operand
		KND_VariableStore.Operation.ADD:
			var current = _host._temp_variables.get(name, 0)
			if typeof(current) == TYPE_STRING:
				_host._temp_variables[name] = str(current) + str(operand)
			else:
				_host._temp_variables[name] = float(current) + float(operand)
		KND_VariableStore.Operation.SUB:
			_host._temp_variables[name] = (
				float(_host._temp_variables.get(name, 0)) - float(operand)
			)
		KND_VariableStore.Operation.MUL:
			_host._temp_variables[name] = (
				float(_host._temp_variables.get(name, 0)) * float(operand)
			)
		KND_VariableStore.Operation.DIV:
			var divisor := float(operand)
			if divisor == 0.0:
				push_error("临时变量 '$%s' 除法操作除数为零" % name)
				return
			_host._temp_variables[name] = (float(_host._temp_variables.get(name, 0)) / divisor)


func _interpolate_variables(text: String) -> String:
	if text.is_empty():
		return text

	var result := text
	var offset := 0
	for regex_match in _variable_pattern.search_all(text):
		var value := _resolve_variable(regex_match.get_string(1), regex_match.get_string(2))
		if value == null:
			continue
		var start := regex_match.get_start() + offset
		var end := regex_match.get_end() + offset
		var replacement := str(value)
		result = result.substr(0, start) + replacement + result.substr(end)
		offset += replacement.length() - regex_match.get_string().length()
	return result


func _resolve_variable(prefix: String, variable_name: String) -> Variant:
	if prefix == "%" and _host.variable_store and _host.variable_store.has(variable_name):
		return _host.variable_store.get_value(variable_name)
	if prefix == "$" and _host._temp_variables.has(variable_name):
		return _host._temp_variables[variable_name]
	return null


func _reload_localized_script(locale: String) -> bool:
	var service := _get_i18n_service()
	if service == null:
		return false
	var source_shot = (
		_host.cur_dialogue_shot if _host.cur_dialogue_shot != null else _host.start_dialogue_shot
	)
	if source_shot == null or source_shot.ks_path.is_empty() or source_shot.ks_path == "null":
		return false

	var localized_shot := (
		service.call("load_localized_script", source_shot.ks_path, locale) as KND_Shot
	)
	if localized_shot == null:
		return false

	var restore_node_id: String = service.call(
		"choose_restore_node_id", _host.cur_dialogue_shot, localized_shot, _host.cur_node_id
	)
	_host.start_dialogue_shot = localized_shot
	_host.cur_dialogue_shot = localized_shot.duplicate()
	_host.cur_node_id = restore_node_id
	_host.justenter = true
	_refresh_current_localized_dialogue()
	return true


func _get_i18n_service() -> Node:
	if _host._i18n_service == null and _host.is_inside_tree():
		_host._i18n_service = _host.get_tree().root.get_node_or_null("KND_I18n")
	return _host._i18n_service


func _load_localized_shot(shot: KND_Shot) -> KND_Shot:
	var service := _get_i18n_service()
	if service == null or shot == null or shot.ks_path.is_empty() or shot.ks_path == "null":
		return shot
	return service.call("load_localized_script", shot.ks_path) as KND_Shot


func _set_current_shot(shot: KND_Shot) -> bool:
	if shot == null:
		return false
	_host.cur_dialogue_shot = shot.duplicate()
	_host._temp_variables.clear()
	_host._waiting_signal_name = ""
	if (
		_host.cur_dialogue_shot.start_node_id
		and not _host.cur_dialogue_shot.start_node_id.is_empty()
	):
		_host.cur_node_id = _host.cur_dialogue_shot.start_node_id
	elif not _host.cur_dialogue_shot.dialogues.is_empty():
		_host.cur_node_id = _host.cur_dialogue_shot.dialogues[0].node_id
	else:
		_host.cur_node_id = ""
	return true


func _refresh_current_localized_dialogue() -> void:
	var dialogue: KND_Dialogue = _host._current_dialogue()
	if dialogue == null:
		return
	_host.cur_dialogue_type = dialogue.dialog_type
	if (
		dialogue.dialog_type != KND_Dialogue.Type.ORDINARY_DIALOG
		or _host._konado_dialogue_box == null
	):
		return
	_host._konado_dialogue_box.character_name = dialogue.character_id
	_host._konado_dialogue_box.dialogue_text = _interpolate_variables(dialogue.dialog_content)


func _set_character_list(character_list: KND_CharacterList) -> void:
	if character_list == null:
		printerr("角色列表为空")
		return
	print(character_list.to_string())
	_host.chara_list = character_list


func _set_background_list(background_resources: KND_BackgroundList) -> void:
	if background_resources == null:
		printerr("背景列表为空")
		return
	print(background_resources.to_string())
	_host.background_list = background_resources


func _set_bgm_list(bgm_resources: KND_BgmList) -> void:
	if bgm_resources == null:
		printerr("BGM列表为空")
		return
	print(bgm_resources.to_string())
	_host.bgm_list = bgm_resources


func _get_dialogue_variable(key: String) -> Dictionary:
	if _host.variable_store and _host.variable_store.has(key):
		return {"value": _host.variable_store.get_value(key)}
	return {}


func _apply_setting(category: String, key: String, value: Variant) -> void:
	match category:
		"text":
			match key:
				"text_speed":
					_host._typing_interval = value
				"auto_delay":
					_host.autoplayspeed = value
				"auto_mode":
					_host.start_autoplay(value)
		"audio":
			pass


func _show_error(message: String) -> void:
	if not _host.enable_overlay_log:
		return
	if _host.error_tooltip_label:
		_host.error_tooltip_label.text = message
	else:
		printerr(message)
	if _host.error_tooltip_panel:
		_host.error_tooltip_panel.show()


func _save_game(save_id: int) -> bool:
	if not _host.save_system:
		printerr("存档系统未设置")
		return false
	return _host.save_system.save_game(save_id)


func _load_game(save_id: int) -> bool:
	if not _host.save_system:
		printerr("存档系统未设置")
		return false
	return _host.save_system.load_game(save_id)


func _delete_save(save_id: int) -> bool:
	if not _host.save_system:
		printerr("存档系统未设置")
		return false
	return _host.save_system.delete_save(save_id)


func _get_save_info(save_id: int) -> Dictionary:
	if not _host.save_system:
		printerr("存档系统未设置")
		return {}
	return _host.save_system.get_save_info(save_id)


func _get_all_save_info() -> Array[Dictionary]:
	if not _host.save_system:
		printerr("存档系统未设置")
		return []
	return _host.save_system.get_all_save_info()


func _set_save_strategy(strategy: Dictionary) -> void:
	if _host.save_system:
		_host.save_system.save_strategy = strategy


func _get_save_strategy() -> Dictionary:
	if not _host.save_system:
		return {}
	return _host.save_system.save_strategy


func _show_achievement_panel() -> void:
	if _host.achievement_mgr:
		_host.achievement_mgr.show_panel()
	else:
		printerr("无KND_AchievementManager")


func _open_main_menu() -> void:
	_host.get_tree().change_scene_to_file("res://sample/demo/main.tscn")


func _quick_save() -> void:
	if not _host.save_system:
		printerr("存档系统未设置")
		return
	var success = _host.save_system.save_game(0)
	if success:
		print("快速保存完成")
		_show_toast("快速保存成功")
	else:
		printerr("快速保存失败")
		_show_toast("快速保存失败")


func _quick_load() -> void:
	if not _host.save_system:
		printerr("存档系统未设置")
		return
	var save_info = _host.save_system.get_save_info(0)
	if not save_info.get("exists", false):
		printerr("无快速存档可读取")
		_show_toast("无快速存档可读取")
		return
	_show_load_confirm_dialog()


func _show_load_confirm_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = ""
	dialog.dialog_text = _host.tr("读取会失去未保存的进度。\n\n你确定要这么做吗？")
	dialog.confirmed.connect(_on_load_confirmed.bind(dialog))
	dialog.canceled.connect(func(): dialog.queue_free())
	_host.add_child(dialog)
	dialog.popup_centered()


func _on_load_confirmed(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	if _host.save_system.load_game(0):
		print("快速读取完成")
	else:
		printerr("快速读取失败")
		_show_toast("快速读取失败")


func _show_toast(message: String, duration: float = 2.0) -> void:
	var toast := Label.new()
	toast.text = _host.tr(message)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 28)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	toast.add_theme_stylebox_override("normal", style)

	_host.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE)
	toast.position.y = 40

	var tween = _host.create_tween()
	tween.tween_interval(duration)
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast.queue_free)
