extends RefCounted
class_name KS_LanguageCatalog

## KonadoScript 编辑器功能使用的统一语言目录。
##
## 解析器仍以 KS_Token.KEYWORDS 作为合法关键字的唯一来源。本目录只描述
## 编辑器展示所需的分组、补全关系和可插入模板，并通过测试确保目录中的
## 关键字始终是解析器已注册的关键字。

const ROOT_KEYWORDS: PackedStringArray = [
	"screentext",
	"showtextbox",
	"hidetextbox",
	"waitsignal",
	"background",
	"actor",
	"play",
	"stop",
	"choice",
	"branch",
	"if",
	"else",
	"endif",
	"set",
	"add",
	"sub",
	"mul",
	"div",
	"jump",
	"jump_branch",
	"signal",
	"achievement",
	"cam",
	"asyncam",
	"end",
]

const CONTEXT_COMPLETIONS: Dictionary = {
	"actor": ["show", "exit", "change", "move", "motion"],
	"play": ["bgm", "sfx"],
	"stop": ["bgm"],
	"cam": ["move", "reset", "shake"],
	"asyncam": ["move", "reset", "shake", "stop"],
	"achievement": ["unlock", "increment", "set_flag"],
}

const STRUCTURAL_KEYWORDS: PackedStringArray = ["at"]

const SNIPPETS: Array[Dictionary] = [
	{
		"group": "dialogue",
		"label": "Dialogue",
		"label_zh": "对话",
		"snippet": '"Character" "Dialogue content" voice_id',
		"description": "Insert a character dialogue line",
		"description_zh": "插入角色对话",
	},
	{
		"group": "text",
		"label": "Screen text",
		"label_zh": "全屏文本",
		"snippet": 'screentext {\n    "Text"\n}',
		"description": "Display NVL-style full-screen text",
		"description_zh": "显示 NVL 风格全屏文本",
	},
	{
		"group": "text",
		"label": "Show dialogue box",
		"label_zh": "显示对话框",
		"snippet": "showtextbox 1.0",
		"description": "Show the dialogue box with an optional duration",
		"description_zh": "按指定时长显示对话框",
	},
	{
		"group": "text",
		"label": "Hide dialogue box",
		"label_zh": "隐藏对话框",
		"snippet": "hidetextbox 1.0",
		"description": "Hide the dialogue box with an optional duration",
		"description_zh": "按指定时长隐藏对话框",
	},
	{
		"group": "text",
		"label": "Wait for signal",
		"label_zh": "等待信号",
		"snippet": "waitsignal signal_name",
		"description": "Pause until an external signal is emitted",
		"description_zh": "暂停并等待外部信号",
	},
	{
		"group": "stage",
		"label": "Background",
		"label_zh": "切换背景",
		"snippet": "background background_name none",
		"description": "Switch the background with an optional transition",
		"description_zh": "切换背景并指定可选转场",
	},
	{
		"group": "actor",
		"label": "Show actor",
		"label_zh": "演员入场",
		"snippet": "actor show actor_name state_name at 2",
		"description": "Show an actor in a state and position",
		"description_zh": "以指定状态和位置显示演员",
	},
	{
		"group": "actor",
		"label": "Exit actor",
		"label_zh": "演员退场",
		"snippet": "actor exit actor_name",
		"description": "Remove an actor from the stage",
		"description_zh": "让演员离开舞台",
	},
	{
		"group": "actor",
		"label": "Change actor state",
		"label_zh": "切换演员状态",
		"snippet": "actor change actor_name state_name",
		"description": "Change an actor state",
		"description_zh": "切换演员状态",
	},
	{
		"group": "actor",
		"label": "Move actor",
		"label_zh": "移动演员",
		"snippet": "actor move actor_name 2",
		"description": "Move an actor to another position",
		"description_zh": "将演员移动到指定位置",
	},
	{
		"group": "actor",
		"label": "Play actor motion",
		"label_zh": "播放演员动作",
		"snippet": "actor motion actor_name motion_name",
		"description": "Play an actor stage-layer motion",
		"description_zh": "播放演员舞台层动作",
	},
	{
		"group": "audio",
		"label": "Play BGM",
		"label_zh": "播放 BGM",
		"snippet": "play bgm bgm_name",
		"description": "Play background music",
		"description_zh": "播放背景音乐",
	},
	{
		"group": "audio",
		"label": "Play SFX",
		"label_zh": "播放音效",
		"snippet": "play sfx sfx_name",
		"description": "Play a sound effect",
		"description_zh": "播放音效",
	},
	{
		"group": "audio",
		"label": "Stop BGM",
		"label_zh": "停止 BGM",
		"snippet": "stop bgm",
		"description": "Stop background music",
		"description_zh": "停止背景音乐",
	},
	{
		"group": "camera",
		"label": "Move camera",
		"label_zh": "移动相机",
		"snippet": "cam move target linear 1.0",
		"description": "Move the camera and wait for completion",
		"description_zh": "移动相机并等待完成",
	},
	{
		"group": "camera",
		"label": "Reset camera",
		"label_zh": "复位相机",
		"snippet": "cam reset linear 1.0",
		"description": "Reset the camera and wait for completion",
		"description_zh": "复位相机并等待完成",
	},
	{
		"group": "camera",
		"label": "Shake camera",
		"label_zh": "晃动相机",
		"snippet": "cam shake 1.0",
		"description": "Shake the camera and wait for completion",
		"description_zh": "晃动相机并等待完成",
	},
	{
		"group": "camera",
		"label": "Move camera asynchronously",
		"label_zh": "异步移动相机",
		"snippet": "asyncam move target linear 1.0",
		"description": "Move the camera without blocking dialogue",
		"description_zh": "移动相机但不阻塞对话",
	},
	{
		"group": "camera",
		"label": "Reset camera asynchronously",
		"label_zh": "异步复位相机",
		"snippet": "asyncam reset linear 1.0",
		"description": "Reset the camera without blocking dialogue",
		"description_zh": "复位相机但不阻塞对话",
	},
	{
		"group": "camera",
		"label": "Shake camera asynchronously",
		"label_zh": "异步晃动相机",
		"snippet": "asyncam shake 1.0",
		"description": "Shake the camera without blocking dialogue",
		"description_zh": "晃动相机但不阻塞对话",
	},
	{
		"group": "camera",
		"label": "Stop asynchronous camera",
		"label_zh": "停止异步运镜",
		"snippet": "asyncam stop",
		"description": "Stop the active asynchronous camera operation",
		"description_zh": "停止当前异步运镜",
	},
	{
		"group": "variable",
		"label": "Set variable",
		"label_zh": "设置变量",
		"snippet": "set %variable_name = value",
		"description": "Set a persistent or temporary variable",
		"description_zh": "设置持久或临时变量",
	},
	{
		"group": "variable",
		"label": "Add variable",
		"label_zh": "变量加法",
		"snippet": "add %variable_name value",
		"description": "Add or append to a variable",
		"description_zh": "增加数值或追加字符串",
	},
	{
		"group": "variable",
		"label": "Subtract variable",
		"label_zh": "变量减法",
		"snippet": "sub %variable_name value",
		"description": "Subtract from a variable",
		"description_zh": "对变量执行减法",
	},
	{
		"group": "variable",
		"label": "Multiply variable",
		"label_zh": "变量乘法",
		"snippet": "mul %variable_name value",
		"description": "Multiply a variable",
		"description_zh": "对变量执行乘法",
	},
	{
		"group": "variable",
		"label": "Divide variable",
		"label_zh": "变量除法",
		"snippet": "div %variable_name value",
		"description": "Divide a variable",
		"description_zh": "对变量执行除法",
	},
	{
		"group": "condition",
		"label": "Conditional block",
		"label_zh": "条件块",
		"snippet": "if %variable_name == value:\n    \nelse:\n    \nendif",
		"description": "Insert an if/else conditional block",
		"description_zh": "插入 if/else 条件块",
	},
	{
		"group": "branch",
		"label": "Choice",
		"label_zh": "选项",
		"snippet": 'choice "Option" -> branch_name',
		"description": "Add a dialogue choice",
		"description_zh": "添加对话选项",
	},
	{
		"group": "branch",
		"label": "Branch",
		"label_zh": "分支",
		"snippet": "branch branch_name",
		"description": "Define a branch",
		"description_zh": "定义分支",
	},
	{
		"group": "branch",
		"label": "Jump to branch",
		"label_zh": "跳转分支",
		"snippet": "jump_branch branch_name",
		"description": "Jump to a branch in the current script",
		"description_zh": "跳转到当前脚本中的分支",
	},
	{
		"group": "flow",
		"label": "Jump to script",
		"label_zh": "跳转剧本",
		"snippet": "jump res://story/next.ks",
		"description": "Jump to another KonadoScript file",
		"description_zh": "跳转到另一个 KonadoScript 文件",
	},
	{
		"group": "flow",
		"label": "Emit signal",
		"label_zh": "发送信号",
		"snippet": "signal signal_name",
		"description": "Emit a dialogue signal",
		"description_zh": "发送对话信号",
	},
	{
		"group": "achievement",
		"label": "Unlock achievement",
		"label_zh": "解锁成就",
		"snippet": 'achievement unlock "achievement_id"',
		"description": "Unlock an achievement",
		"description_zh": "解锁成就",
	},
	{
		"group": "achievement",
		"label": "Increment achievement",
		"label_zh": "增加成就进度",
		"snippet": 'achievement increment "achievement_id" 1',
		"description": "Increment achievement progress",
		"description_zh": "增加成就进度",
	},
	{
		"group": "achievement",
		"label": "Set achievement flag",
		"label_zh": "设置成就标记",
		"snippet": 'achievement set_flag "flag_id" true',
		"description": "Set an achievement flag",
		"description_zh": "设置成就标记",
	},
	{
		"group": "flow",
		"label": "End dialogue",
		"label_zh": "结束对话",
		"snippet": "end",
		"description": "End the current dialogue",
		"description_zh": "结束当前对话",
	},
]

const GROUP_LABELS: Dictionary = {
	"dialogue": {"en": "Dialogue", "zh": "对话"},
	"text": {"en": "Text and UI", "zh": "文本与界面"},
	"stage": {"en": "Stage", "zh": "舞台"},
	"actor": {"en": "Actor", "zh": "演员"},
	"audio": {"en": "Audio", "zh": "音频"},
	"camera": {"en": "Camera", "zh": "相机"},
	"variable": {"en": "Variables", "zh": "变量"},
	"condition": {"en": "Conditions", "zh": "条件"},
	"branch": {"en": "Branches", "zh": "分支"},
	"achievement": {"en": "Achievements", "zh": "成就"},
	"flow": {"en": "Flow", "zh": "流程"},
}


static func is_chinese_locale(locale: String = OS.get_locale()) -> bool:
	return locale.to_lower().begins_with("zh")


static func get_group_label(group: String, chinese: bool) -> String:
	var labels: Dictionary = GROUP_LABELS.get(group, {"en": group, "zh": group})
	return labels["zh"] if chinese else labels["en"]


static func get_snippet_label(snippet: Dictionary, chinese: bool) -> String:
	return snippet.get("label_zh", snippet["label"]) if chinese else snippet["label"]


static func get_snippet_description(snippet: Dictionary, chinese: bool) -> String:
	return (
		snippet.get("description_zh", snippet["description"]) if chinese else snippet["description"]
	)


static func get_context_completions(root_keyword: String) -> PackedStringArray:
	return PackedStringArray(CONTEXT_COMPLETIONS.get(root_keyword, []))


static func get_background_effects() -> PackedStringArray:
	return PackedStringArray(KS_Emitter.BACKGROUND_EFFECTS_MAP.keys())


static func get_parser_keywords() -> PackedStringArray:
	var keywords := PackedStringArray()
	for keyword: String in KS_Token.KEYWORDS:
		keywords.append(keyword.trim_suffix(":"))
	keywords.sort()
	return keywords


static func get_editor_keywords() -> PackedStringArray:
	var keywords := ROOT_KEYWORDS.duplicate()
	for root_keyword: String in CONTEXT_COMPLETIONS:
		for keyword: String in CONTEXT_COMPLETIONS[root_keyword]:
			if not keywords.has(keyword):
				keywords.append(keyword)
	for keyword: String in STRUCTURAL_KEYWORDS:
		if not keywords.has(keyword):
			keywords.append(keyword)
	keywords.sort()
	return keywords


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var parser_keywords := get_parser_keywords()
	for keyword: String in get_editor_keywords():
		if not parser_keywords.has(keyword):
			errors.append("编辑器目录包含解析器不支持的关键字：%s" % keyword)
	for keyword: String in ROOT_KEYWORDS:
		if not parser_keywords.has(keyword):
			errors.append("根命令未在解析器中注册：%s" % keyword)
	for keyword: String in parser_keywords:
		if not get_editor_keywords().has(keyword):
			errors.append("解析器关键字未纳入编辑器目录：%s" % keyword)
	return errors
