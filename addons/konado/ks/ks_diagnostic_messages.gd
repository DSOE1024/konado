@tool
extends RefCounted
class_name KS_DiagnosticMessages

## Localizes compiler diagnostics shown by the Godot Script Editor.
##
## Compiler messages remain stable for logs and compatibility. The editor layer
## translates their structured message body according to the editor UI language.

const EXACT_ENGLISH: Dictionary = {
	"文件不存在，无法打开脚本文件": "The script file does not exist or cannot be opened.",
	"无法打开脚本文件": "The script file could not be opened.",
	"字符串字面量未闭合": "Unterminated string literal.",
	"解析器未能消费当前语句": "The parser could not consume the current statement.",
	"意外的 else：当前没有等待结束的 if 条件块": "Unexpected else: there is no open if block.",
	"意外的 endif：当前没有等待结束的 if 条件块": "Unexpected endif: there is no open if block.",
	"screentext 缺少 {": "screentext requires an opening {.",
	"screentext 块内仅允许字符串文本或结束符 }":
	"Only string lines or the closing } are allowed inside screentext.",
	"screentext 缺少结束符 }": "screentext requires a closing }.",
	"showtextbox 缺少动画时长": "showtextbox requires an animation duration.",
	"hidetextbox 缺少动画时长": "hidetextbox requires an animation duration.",
	"waitsignal 缺少信号名称": "waitsignal requires a signal name.",
	"background 缺少背景资源名": "background requires a background resource name.",
	"actor 缺少操作指令": "actor requires an action.",
	"actor show 缺少角色名": "actor show requires an actor name.",
	"actor show 缺少状态": "actor show requires a state.",
	"actor show 的 at 缺少位置": "actor show requires a position after at.",
	"actor exit 缺少角色名": "actor exit requires an actor name.",
	"actor change 缺少角色名": "actor change requires an actor name.",
	"actor change 缺少新状态": "actor change requires a new state.",
	"actor move 缺少角色名": "actor move requires an actor name.",
	"actor move 缺少目标坐标": "actor move requires a target position.",
	"actor motion 缺少角色名": "actor motion requires an actor name.",
	"actor motion 缺少动作名": "actor motion requires a motion name.",
	"play 缺少音频类型": "play requires an audio type.",
	"cam 缺少操作指令": "cam requires an action.",
	"cam move 缺少目标镜头名": "cam move requires a target camera.",
	"asyncam 缺少操作指令": "asyncam requires an action.",
	"asyncam move 缺少目标镜头名": "asyncam move requires a target camera.",
	"choice 缺少选项文本": "choice requires option text.",
	"choice 缺少 -> 运算符": "choice requires the -> operator.",
	"choice 缺少目标分支名": "choice requires a target branch.",
	"branch 缺少标签ID": "branch requires an identifier.",
	"if 条件缺少变量引用（格式：if %变量名 == 值:）":
	"if requires a variable reference (format: if %variable == value:).",
	"if 条件缺少比较运算符": "if requires a comparison operator.",
	"if 条件缺少目标值": "if requires a comparison value.",
	"if 条件目标值应为整数": "The if comparison value must be an integer.",
	"if 条件末尾缺少冒号": "The if condition must end with a colon.",
	"if 条件冒号后不允许其他内容": "Nothing is allowed after the if condition's colon.",
	"else 末尾缺少冒号": "else must end with a colon.",
	"else 冒号后不允许其他内容": "Nothing is allowed after the else colon.",
	"endif 后不允许其他内容": "Nothing is allowed after endif.",
	"if 条件块缺少 endif": "The if block requires endif.",
	"对话语句后存在多余内容": "Unexpected content after the dialogue statement.",
	"showtextbox 动画时长后存在多余内容": "Unexpected content after the showtextbox duration.",
	"hidetextbox 动画时长后存在多余内容": "Unexpected content after the hidetextbox duration.",
	"waitsignal 信号名称后存在多余内容": "Unexpected content after the waitsignal name.",
	"background 参数后存在多余内容": "Unexpected content after the background arguments.",
	"actor 参数后存在多余内容": "Unexpected content after the actor arguments.",
	"play 参数后存在多余内容": "Unexpected content after the play arguments.",
	"stop bgm 后存在多余内容": "Unexpected content after stop bgm.",
	"cam 参数后存在多余内容": "Unexpected content after the cam arguments.",
	"asyncam 参数后存在多余内容": "Unexpected content after the asyncam arguments.",
	"choice 目标分支后存在多余内容": "Unexpected content after the choice target.",
	"branch 标签后存在多余内容": "Unexpected content after the branch identifier.",
	"jump_branch 目标分支后存在多余内容": "Unexpected content after the jump_branch target.",
	"achievement 参数后存在多余内容": "Unexpected content after the achievement arguments.",
	"end 后存在多余内容": "Unexpected content after end.",
	"showtextbox 动画时长不能为负数": "The showtextbox duration cannot be negative.",
	"hidetextbox 动画时长不能为负数": "The hidetextbox duration cannot be negative.",
	"cam 过渡时长应为数字": "The cam transition duration must be numeric.",
	"cam 震动时长应为数字": "The cam shake duration must be numeric.",
	"asyncam 过渡时长应为数字": "The asyncam transition duration must be numeric.",
	"asyncam 震动时长应为数字": "The asyncam shake duration must be numeric.",
	"镜头过渡时长不能为负数": "The camera transition duration cannot be negative.",
	"镜头震动时长不能为负数": "The camera shake duration cannot be negative.",
	"achievement increment 增量应为整数": "achievement increment requires an integer amount.",
	"achievement set_flag 布尔值应为 true 或 false": "achievement set_flag requires true or false.",
	"jump 缺少目标路径": "jump requires a target script path.",
	"jump 目标必须是 res:// 下的 .ks 文件": "jump requires a .ks file under res://.",
	"jump_branch 缺少目标分支名": "jump_branch requires a target branch.",
	"signal 缺少信号内容": "signal requires a signal name.",
	"achievement 缺少操作类型": "achievement requires an action.",
	"achievement increment 缺少增量数值": "achievement increment requires an amount.",
	"achievement set_flag 缺少布尔值": "achievement set_flag requires a boolean value.",
	"branch 内不能嵌套 branch": "A branch cannot be nested inside another branch.",
	"选项行没有有效的选项": "The choice statement contains no valid option.",
	"信号指令内容为空": "The signal command cannot be empty.",
	"achievement 目标ID为空": "The achievement target ID cannot be empty.",
}

static var _dynamic_rules: Array[Dictionary] = []


static func localize(message: String, locale: String = "") -> String:
	if KS_EditorLocale.is_chinese(locale):
		return message
	if EXACT_ENGLISH.has(message):
		return EXACT_ENGLISH[message]
	_ensure_dynamic_rules()
	for rule: Dictionary in _dynamic_rules:
		var match_result: RegExMatch = (rule["regex"] as RegEx).search(message)
		if match_result == null:
			continue
		var values: Array = []
		for group_index: int in range(1, match_result.get_group_count() + 1):
			values.append(match_result.get_string(group_index))
		return String(rule["template"]) % values
	return "KonadoScript: " + message


static func _ensure_dynamic_rules() -> void:
	if not _dynamic_rules.is_empty():
		return
	_add_rule(
		"^无法识别的语法：(.+)；条件块结束关键字应为 endif$",
		"Unrecognized syntax: %s; a conditional block must end with endif.",
	)
	_add_rule("^无法识别的语法：(.+)$", "Unrecognized syntax: %s.")
	_add_rule("^期望 (.+)，实际为 (.+)$", "Expected %s; got %s.")
	_add_rule("^未知的 actor 操作: (.+)$", "Unknown actor action: %s.")
	_add_rule("^play 后应为 bgm 或 sfx，实际为: (.+)$", "Expected bgm or sfx after play; got %s.")
	_add_rule("^play (.+) 缺少资源名$", "play %s requires a resource name.")
	_add_rule(
		"^未知的 cam 操作: (.+)（应为 move、reset 或 shake）$",
		"Unknown cam action: %s (expected move, reset, or shake).",
	)
	_add_rule(
		"^asyncam 未知操作: (.+)（应为 move、reset、shake 或 stop）$",
		"Unknown asyncam action: %s (expected move, reset, shake, or stop).",
	)
	_add_rule("^if 条件的比较运算符无效: (.+)$", "Invalid if comparison operator: %s.")
	_add_rule("^镜头过渡类型无效：(.+)$", "Invalid camera transition: %s.")
	_add_rule(
		"^(set|add|sub|mul|div) 变量值后存在多余内容$",
		"Unexpected content after the %s value.",
	)
	_add_rule(
		"^(.+) 缺少变量名（格式：(.+) %变量名 值）$",
		"%s requires a variable name (format: %s %%variable value).",
	)
	_add_rule("^(set|add|sub|mul|div) 缺少变量值$", "%s requires a value.")
	_add_rule("^achievement (.+) 缺少目标ID$", "achievement %s requires a target ID.")
	_add_rule("^未知的 achievement 操作: (.+)$", "Unknown achievement action: %s.")
	_add_rule("^branch 标签 '(.+)' 重复$", "Duplicate branch label '%s'.")
	_add_rule(
		"^跳转标签 '(.+)' 不存在（当前可选标签：(.+)）$",
		"Target branch '%s' does not exist (available branches: %s).",
	)
	_add_rule("^jump_branch 目标分支 '(.+)' 未找到$", "Target branch '%s' was not found.")
	_add_rule("^jump 目标剧本 '(.+)' 不存在$", "Target KonadoScript '%s' does not exist.")
	_add_rule("^目标效果 '(.+)' 未找到$", "Background effect '%s' was not found.")
	_add_rule(
		"^角色 '(.+)' 在部分路径上不存在，无法安全(.+)$",
		"Actor '%s' is unavailable on some paths, so it cannot safely perform: %s.",
	)
	_add_rule("^角色 '(.+)' 不存在，无法(.+)$", "Actor '%s' does not exist; cannot perform: %s.")
	var resource_kinds := {
		"角色": "actor",
		"背景": "background",
		"背景音乐": "BGM",
		"音效": "sound effect",
		"语音": "voice",
		"角色状态": "actor state",
		"演员动作": "actor motion",
		"镜头配置": "camera setup",
	}
	for chinese_kind: String in resource_kinds:
		var english_kind := String(resource_kinds[chinese_kind])
		_add_rule(
			"^未找到%s '(.+)'$" % chinese_kind,
			"Unknown %s: '%%s'." % english_kind,
		)
		_add_rule(
			"^%s '(.+)' 存在 (\\d+) 个重复定义$" % chinese_kind,
			"%s '%%s' has %%s duplicate definitions." % english_kind.capitalize(),
		)
		_add_rule(
			"^%s '(.+)' 未配置目标资源$" % chinese_kind,
			"%s '%%s' has no target resource." % english_kind.capitalize(),
		)
		_add_rule(
			"^%s '(.+)' 的目标资源不存在：(.+)$" % chinese_kind,
			"%s '%%s' targets a missing resource: %%s." % english_kind.capitalize(),
		)


static func _add_rule(pattern: String, template: String) -> void:
	var regex := RegEx.new()
	if regex.compile(pattern) == OK:
		_dynamic_rules.append({"regex": regex, "template": template})
