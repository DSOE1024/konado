extends Resource
class_name Dialogue

## 源对话文件行号
var source_file_line: int = -1

## 对话类型枚举
enum Type {
	START,               # 开始
	ORDINARY_DIALOG,     # 普通对话
	DISPLAY_ACTOR,       # 显示演员
	ACTOR_CHANGE_STATE,  # 演员切换状态
	MOVE_ACTOR,          # 移动角色
	SWITCH_BACKGROUND,   # 切换背景
	EXIT_ACTOR,          # 演员退场
	PLAY_BGM,            # 播放BGM
	STOP_BGM,            # 停止播放BGM
	PLAY_SOUND_EFFECT,   # 播放音效
	SHOW_CHOICE,         # 显示选项
	BRANCH,              # 分支
	JUMP,                # 跳转（修正原JUMP_Shot语义）
	THE_END              # 剧终
}

@export var dialog_type: Type:
	set(v):
		dialog_type = v
		notify_property_list_changed()

#  用于标记跳转点		
var branch_id: String

# 对话内容
var branch_dialogue: Array[Dialogue] = []

# 是否加载完成
var is_branch_loaded: bool = false

# 对话人物ID
var character_id: String
# 对话内容
var dialog_content: String
# 显示的角色

# 创建和显示的角色ID
var character_name: String
# 角色图片ID
var character_state: String
# 创建角色的位置
var actor_position: Vector2
# 角色图片缩放
var actor_scale: float
## 演员立绘水平镜像翻转
var actor_mirror: bool

# 隐藏的角色
var exit_actor: String
# 要切换状态的角色
var change_state_actor: String
# 要切换的状态
var change_state: String
# 要移动的角色
var target_move_chara: String
# 角色要移动的位置
var target_move_pos: Vector2
# 选项
var choices: Array[DialogueChoice] = []
# BGM
var bgm_name: String
# 语音名称
var voice_id: String
# 音效名称
var soundeffect_name: String
# 对话背景图片
var background_image_name: String
# 背景切换特效
var background_toggle_effects: KND_ActingInterface.BackgroundTransitionEffectsType

# 目标跳转的镜头
var jump_shot_id: String

# 保存不同分支故事线的演员字典，默认故事线为"main"
# 角色信息字典结构说明:
# {
#     "id": int,        # 角色唯一标识
#     "x": float,       # X轴坐标
#     "y": float,       # Y轴坐标
#     "state": String,   # 当前状态标识
#     "c_scale": float, # 缩放系数
#     "mirror": bool    # 是否镜像翻转
# }
@export var actor_snapshots: Dictionary = {}

#region 自定义显示模板
class Label_Template:
	@export var label_notes: String = ""
	static func get_property_infos():
		var infos = {}
		for info in (Label_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos

class Tag_Template:
	@export var branch_id: String = ""
	static func get_property_infos():
		var infos = {}
		for info in (Tag_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos

class TagDialogue_Template:
	@export var branch_dialogue: Array[Dialogue] = []
	static func get_property_infos():
		var infos = {}
		for info in (TagDialogue_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos

class Ordinary_Dialog_Template:
	@export var character_id: String = ""
	@export_multiline var dialog_content: String = ""
	@export var voice_id: String = ""
	static func get_property_infos():
		var infos = {}
		for info in (Ordinary_Dialog_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos
	
class Switch_Background_Template:
	@export var background_image_name: String = ""
	@export var background_toggle_effects: KND_ActingInterface.BackgroundTransitionEffectsType
	static func get_property_infos():
		var infos = {}
		for info in (Switch_Background_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos
		
class Actor_Template:
	@export var character_name: String
	@export var character_state: String
	@export var actor_position: Vector2
	@export var actor_scale: float
	@export var actor_mirror: bool
	@export var exit_actor: String = ""
	@export var change_state_actor: String = ""
	@export var change_state: String = ""
	@export var target_move_chara: String = ""
	@export var target_move_pos: Vector2 = Vector2(0, 0)
	static func get_property_infos():
		var infos = {}
		for info in (Actor_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos
		
class Play_Audio_Template:
	@export var bgm_name: String = ""
	#@export var voice_name: String = ""
	@export var soundeffect_name: String = ""
	static func get_property_infos():
		var infos = {}
		for info in (Play_Audio_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos
class Choice_Template:
	@export var choices: Array[DialogueChoice] = []
	static func get_property_infos():
		var infos = {}
		for info in (Choice_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos
	
class Jump_Template:
	@export var jump_shot_id: String = ""
	static func get_property_infos():
		var infos = {}
		for info in (Jump_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos
		
class Unlock_Achievements_Template:
	@export var achievement_id: String = ""
	static func get_property_infos():
		var infos = {}
		for info in (Unlock_Achievements_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos

class ITEM_OP_Template:
	@export var item_id: String = ""
	static func get_property_infos():
		var infos = {}
		for info in (ITEM_OP_Template as Script).get_script_property_list():
			infos[info.name] = info
		return infos
#endregion

func _get_property_list():
	var list = []
	if dialog_type == Type.BRANCH:
		var tag_template = Tag_Template.get_property_infos()
		var tag_dialogue_template = TagDialogue_Template.get_property_infos()
		list.append(tag_template["branch_id"])
		list.append(tag_dialogue_template["branch_dialogue"])
	if dialog_type == Type.ORDINARY_DIALOG:
		var oridinary_dialog_template = Ordinary_Dialog_Template.get_property_infos()
		list.append(oridinary_dialog_template["character_id"])
		list.append(oridinary_dialog_template["dialog_content"])
		list.append(oridinary_dialog_template["voice_id"])
	if dialog_type == Type.DISPLAY_ACTOR:
		var actor_template = Actor_Template.get_property_infos()
		list.append(actor_template["character_name"])
		list.append(actor_template["character_state"])
		list.append(actor_template["actor_position"])
		list.append(actor_template["actor_scale"])
		list.append(actor_template["actor_mirror"])
	if dialog_type == Type.ACTOR_CHANGE_STATE:
		var actor_template = Actor_Template.get_property_infos()
		list.append(actor_template["change_state_actor"])
		list.append(actor_template["change_state"])
	if dialog_type == Type.MOVE_ACTOR:
		var actor_template = Actor_Template.get_property_infos()
		list.append(actor_template["target_move_chara"])
		list.append(actor_template["target_move_pos"])
	if dialog_type == Type.SWITCH_BACKGROUND:
		var switch_background_template = Switch_Background_Template.get_property_infos()
		list.append(switch_background_template["background_image_name"])
		list.append(switch_background_template["background_toggle_effects"])
	if dialog_type == Type.EXIT_ACTOR:
		var actor_template = Actor_Template.get_property_infos()
		list.append(actor_template["exit_actor"])
	if dialog_type == Type.PLAY_BGM:
		var play_audio_template = Play_Audio_Template.get_property_infos()
		list.append(play_audio_template["bgm_name"])
	if dialog_type == Type.STOP_BGM:
		pass
	if dialog_type == Type.PLAY_SOUND_EFFECT:
		var play_audio_template = Play_Audio_Template.get_property_infos()
		list.append(play_audio_template["soundeffect_name"])
	if dialog_type == Type.SHOW_CHOICE:
		var choice_template = Choice_Template.get_property_infos()
		list.append(choice_template["choices"])
	if dialog_type == Type.JUMP:
		var jump_template = Jump_Template.get_property_infos()
		list.append(jump_template["jump_shot_id"])
	if dialog_type == Type.THE_END:
		pass
	return list
	

# 转换为JSON字符串
func to_json() -> String:
	var data = serialize_to_dict()
	return JSON.stringify(data, "\t")

# 从JSON字符串解析
func from_json(json_string: String) -> bool:
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("JSON解析错误: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		return false
	
	var data = json.data
	if data is Dictionary:
		return deserialize_from_dict(data)

	push_error("JSON数据格式错误: 根元素不是字典")
	return false

# 序列化为字典
func serialize_to_dict() -> Dictionary:
	var dict = {}
	
	# 基本属性
	dict["source_file_line"] = source_file_line
	dict["dialog_type"] = Type.keys()[dialog_type]
	
	# 根据对话类型序列化相关属性
	match dialog_type:
		Type.BRANCH:
			dict["branch_id"] = branch_id
			dict["branch_dialogue"] = serialize_dialogue_array(branch_dialogue)
			dict["is_branch_loaded"] = is_branch_loaded
		
		Type.ORDINARY_DIALOG:
			dict["character_id"] = character_id
			dict["dialog_content"] = dialog_content
			dict["voice_id"] = voice_id
		
		Type.DISPLAY_ACTOR:
			dict["character_name"] = character_name
			dict["character_state"] = character_state
			dict["actor_position"] = {"x": actor_position.x, "y": actor_position.y}
			dict["actor_scale"] = actor_scale
			dict["actor_mirror"] = actor_mirror
		
		Type.ACTOR_CHANGE_STATE:
			dict["change_state_actor"] = change_state_actor
			dict["change_state"] = change_state
		
		Type.MOVE_ACTOR:
			dict["target_move_chara"] = target_move_chara
			dict["target_move_pos"] = {"x": target_move_pos.x, "y": target_move_pos.y}
		
		Type.SWITCH_BACKGROUND:
			dict["background_image_name"] = background_image_name
			dict["background_toggle_effects"] = background_toggle_effects
		
		Type.EXIT_ACTOR:
			dict["exit_actor"] = exit_actor
		
		Type.PLAY_BGM:
			dict["bgm_name"] = bgm_name
		
		Type.PLAY_SOUND_EFFECT:
			dict["soundeffect_name"] = soundeffect_name
		
		Type.SHOW_CHOICE:
			dict["choices"] = serialize_choice_array(choices)
		
		Type.JUMP:
			dict["jump_shot_id"] = jump_shot_id
		
	
	# 演员快照
	dict["actor_snapshots"] = actor_snapshots.duplicate(true)
	
	return dict

# 从字典反序列化
func deserialize_from_dict(dict: Dictionary) -> bool:
	# 基本属性
	if "source_file_line" in dict:
		source_file_line = dict["source_file_line"]
	
	if "dialog_type" in dict:
		var type_str = dict["dialog_type"]
		if Type.keys().has(type_str):
			dialog_type = Type.get(type_str)
		else:
			push_error("未知的对话类型: " + str(type_str))
			return false
	
	# 根据对话类型反序列化相关属性
	match dialog_type:
		Type.BRANCH:
			if "branch_id" in dict:
				branch_id = dict["branch_id"]
			if "branch_dialogue" in dict:
				branch_dialogue = deserialize_dialogue_array(dict["branch_dialogue"])
			if "is_branch_loaded" in dict:
				is_branch_loaded = dict["is_branch_loaded"]
		
		Type.ORDINARY_DIALOG:
			if "character_id" in dict:
				character_id = dict["character_id"]
			if "dialog_content" in dict:
				dialog_content = dict["dialog_content"]
			if "voice_id" in dict:
				voice_id = dict["voice_id"]
		
		Type.DISPLAY_ACTOR:
			if "character_name" in dict:
				character_name = dict["character_name"]
			if "character_state" in dict:
				character_state = dict["character_state"]
			if "actor_position" in dict:
				var pos_dict = dict["actor_position"]
				if pos_dict is Dictionary and "x" in pos_dict and "y" in pos_dict:
					actor_position = Vector2(pos_dict["x"], pos_dict["y"])
			if "actor_scale" in dict:
				actor_scale = dict["actor_scale"]
			if "actor_mirror" in dict:
				actor_mirror = dict["actor_mirror"]
		
		Type.ACTOR_CHANGE_STATE:
			if "change_state_actor" in dict:
				change_state_actor = dict["change_state_actor"]
			if "change_state" in dict:
				change_state = dict["change_state"]
		
		Type.MOVE_ACTOR:
			if "target_move_chara" in dict:
				target_move_chara = dict["target_move_chara"]
			if "target_move_pos" in dict:
				var pos_dict = dict["target_move_pos"]
				if pos_dict is Dictionary and "x" in pos_dict and "y" in pos_dict:
					target_move_pos = Vector2(pos_dict["x"], pos_dict["y"])
		
		Type.SWITCH_BACKGROUND:
			if "background_image_name" in dict:
				background_image_name = dict["background_image_name"]
			if "background_toggle_effects" in dict:
				background_toggle_effects = dict["background_toggle_effects"]
		
		Type.EXIT_ACTOR:
			if "exit_actor" in dict:
				exit_actor = dict["exit_actor"]
		
		Type.PLAY_BGM:
			if "bgm_name" in dict:
				bgm_name = dict["bgm_name"]
		
		Type.PLAY_SOUND_EFFECT:
			if "soundeffect_name" in dict:
				soundeffect_name = dict["soundeffect_name"]
		
		Type.SHOW_CHOICE:
			if "choices" in dict:
				choices = deserialize_choice_array(dict["choices"])
		
		Type.JUMP:
			if "jump_shot_id" in dict:
				jump_shot_id = dict["jump_shot_id"]
		

	# 演员快照
	if "actor_snapshots" in dict:
		actor_snapshots = dict["actor_snapshots"].duplicate(true)
	
	return true

# 序列化对话数组
func serialize_dialogue_array(dialogues: Array[Dialogue]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dialogue in dialogues:
		if dialogue:
			result.append(dialogue.serialize_to_dict())
	return result

# 反序列化对话数组
func deserialize_dialogue_array(data: Array) -> Array[Dialogue]:
	var result: Array[Dialogue] = []
	for item in data:
		if item is Dictionary:
			var dialogue = Dialogue.new()
			if dialogue.deserialize_from_dict(item):
				result.append(dialogue)
	return result

# 序列化选项数组
func serialize_choice_array(choices: Array[DialogueChoice]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for choice in choices:
		if choice:
			result.append(choice.serialize_to_dict())
	return result

# 反序列化选项数组
func deserialize_choice_array(data: Array) -> Array[DialogueChoice]:
	var result: Array[DialogueChoice] = []
	for item in data:
		if item is Dictionary:
			var choice = DialogueChoice.new()
			if choice.deserialize_from_dict(item):
				result.append(choice)
	return result
