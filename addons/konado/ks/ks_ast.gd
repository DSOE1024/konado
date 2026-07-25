extends RefCounted
class_name KS_AST

## KS 抽象语法树（AST）节点定义
## 所有 AST 节点类型均为内部类


## 基础节点
class ASTNode extends RefCounted:
	var line: int = 0  ## 源代码行号


## 脚本根节点 —— 代表一个完整的 ks 文件
class ScriptNode extends ASTNode:
	var statements: Array = []  ## Array[ASTNode]


## 普通对话节点
class DialogueNode extends ASTNode:
	var character_id: String = ""
	var content: String = ""
	var voice_id: String = ""


## 背景切换节点
class BackgroundNode extends ASTNode:
	var background_name: String = ""
	var effect: String = ""


## 演员操作节点
class ActorNode extends ASTNode:
	var action: String = ""         ## "show", "exit", "change", "move", "motion"
	var actor_name: String = ""
	var state: String = ""
	var motion_name: String = ""
	var position: float = 0.0
	var has_position: bool = false


## 音频操作节点
class AudioNode extends ASTNode:
	var action: String = ""         ## "play" 或 "stop"
	var target: String = ""         ## "bgm" 或 "sfx"
	var resource_name: String = ""


## 镜头操作节点
class CameraNode extends ASTNode:
	var action: String = ""         ## "move"、"reset" 或 "shake"
	var target_cam: String = ""     ## move 操作的目标镜头名
	var tween_type: String = ""     ## tween 动画类型，none 表示无动画
	var tween_time: float = 0.0     ## tween 动画时间
	var shake_time: float = 0.0     ## shake 晃动持续时间


## 选项条目
class ChoiceOption extends RefCounted:
	var text: String = ""
	var branch_target: String = ""


## 选项组节点（合并的连续 choice 行）
class ChoiceGroupNode extends ASTNode:
	var options: Array = []  ## Array[ChoiceOption]


## 分支节点
class BranchNode extends ASTNode:
	var branch_id: String = ""
	var body: Array = []  ## Array[ASTNode]


## 条件分支节点
class IfElseNode extends ASTNode:
	var var_prefix: String = ""     ## "%" 或 "$"
	var var_name: String = ""
	var op: String = ""             ## "==", "!=", ">", "<", ">=", "<="
	var target_value: int = 0
	var if_body: Array = []         ## Array[ASTNode]
	var else_body: Array = []       ## Array[ASTNode]


## 变量操作节点
class VariableNode extends ASTNode:
	var operation: String = ""      ## "set", "add", "sub", "mul", "div"
	var var_prefix: String = ""     ## "%" 或 "$"
	var var_name: String = ""
	var operand: String = ""


## 跳转镜头节点
class JumpNode extends ASTNode:
	var target_path: String = ""


## 跳转分支节点
class JumpBranchNode extends ASTNode:
	var target_branch: String = ""


## 自定义信号节点
class SignalNode extends ASTNode:
	var signal_content: String = ""


## 成就操作节点
class AchievementNode extends ASTNode:
	var action: String = ""         ## "unlock", "increment", "set_flag"
	var target_id: String = ""
	var increment_value: int = 0
	var flag_value: bool = false


## 结束节点
class EndNode extends ASTNode:
	pass


## NVL 屏幕文本节点（Overlay 正文）
class ScreenTextNode extends ASTNode:
	var lines: Array[String] = []    ## 文本行列表

## 显示对话框节点
class ShowTextBoxNode extends ASTNode:
	var duration: float = 0.0         ## 淡入动画时长（秒），0.0 表示禁用动画

## 隐藏对话框节点
class HideTextBoxNode extends ASTNode:
	var duration: float = 0.0         ## 淡出动画时长（秒），0.0 表示禁用动画
