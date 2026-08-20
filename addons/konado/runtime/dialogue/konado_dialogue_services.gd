extends RefCounted

## Resource lookup, localization and persistence services for the atomic runtime.

var _host: KonadoDialogueManager
var _variable_pattern := RegEx.create_from_string("([%$])([\\p{L}_][\\p{L}\\p{N}_-]*)")
var _missing_variable_warnings: Dictionary = {}


func _init(host: KonadoDialogueManager) -> void:
	_host = host


func _display_background(name: String, effect: int, duration: float) -> bool:
	if _host.stage_controller == null:
		push_error("Konado: 未配置表演界面")
		return false
	var target: KonadoBackground
	if _host.background_list != null:
		for background in _host.background_list.background_list:
			if background.background_name == name:
				target = background
				break
	if target == null or target.background_scene == null:
		push_error("Konado: 未找到背景资源 '%s'" % name)
		return false
	_host.stage_controller.change_background_scene(target.background_scene, name, effect, duration)
	return true


func _play_bgm(name: String) -> bool:
	if _host.audio_controller == null or _host.background_music_list == null:
		return false
	for item in _host.background_music_list.background_music_tracks:
		if item != null and item.background_music_name == name:
			_host.audio_controller.play_background_music(item.stream, name)
			return true
	push_error("Konado: 未找到 BGM '%s'" % name)
	return false


func _play_voice(name: String) -> Dictionary:
	if _host.audio_controller == null or _host.voice_list == null:
		return {"ok": false, "duration": 0.0}
	for item in _host.voice_list.voices:
		if item != null and item.voice_name == name:
			if item.stream == null:
				push_error("Konado: 语音 '%s' 没有配置音频资源" % name)
				return {"ok": false, "duration": 0.0}
			_host.audio_controller.play_voice(item.stream)
			return {
				"ok": true,
				"duration": item.stream.get_length(),
			}
	push_error("Konado: 未找到语音 '%s'" % name)
	if _host.dialogue_box != null:
		_host.dialogue_box.clear_voice_progress()
	return {"ok": false, "duration": 0.0}


func _play_sound_effect(name: String) -> bool:
	if _host.audio_controller == null or _host.sound_effect_list == null:
		return false
	for item in _host.sound_effect_list.sound_effects:
		if item != null and item.sound_effect_name == name:
			_host.audio_controller.play_sound_effect(item.stream)
			return true
	push_error("Konado: 未找到音效 '%s'" % name)
	return false


func _apply_temp_operation(name: String, operation: int, operand: Variant) -> bool:
	var result := KonadoValueOperations.apply(
		_host._temp_variables.get(name), operation, operand, _host._temp_variables.has(name)
	)
	if not bool(result.get("ok", false)):
		return false
	_host._temp_variables[name] = result.get("value")
	return true


func _interpolate_variables(text: String) -> String:
	var result := text
	var offset := 0
	for regex_match in _variable_pattern.search_all(text):
		var prefix := regex_match.get_string(1)
		var variable_name := regex_match.get_string(2)
		var resolution := _resolve_variable_result(prefix, variable_name)
		if not bool(resolution.get("found", false)):
			_warn_missing_variable(prefix, variable_name)
			continue
		var value: Variant = resolution.get("value")
		var start := regex_match.get_start() + offset
		var finish := regex_match.get_end() + offset
		var replacement := str(value)
		result = result.substr(0, start) + replacement + result.substr(finish)
		offset += replacement.length() - regex_match.get_string().length()
	return result


func _resolve_variable(prefix: String, name: String) -> Variant:
	return _resolve_variable_result(prefix, name).get("value")


func resolve_speaker(kind: int, source: String) -> Dictionary:
	match kind:
		KonadoScriptSyntaxTree.DialogueNode.SpeakerKind.ACTOR:
			return _actor_speaker_success(source)
		KonadoScriptSyntaxTree.DialogueNode.SpeakerKind.TEXT:
			return {"ok": true, "value": _interpolate_variables(source)}
		KonadoScriptSyntaxTree.DialogueNode.SpeakerKind.TEMPORARY_VARIABLE:
			return _speaker_from_variable("$", source)
		KonadoScriptSyntaxTree.DialogueNode.SpeakerKind.PERSISTENT_VARIABLE:
			return _speaker_from_variable("%", source)
	return {"ok": false, "error": "未知的对话署名类型：%d" % kind}


func _speaker_from_variable(prefix: String, name: String) -> Dictionary:
	var resolution := _resolve_variable_result(prefix, name)
	if not bool(resolution.get("found", false)):
		return {
			"ok": false, "error": "找不到%s变量 '%s%s'" % [_variable_scope_name(prefix), prefix, name]
		}
	var value: Variant = resolution.get("value")
	if not (value is String or value is StringName):
		return {"ok": false, "error": "对话署名变量 '%s%s' 必须保存字符串演员 ID" % [prefix, name]}
	return _actor_speaker_success(String(value))


func _actor_speaker_success(value: String) -> Dictionary:
	if value.is_empty():
		return {"ok": false, "error": "对话署名变量必须保存非空的演员 ID"}
	return {"ok": true, "value": value}


func _resolve_variable_result(prefix: String, name: String) -> Dictionary:
	if prefix == "%" and _host.variable_store != null and _host.variable_store.has(name):
		return {"found": true, "value": _host.variable_store.get_value(name)}
	if prefix == "$" and _host._temp_variables.has(name):
		return {"found": true, "value": _host._temp_variables[name]}
	return {"found": false}


func _warn_missing_variable(prefix: String, name: String) -> void:
	var key := prefix + name
	if _missing_variable_warnings.has(key):
		return
	_missing_variable_warnings[key] = true
	push_warning("Konado: 找不到%s变量 '%s'，保留原始占位符" % [_variable_scope_name(prefix), key])


func _variable_scope_name(prefix: String) -> String:
	return "持久" if prefix == "%" else "临时"


func _reload_localized_script(locale: String) -> bool:
	var service := _get_story_localization()
	if service == null or _host.current_shot == null:
		return false
	var source_path := _host.current_shot.source_path
	if source_path.is_empty() or source_path == "null":
		return false
	var localized := service.call("load_localized_script", source_path, locale, false) as KonadoShot
	if localized == null or not localized.ensure_script_ready():
		return false
	var current_program := _host.current_shot.program
	if (
		localized.program == null
		or localized.program.control_flow_sha256 != current_program.control_flow_sha256
	):
		push_error("Konado: 本地化剧本结构与默认剧本不一致，已拒绝热切换")
		return false
	_host.current_shot.install_locale_overlay(localized.locale_overlay)
	_host.start_dialogue_shot = localized
	_host._refresh_current_localized_dialogue()
	return true


func _get_story_localization() -> Node:
	if _host._story_localization == null and _host.is_inside_tree():
		_host._story_localization = (_host.get_tree().root.get_node_or_null(
			"KonadoStoryLocalization"
		))
	return _host._story_localization


func _load_localized_shot(shot: KonadoShot) -> KonadoShot:
	var service := _get_story_localization()
	if service == null or shot == null or shot.source_path.is_empty() or shot.source_path == "null":
		return shot
	var localized := (
		service.call("load_localized_script", shot.source_path, "", false) as KonadoShot
	)
	return localized if localized != null else shot


func _apply_setting(category: String, key: String, value: Variant) -> void:
	if category == "text":
		match key:
			"text_speed":
				_host.typing_interval = float(value)
			"auto_delay":
				_host.auto_play_delay = float(value)
			"auto_mode":
				_host.start_autoplay(bool(value))


func _save_game(id: int) -> bool:
	if _host.save_system == null:
		return false
	return _host.save_system.save_game(id)


func _load_game(id: int) -> bool:
	if _host.save_system == null:
		return false
	return _host.save_system.load_game(id)


func _delete_save(id: int) -> bool:
	if _host.save_system == null:
		return false
	return _host.save_system.delete_save(id)


func _get_save_info(id: int) -> Dictionary:
	return _host.save_system.get_save_info(id) if _host.save_system != null else {}


func _get_all_save_info() -> Array[Dictionary]:
	return _host.save_system.get_all_save_info() if _host.save_system != null else []
