extends Node
class_name DialogueInterface
# 对话UI控制脚本

## 对话选项按钮容器
@onready var _choice_container: Container = $ChoicesContainer
@onready var _dialog_manager: KND_DialogueManager = $"../.."

## 完成打字的信号
signal finish_typing
## 完成创建选项的信号
signal finish_display_options



## 初始化对话框
func init_dialog_box() -> void:
	distroy_options()




func distroy_options() -> void:
	# 隐藏选项容器
	_choice_container.hide()
	# 删除原有选项
	if _choice_container.get_child_count() != 0:
		for child in _choice_container.get_children():
			child.queue_free()

## 显示对话选项的方法
func display_options(choices: Array[DialogueChoice], choices_font_size: int = 40) -> void:
	distroy_options()
	# 生成新选项
	for choice in choices:
		var choiceButton: Button = Button.new()
		# 选项文本内容
		choiceButton.set_text(choice.choice_text)
		choiceButton.add_theme_font_size_override("font_size", int(choices_font_size))
		# 选项触发
		choiceButton.button_up.connect(
			func():
				await get_tree().create_timer(0.001).timeout
				print_rich("[color=green]选项被触发: [/color]"+str(choice))
				_dialog_manager.on_option_triggered(choice)
				choiceButton.set_disabled(true)
				)
		# 添加到选项容器
		_choice_container.add_child(choiceButton)
		print_rich("[color=cyan]生成选项按钮: [/color]"+str(choiceButton))
	# 显示选项容器
	_choice_container.show()
