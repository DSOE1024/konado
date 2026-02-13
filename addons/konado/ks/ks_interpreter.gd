extends RefCounted
class_name KonadoScriptsInterpreter

## Konado脚本解释器

## 是否初始化完成
var is_init: bool = false

## 源文件脚本路径
var tmp_path = ""
## 源文件脚本行，显示在编辑器中
var tmp_original_line_number = 0
## 当前脚本行，经过处理后的行
var tmp_line_number = 0
var tmp_content_lines = []

## 对话内容正则表达式
var dialogue_content_regex: RegEx
## Shot Id 元数据正则表达式
var shot_id_metedata_regex: RegEx

## 演员验证表
var cur_tmp_actors = []

## 角色依赖记录，出现的角色将记录下来
var dep_characters: Array[String] = []

## 选项行记录表 key: 行号 value: 行内容
var cur_tmp_option_lines = {}
var tmp_tags = []

# ====================== 编译选项 ====================== #

## 是否允许自定义后缀脚本，开启后将不强制要求使用ks作为脚本文件后缀
var allow_custom_suffix: bool = false

## 是否允许跳过错误语法行，开启后将跳过错误语法行，继续解析后续语法，只打印警告信息
var allow_skip_error_line: bool = false

## 是否开启演员验证，开启后将针对所有演员语法进行验证，判断是否存在
var enable_actor_validation: bool = true

# ====================== choice缩进解析临时变量 ====================== #
## 是否处于choice缩进选项解析中（支持缩进式choice）
var tmp_in_choice_indent: bool = false
## 当前正在解析的choice对话框对象（支持缩进式choice）
var tmp_current_choice_dialog: Dialogue = null
## 缩进式choice的起始行号（支持缩进式choice）
var tmp_choice_start_line: int = 0

# ====================================================== #


func _init(flags: Dictionary[String, Variant]) -> void:
	is_init = false
	if flags.has("allow_custom_suffix"):
		if flags["allow_custom_suffix"] is not bool:
			_scripts_debug(tmp_path, tmp_original_line_number, "allow_custom_suffix选项类型错误，应为bool类型")
			return
		allow_custom_suffix = flags["allow_custom_suffix"] as bool
	if flags.has("allow_skip_error_line"):
		if flags["allow_skip_error_line"] is not bool:
			_scripts_debug(tmp_path, tmp_original_line_number, "allow_skip_error_line选项类型错误，应为bool类型")
			return
		allow_skip_error_line = flags["allow_skip_error_line"] as bool
	if flags.has("enable_actor_validation"):
		if flags["enable_actor_validation"] is not bool:
			_scripts_debug(tmp_path, tmp_original_line_number, "enable_actor_validation选项类型错误，应为bool类型")
			return
		enable_actor_validation = flags["enable_actor_validation"] as bool
		
	# 提前初始化正则表达式，避免重复编译
	dialogue_content_regex = RegEx.new()
	dialogue_content_regex.compile("^\"(.*?)\"\\s+\"(.*?)\"(?:\\s+(\\S+))?$")

	shot_id_metedata_regex = RegEx.new()
	shot_id_metedata_regex.compile("^(shot_id)\\s+(\\S+)")
	
	is_init = true
	print("解释器初始化完成" + " " + "flags: " + str(flags))
	
## 全文解析模式
func process_scripts_to_data(path: String) -> KND_Shot:
	if not is_init:
		_scripts_debug(path, 0, "解释器未初始化，无法解析脚本文件")
		return null  # 统一返回null，符合返回值类型
	if not path:
		_scripts_debug(path, 0, "路径为空，无法打开脚本文件")
		return null

	if not FileAccess.file_exists(path):
		_scripts_debug(path, 0, "文件不存在，无法打开脚本文件")
		return null

	if not path.ends_with(".ks"):
		if allow_custom_suffix:
			_scripts_warning(path, 0, "建议使用使用ks作为脚本文件后缀")
		else:
			_scripts_debug(path, 0, "编译器要求使用ks作为脚本文件后缀，如果需要使用自定义后缀，请开启allow_custom_suffix选项")
			return null

	tmp_path = path

	# 读取文件内容
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_scripts_debug(path, 0, "无法打开脚本文件")
		return null
	var raw_script_lines = file.get_as_text().split("\n")
	file.close()

	
	_scripts_info(path, 0, "开始解析脚本文件")

	var diadata: KND_Shot = KND_Shot.new()

	# 解析元数据
	var metadata_result = _parse_metadata(raw_script_lines, path)
	shot_id_metedata_regex = null
	if not metadata_result:
		_scripts_debug(path, 0, "元数据解析失败")
		return null  # 元数据失败直接终止，返回null
	diadata.shot_id = metadata_result[0]


	_scripts_info(path, 1, "Shot id：%s" % [diadata.shot_id])

	# 清空演员验证表
	cur_tmp_actors = []

	# 只保留内容行
	var content_lines = raw_script_lines.slice(1)

	tmp_content_lines = content_lines

	# 重置choice缩进解析状态（新增：防止解析多文件时状态污染）
	_reset_choice_indent_state()

	# 解析内容行
	for i in content_lines.size():
		tmp_line_number = i
		var original_line = content_lines[i]  # 保留原始行（未strip），用于判断缩进（核心）
		var line = original_line.strip_edges()  # 处理后的行，用于内容解析
		var original_line_number =  i + 2

		tmp_original_line_number = original_line_number

		# ========== 核心缩进行处理逻辑 - 保留原始行判断缩进 ========== #
		# 非choice缩进解析中：跳过缩进行（保持原有逻辑）
		# choice缩进解析中：处理缩进行（新增逻辑）
		if (original_line.begins_with("    ") or original_line.begins_with("\t")) and not tmp_in_choice_indent:
			continue
		# ===================================================================== #

		# 空行或注释行，必须提前处理strip_edges
		if line.is_empty():
			continue
		if line.begins_with("#") or line.begins_with("##"):
			continue

		print("第%d行内容：" % original_line_number, line)

		# ========== 核心Choice缩进解析 - 无缩进即终止缩进（关键） ========== #
		if tmp_in_choice_indent:
			# 检查当前行是否有缩进：无缩进 → 自动结束Choice缩进，切换回普通行解析
			if not (original_line.begins_with("    ") or original_line.begins_with("\t")):
				_scripts_info(path, original_line_number, "检测到无缩进行，自动结束choice缩进解析")
				# 提交已解析的choice数据（如果有）
				if tmp_current_choice_dialog and tmp_current_choice_dialog.choices.size() > 0:
					var dialogue_dic: Dictionary = tmp_current_choice_dialog.serialize_to_dict()
					diadata.dialogues_source_data.append(dialogue_dic)
					_scripts_info(path, tmp_choice_start_line, "缩进式choice解析完成 选项数量: %d" % tmp_current_choice_dialog.choices.size())
				# 重置缩进状态
				_reset_choice_indent_state()
				# 不continue，继续处理当前无缩进行（作为普通行解析）
			else:
				# 有缩进 → 解析为choice选项行
				if not _parse_choice_indent_line(line, original_line_number, path):
					if allow_skip_error_line:
						_scripts_warning(path, original_line_number, "choice缩进选项行解析失败，跳过该行: %s" % line)
						continue
					else:
						_scripts_debug(path, original_line_number, "choice缩进选项行解析失败，终止解析: %s" % line)
						_reset_choice_indent_state()
						return null  # 用return null真正终止，替代break
				# 解析成功则跳过后续普通行解析
				continue
		# =============================================== #

		# 解析普通行（非choice缩进状态）
		var dialog: Dialogue = parse_line(line, original_line_number, path, diadata)  # 传入diadata给parse_line
		if dialog:
			# 如果是标签对话，则添加到标签对话字典中
			if dialog.dialog_type == Dialogue.Type.BRANCH:
				diadata.source_branches.set(dialog.branch_id, dialog.serialize_to_dict())
			else:
				# ====================== 修复重复空对话：核心3行修改 ====================== #
				# 一行式choice：正常添加；缩进式choice（刚解析完choice:）：跳过添加，仅缩进结束后统一提交
				# 避免解析choice:时添加空dialog，后续缩进结束又加一次造成重复
				if not (dialog.dialog_type == Dialogue.Type.SHOW_CHOICE and tmp_in_choice_indent):
					var dialogue_dic: Dictionary = dialog.serialize_to_dict()
					diadata.dialogues_source_data.append(dialogue_dic)
				# ========================================================================= #
		else:
			if allow_skip_error_line:
				_scripts_warning(path, original_line_number, "解析失败：无法识别的语法，请检查语法是否正确或删除该行: %s" % line)
				continue
			else:
				_scripts_debug(path, original_line_number, "解析失败：无法识别的语法，终止解析: %s" % line)
				_reset_choice_indent_state()
				return null  # 用return null真正终止，替代break
			
	# 解析结束后检查是否有未完成的choice缩进（文件末尾是缩进行的情况）
	if tmp_in_choice_indent and tmp_current_choice_dialog:
		if tmp_current_choice_dialog.choices.size() > 0:
			var dialogue_dic: Dictionary = tmp_current_choice_dialog.serialize_to_dict()
			diadata.dialogues_source_data.append(dialogue_dic)
			_scripts_info(path, tmp_choice_start_line, "缩进式choice解析完成 选项数量: %d" % tmp_current_choice_dialog.choices.size())
		else:
			_scripts_warning(path, tmp_choice_start_line, "choice: 后无有效选项行，忽略该choice")
			# 无有效选项时，不添加任何空dialog到diadata
		_reset_choice_indent_state()

	diadata.get_dialogues()
	

	_scripts_info(path, 0, "文件：%s 章节ID：%s 对话数量：%d" % 
		[path, diadata.shot_id, diadata.dialogues.size()])

	tmp_path = ""

	# 标签验证失败 → 真正终止解析，返回null
	if not _check_tag_and_choice():
		_scripts_debug(path, 0, "标签和选项解析失败，终止所有解析")
		return null

	# 生成演员快照
	var cur_actor_dic: Dictionary = {}
	for dialogue in diadata.get_dialogues():
		if dialogue.dialog_type == Dialogue.Type.DISPLAY_ACTOR:
			pass
				#var actor: DialogueActor = dialogue.show_actor
				#var chara_dict := {
					#"id": actor.character_name,
					#"x": actor.actor_position.x,
					#"y": actor.actor_position.y,
					#"state": actor.character_state,
					#"c_scale": actor.actor_scale,
					#"mirror": actor.actor_mirror
					#}
				#cur_actor_dic[actor.character_name] = chara_dict
		if dialogue.dialog_type == Dialogue.Type.EXIT_ACTOR:
			if cur_actor_dic.has(dialogue.exit_actor):
				cur_actor_dic.erase(dialogue.exit_actor)
		if dialogue.dialog_type == Dialogue.Type.ACTOR_CHANGE_STATE:
			if cur_actor_dic.has(dialogue.change_state_actor):
				cur_actor_dic[dialogue.change_state_actor]["state"] = dialogue.change_state
		if dialogue.dialog_type == Dialogue.Type.MOVE_ACTOR:
			if cur_actor_dic.has(dialogue.target_move_chara):
				cur_actor_dic[dialogue.target_move_chara]["x"] = dialogue.target_move_pos.x
				cur_actor_dic[dialogue.target_move_chara]["y"] = dialogue.target_move_pos.y
		dialogue.actor_snapshots = cur_actor_dic
	
	return diadata

# 单行解析模式
func parse_single_line(line: String, line_number: int, path: String) -> Dialogue:
	return parse_line(line.strip_edges(), line_number, path, null)

# 内部解析实现 - 新增diadata参数，给_parse_end用
func parse_line(line: String, line_number: int, path: String, diadata: KND_Shot) -> Dialogue:
	var dialog := Dialogue.new()
	dialog.source_file_line = line_number
	
	if _parse_background(line, dialog):
		print("解析成功：背景切换\n")
		return dialog
	if _parse_actor(line, dialog):
		print("解析成功：角色相关\n")
		return dialog
	if _parse_audio(line, dialog):
		print("解析成功：音频相关\n")
		return dialog
	if _parse_choice(line, dialog): 
		print("解析成功：选择相关\n")
		return dialog
	if _parse_jumpshot(line, dialog):
		print("解析成功：跳转镜头相关\n")
		return dialog
	if _parse_dialog(line, dialog):
		print("解析成功：对话相关\n")
		return dialog
	if _parse_end(line, dialog, diadata):  # 传入diadata
		print("解析成功：结束相关\n")
		return dialog
	if _parse_branch(line, dialog):
		print("解析成功：标签相关\n")
		return dialog

	dialog = null
	return null

# 解析元数据（前两行）
func _parse_metadata(raw_script_lines: PackedStringArray, path: String) -> PackedStringArray:
	if raw_script_lines.size() < 2:
		_scripts_debug(path, 1, "文件不完整，至少需要shot id")
		return []

	var metadata: PackedStringArray = []

	if raw_script_lines[0]:
		var result = shot_id_metedata_regex.search(raw_script_lines[0])
		if not result:
			_scripts_debug(path, 1, "无效的元数据格式: %s" % raw_script_lines[0])
			return []
		
		var key = result.get_string(1)
		var value = result.get_string(2)
		
		match key:
			"shot_id":
				metadata.append(value)
	return metadata
	
	
# 背景切换解析
func _parse_background(line: String, dialog: Dialogue) -> bool:
	if not line.begins_with("background"):
		return false
	
	var parts = line.split(" ", false)
	if parts.size() < 2:
		return false

	dialog.dialog_type = Dialogue.Type.SWITCH_BACKGROUND
	dialog.background_image_name = parts[1]
	
	if parts.size() >= 3:
		var effect = parts[2]
		dialog.background_toggle_effects = {
			"none": KND_ActingInterface.BackgroundTransitionEffectsType.NONE_EFFECT,
			"erase": KND_ActingInterface.BackgroundTransitionEffectsType.EraseEffect,
			"blinds": KND_ActingInterface.BackgroundTransitionEffectsType.BlindsEffect,
			"wave": KND_ActingInterface.BackgroundTransitionEffectsType.WaveEffect,
			"fade": KND_ActingInterface.BackgroundTransitionEffectsType.ALPHA_FADE_EFFECT,
			"vortex": KND_ActingInterface.BackgroundTransitionEffectsType.VORTEX_SWAP_EFFECT,
			"windmill": KND_ActingInterface.BackgroundTransitionEffectsType.WINDMILL_EFFECT,
			"cyberglitch": KND_ActingInterface.BackgroundTransitionEffectsType.CYBER_GLITCH_EFFECT
		}.get(effect, KND_ActingInterface.BackgroundTransitionEffectsType.NONE_EFFECT)

	return true

# 角色相关解析
func _parse_actor(line: String, dialog: Dialogue) -> bool:
	if not line.begins_with("actor"):
		return false
	
	var parts = line.split(" ", false)
	if parts.size() < 3:
		return false

	match parts[1]:
		"show":
			dialog.dialog_type = Dialogue.Type.DISPLAY_ACTOR
			dialog.character_name = parts[2]
			dialog.character_state = parts[3]
			dialog.actor_position = Vector2(parts[5].to_float(), parts[6].to_float())
			dialog.actor_scale = parts[8].to_float()
			if parts.size() == 10:
				if parts[9] == "mirror":
					dialog.actor_mirror = true
			

			if not dep_characters.has(dialog.character_name):
				dep_characters.append(dialog.character_name)
			# 添加检查功能
			if enable_actor_validation:
				if not cur_tmp_actors.has(dialog.character_name):
					cur_tmp_actors.append(dialog.character_name)
				else:
					_scripts_debug(tmp_path, tmp_original_line_number, "角色已存在，请检查角色名称是否重复创建")
					return false
		"exit":
			dialog.dialog_type = Dialogue.Type.EXIT_ACTOR
			dialog.exit_actor = parts[2]
			# 添加检查功能
			if enable_actor_validation:
				if cur_tmp_actors.has(parts[2]):
					cur_tmp_actors.erase(parts[2])
				else:
					_scripts_debug(tmp_path, tmp_original_line_number, "无法移除不存在的角色，请检查角色名称是否正确")
		"change":
			dialog.dialog_type = Dialogue.Type.ACTOR_CHANGE_STATE
			dialog.change_state_actor = parts[2]

			# 添加检查功能
			if enable_actor_validation:
				if not cur_tmp_actors.has(parts[2]):
					_scripts_debug(tmp_path, tmp_original_line_number, "无法改变不存在的角色的状态，请检查角色名称是否正确")
				
			dialog.change_state = parts[3]
		"move":
			dialog.dialog_type = Dialogue.Type.MOVE_ACTOR
			dialog.target_move_chara = parts[2]

			# 添加检查功能
			if enable_actor_validation:
				if not cur_tmp_actors.has(parts[2]):
					_scripts_debug(tmp_path, tmp_original_line_number, "无法移动不存在的角色的位置，请检查角色名称是否正确")

			dialog.target_move_pos = Vector2(parts[3].to_float(), parts[4].to_float())
	
	return true



# 音频解析
func _parse_audio(line: String, dialog: Dialogue) -> bool:
	if not line.begins_with("play") and not line.begins_with("stop"):
		return false
	
	var parts = line.split(" ", false)
	if parts[0] == "play":
		if parts[1] == "bgm":
			dialog.dialog_type = Dialogue.Type.PLAY_BGM 
		elif parts[1] == "sfx":
			dialog.dialog_type = Dialogue.Type.PLAY_SOUND_EFFECT
		dialog["bgm_name" if parts[1] == "bgm" else "soundeffect_name"] = parts[2]
	elif parts[0] == "stop":
		dialog.dialog_type = Dialogue.Type.STOP_BGM
	
	return true

# 解析选项（重构：支持一行式choice + 缩进式choice:）
func _parse_choice(line: String, dialog: Dialogue) -> bool:
	# 匹配原有一行式choice：choice "文本" 标签 "文本2" 标签2
	if line.begins_with("choice ") and not line.begins_with("choice:"):
		dialog.dialog_type = Dialogue.Type.SHOW_CHOICE
		dialog.choices.clear()  # 清空现有选项
		
		# 移除开头的"choice"关键字
		var content = line.substr(6).strip_edges()
		
		# 使用正则表达式来正确解析带引号的字符串
		var regex = RegEx.new()
		regex.compile('"([^"\\\\]*(?:\\\\.[^"\\\\]*)*)"|(\\S+)')
		
		var matches = regex.search_all(content)
		var parts = []
		
		for match in matches:
			if match.get_string(1) != "":  # 带引号的部分
				# 恢复转义的引号
				var text = match.get_string(1).replace('\\"', '"')
				parts.append(text)
			elif match.get_string(2) != "":  # 无引号的部分
				parts.append(match.get_string(2))
		
		# 验证parts数量
		if parts.size() % 2 != 0:
			_scripts_debug(tmp_path, tmp_original_line_number, "选项格式错误: 每个选项必须包含文本和跳转标签")
			return false
		
		# 创建选项对象
		for i in range(0, parts.size(), 2):
			var choice = DialogueChoice.new()
			choice.choice_text = parts[i]
			choice.jump_tag = parts[i + 1]
			dialog.choices.append(choice)
		
		# 记录日志
		var choices_strs = ""
		for choice in dialog.choices:
			choices_strs += "\"" + choice.choice_text + "\" -> " + choice.jump_tag + "  "
		
		# 记录跳转标签用于后续验证
		var jump_tags = []
		for choice in dialog.choices:
			jump_tags.append(choice.jump_tag)
		cur_tmp_option_lines[tmp_original_line_number] = jump_tags
		
		_scripts_info(tmp_path, tmp_line_number + 1, "一行式选项解析完成 选项数量: " + str(dialog.choices.size()) + "  选项: " + choices_strs)
		return true
	
	# 严格匹配choice:（无多余字符），避免误判
	if line == "choice:":
		dialog.dialog_type = Dialogue.Type.SHOW_CHOICE
		dialog.choices.clear()  # 清空现有选项
		# 设置choice缩进解析状态，后续行将作为选项行解析
		tmp_in_choice_indent = true
		tmp_current_choice_dialog = dialog
		tmp_choice_start_line = tmp_original_line_number
		_scripts_info(tmp_path, tmp_original_line_number, "开始解析缩进式choice，后续缩进行为选项行")
		return true
	return false

# 解析choice缩进选项行，格式："选项文本" 目标分支
func _parse_choice_indent_line(line: String, line_number: int, path: String) -> bool:
	# 校验当前是否处于choice缩进解析中，防止非法调用
	if not tmp_in_choice_indent or not tmp_current_choice_dialog:
		_scripts_debug(path, line_number, "非法的choice缩进行，未找到choice: 起始标记")
		_reset_choice_indent_state()
		return false
	
	# 校验行是否为空
	if line.is_empty():
		return true  # 跳过空行，不报错
	
	# 正则匹配："选项文本" 目标分支（兼容转义引号）
	var regex = RegEx.new()
	regex.compile('^"([^"\\\\]*(?:\\\\.[^"\\\\]*)*)"\\s+(\\S+)$')
	var result = regex.search(line)
	if not result:
		_scripts_debug(path, line_number, "choice缩进选项行格式错误，正确格式：\"选项文本\" 目标分支")
		return false
	
	# 提取选项文本和目标分支
	var choice_text = result.get_string(1).replace('\\"', '"')  # 恢复转义引号
	var jump_tag = result.get_string(2)
	
	# 创建选项对象并添加到当前choice dialog
	var choice = DialogueChoice.new()
	choice.choice_text = choice_text
	choice.jump_tag = jump_tag
	tmp_current_choice_dialog.choices.append(choice)
	
	# 记录跳转标签到全局验证表（和原有逻辑一致，保证_check_tag_and_choice生效）
	if not cur_tmp_option_lines.has(tmp_choice_start_line):
		cur_tmp_option_lines[tmp_choice_start_line] = []
	cur_tmp_option_lines[tmp_choice_start_line].append(jump_tag)
	
	_scripts_info(path, line_number, "choice缩进选项解析成功：\"%s\" -> %s" % [choice_text, jump_tag])
	return true

# 分支解析
func _parse_branch(line: String, dialog: Dialogue) -> bool:
	# 禁止在choice缩进中嵌套branch
	if tmp_in_choice_indent:
		_scripts_debug(tmp_path, tmp_original_line_number, "choice缩进中不允许嵌套branch标签")
		_reset_choice_indent_state()
		return false
	
	if not line.begins_with("branch"):
		return false
	
	var parts = line.split(" ", false)
	if parts.size() < 2:
		_scripts_debug(tmp_path, tmp_original_line_number, "branch格式错误")
		return false
	dialog.dialog_type = Dialogue.Type.BRANCH
	dialog.branch_id = parts[1]

	var tag_inner_line_number = tmp_line_number + 1
	var expected_indent = "    "  # 预期的缩进（4个空格或制表符）

	# 遍历标签内的行(缩进)
	while tag_inner_line_number < tmp_content_lines.size():
		var original_line = tmp_content_lines[tag_inner_line_number]
		var inner_line = original_line.strip_edges()
		
		# 检查是否为空行或只有空白字符的行
		if inner_line.is_empty():
			tag_inner_line_number += 1
			continue  # 跳过空行但继续处理后续内容
		
		# 检查缩进，允许4个空格或制表符
		if not (original_line.begins_with("    ") or original_line.begins_with("\t")):
			break  # 没有缩进，结束分支内容
		
		tag_inner_line_number += 1
		
		if inner_line.begins_with("branch"):
			_scripts_debug(tmp_path, tag_inner_line_number, "branch内不能嵌套branch")
			return false
		
		var inner_dialog = parse_line(inner_line, tag_inner_line_number, tmp_path, null)
		if inner_dialog:
			dialog.branch_dialogue.append(inner_dialog)

	tmp_tags.append(dialog.branch_id)

	_scripts_info(tmp_path, tmp_original_line_number, "标签" + dialog.branch_id + "解析完成" + " " + "标签内有" + str(dialog.branch_dialogue.size()) + "行对话")

	return true

# 跳转解析
func _parse_jumpshot(line: String, dialog: Dialogue) -> bool:
	if not line.begins_with("jump"):
		return false
	
	var parts = line.split(" ", false)
	dialog.dialog_type = Dialogue.Type.JUMP
	dialog.jump_shot_id = parts[1]
	return true

# 对话解析（使用正则表达式优化）
func _parse_dialog(line: String, dialog: Dialogue) -> bool:
	if not line.begins_with("\""):
		return false
	
	var result = dialogue_content_regex.search(line)
	if not result:
		return false
	
	dialog.dialog_type = Dialogue.Type.ORDINARY_DIALOG
	dialog.character_id = result.get_string(1)
	dialog.dialog_content = result.get_string(2)
	if result.get_string(3):
		dialog.voice_id = result.get_string(3)
	
	return true

# 检查tag和choice（原有逻辑不变，缩进式choice的跳转标签已统一记录到cur_tmp_option_lines）
func _check_tag_and_choice() -> bool:
	for line_num in cur_tmp_option_lines:
		var jump_tags = cur_tmp_option_lines[line_num] as Array
		for tag in jump_tags:
			if not tmp_tags.has(tag):
				_scripts_debug(tmp_path, line_num, "跳转标签 '" + tag + "' 不存在")
				return false
	return true

	
# 解析结束 - 新增diadata参数，解决end行结束缩进时的参数缺失
func _parse_end(line: String, dialog: Dialogue, diadata: KND_Shot) -> bool:
	# 如果是end行，结束当前choice缩进解析并添加dialog
	if tmp_in_choice_indent and tmp_current_choice_dialog and diadata != null:
		# 检查是否有解析到选项
		if tmp_current_choice_dialog.choices.size() > 0:
			var dialogue_dic: Dictionary = tmp_current_choice_dialog.serialize_to_dict()
			diadata.dialogues_source_data.append(dialogue_dic)
			_scripts_info(tmp_path, tmp_choice_start_line, "缩进式choice解析完成 选项数量: %d" % tmp_current_choice_dialog.choices.size())
		else:
			_scripts_warning(tmp_path, tmp_choice_start_line, "choice: 后无有效选项行，忽略该choice")
			# 无有效选项时，不添加任何空dialog到diadata
		# 重置状态
		_reset_choice_indent_state()
	
	if line.begins_with("end"):
		dialog.dialog_type = Dialogue.Type.THE_END
		return true
	return false

# 统一重置Choice缩进状态（核心，避免状态残留）
func _reset_choice_indent_state() -> void:
	tmp_in_choice_indent = false
	tmp_current_choice_dialog = null
	tmp_choice_start_line = 0

# 错误报告
func _scripts_debug(path: String, line: int, error_info: String):
	push_error("错误：%s [行：%d] %s " % [path, line, error_info])


# 警告提示
func _scripts_warning(path: String, line: int, warning_info: String):
	push_warning("警告：%s [行：%d] %s " % [path, line, warning_info])

# 信息提示
func _scripts_info(path: String, line: int, info_info: String):
	print("信息：%s [行：%d] %s " % [path, line, info_info])
