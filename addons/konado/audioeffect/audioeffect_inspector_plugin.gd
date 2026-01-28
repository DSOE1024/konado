@tool
extends EditorInspectorPlugin

# 预加载自定义的EditorProperty下拉控件
var AudioDropdownEditor = preload("res://addons/konado/audioeffect/audioeffect_dropdown_editor.gd")

# 仅处理KND_DialogueBox类
func _can_handle(object: Object) -> bool:
	return object is KND_DialogueBox

# 官方重写方法：解析对象属性 → 仅替换typing_effect_audio的编辑器
func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags,
	wide: bool
) -> bool:
	# 仅处理typing_effect_audio属性
	if name == "typing_effect_audio":
		# 创建自定义EditorProperty控件实例，添加到检查器
		add_property_editor(name, AudioDropdownEditor.new("typewriter"))
		# 返回true移除Godot内置的资源选择器，仅显示自定义下拉
		return true
	# 其他属性使用官方默认编辑器
	return false
