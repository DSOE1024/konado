@tool
extends Control
class_name KND_Actor

## Konado对话角色类，用于在对话中显示角色

## 演员进场动画完成信号
signal actor_entered
## 演员退场动画完成信号
signal actor_exited
## 演员移动动画完成信号
signal actor_moved

## 是否使用补间动画，将会在角色移动时显示动画效果
@export var use_tween: bool = true

## 动画时间，为0时则等于禁用动画效果
@export var animation_time: float = 0.2:
	set(value):
		if animation_time != value:
			animation_time = max(value, 0)

@export var texture_rect: TextureRect
var _status_node: Node = null

## 屏幕横向分块数，不得小于2，将屏幕宽度分为从左到右递增的块，每个块大小相同
@export var h_division: int = 5:
	set(value):
		if h_division != value:
			h_division = clamp(value, 2, 5)
			_on_resized()

## 当前角色横向位置所在区块分割线索引，从0开始，从左到右递增
@export var h_character_position: int = 3:
	set(value):
		if h_character_position != value:
			h_character_position = clamp(value, 0, h_division)
			_on_resized()

func _ready() -> void:
	# 初始化透明度为1（确保初始状态正常）
	if texture_rect:
		texture_rect.modulate.a = 1.0
		texture_rect.visible = true
	# 初始化位置
	_on_resized()

func _on_resized() -> void:
	if not slot:
		print("警告：slot未赋值")
		return
	
	if use_tween:
		var tween: Tween = slot.create_tween()
		tween.set_parallel(true)
		tween.tween_property(slot, "position:x", -size.x / h_division * (h_division - h_character_position ) + slot.size.x/2, animation_time)
		await tween.finished
		_layout_status_node()
		actor_moved.emit()
	else:
		slot.position.x = -size.x / h_division * (h_division - h_character_position ) + slot.size.x/2
	
		_layout_status_node()
		actor_moved.emit()

## 高亮
func set_highlight(highlight: bool) -> void:
	if _status_node and _status_node.has_method("set_highlight"):
		_status_node.call("set_highlight", highlight)
		return
	var visual := _get_status_visual()
	if visual == null:
		return
	if highlight:
		visual.set_modulate(Color(1.0, 1.0, 1.0))
	else:
		visual.set_modulate(Color(0.35, 0.35, 0.35, 1.0))
	pass

## 角色进场动画（透明度从0过渡到1）
func enter_actor(play_anim: bool = true) -> void:
	var visual := _get_status_visual()
	if visual == null:
		print("警告：角色状态节点未赋值，无法执行进场动画")
		emit_signal("actor_entered")
		return
	
	# 重置基础状态
	visual.visible = true
	visual.modulate.a = 0.0
	
	# 创建补间动画
	var tween: Tween = visual.create_tween()
	# 并行执行多个动画轨道
	tween.set_parallel(true)
	
	# 透明度动画（核心进场效果）
	tween.tween_property(visual, "modulate:a", 1.0, animation_time)
	
	tween.finished.connect(_on_enter_animation_finished)
	tween.play()

## 角色退场动画（透明度从1过渡到0）
func exit_actor(play_anim: bool = true) -> void:
	var visual := _get_status_visual()
	if visual == null:
		print("警告：角色状态节点未赋值，无法执行退场动画")
		emit_signal("actor_exited")
		return
	
	# 创建补间动画
	var tween: Tween = visual.create_tween()
	# 透明度淡出动画
	tween.tween_property(visual, "modulate:a", 0.0, animation_time)
	
	# 动画完成后删除节点
	tween.finished.connect(func(): self.queue_free())
	tween.play()

## 进场动画完成回调
func _on_enter_animation_finished() -> void:
	actor_entered.emit()

func set_character_scene(scene: PackedScene, initial_status: String = "") -> void:
	_clear_status_node()
	if not slot:
		return
	if scene == null:
		push_error("正在试图设置一个空角色场景")
		return
	if texture_rect:
		texture_rect.texture = null
		texture_rect.visible = false
	var instance := scene.instantiate()
	_status_node = instance
	slot.add_child(instance)
	_layout_status_node()
	if instance is CanvasItem:
		instance.visible = true
	if not initial_status.is_empty():
		apply_character_status(initial_status)

## 演员节点只负责把剧本里的状态名转发给角色场景。
## 这里不判断图片、Spine、Live2D 或视频，避免主链路重新绑定到某一种媒体类型。
func apply_character_status(status_name: String) -> void:
	if status_name.is_empty():
		return
	if _status_node == null:
		push_error("角色场景节点未创建，无法切换状态：" + status_name)
		return
	# 优先使用正式协议；后面的 has_method 分支用于兼容未继承基类的用户场景。
	if _status_node is KND_CharacterSceneBase:
		(_status_node as KND_CharacterSceneBase).apply_status(status_name)
		return
	elif _status_node.has_method("apply_status"):
		_status_node.call("apply_status", status_name)
		return
	if _status_node.has_method("change_status"):
		_status_node.call("change_status", status_name)
		return
	if _status_node.has_method("set_status"):
		_status_node.call("set_status", status_name)
		return
	push_warning("角色场景未实现 apply_status：" + status_name)

## 动作入口预留给后续“立绘动作”命令，例如震动、挥手、播放一次性动画。
## 持续状态和一次性动作分开，避免播放动作时破坏当前表情或待机状态。
func play_character_action(action_name: String) -> void:
	if action_name.is_empty():
		return
	if _status_node == null:
		push_error("角色场景节点未创建，无法播放动作：" + action_name)
		return
	# 仍然保留 apply_action 兼容入口，方便用户用自己的场景脚本先接入。
	if _status_node is KND_CharacterSceneBase:
		(_status_node as KND_CharacterSceneBase).play_action(action_name)
		return
	elif _status_node.has_method("play_action"):
		_status_node.call("play_action", action_name)
		return
	elif _status_node.has_method("apply_action"):
		_status_node.call("apply_action", action_name)
		return
	push_warning("角色场景未实现 play_action：" + action_name)

func set_character_texture(texture: Texture) -> void:
	_clear_status_node()
	if not texture_rect:
		return
	if texture == null:
		push_error("正在试图设置一个空角色图像")
	texture_rect.visible = true
	texture_rect.texture = texture

func _clear_status_node() -> void:
	if _status_node and is_instance_valid(_status_node):
		_status_node.queue_free()
	_status_node = null

func _layout_status_node() -> void:
	if _status_node == null or not slot:
		return
	# Control 场景适合铺满角色槽；Node2D 场景适合以槽中心作为立绘锚点。
	# 具体缩放和内部偏移仍由角色场景自己控制。
	if _status_node is Control:
		var control := _status_node as Control
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elif _status_node is Node2D:
		var node_2d := _status_node as Node2D
		node_2d.position = slot.size * 0.5

func _get_status_visual() -> CanvasItem:
	if _status_node:
		if _status_node is CanvasItem:
			return _status_node as CanvasItem
		var canvas_item := _find_canvas_item(_status_node)
		if canvas_item:
			return canvas_item
	if texture_rect:
		return texture_rect
	return null

func _find_canvas_item(node: Node) -> CanvasItem:
	for child in node.get_children():
		if child is CanvasItem:
			return child as CanvasItem
		var nested := _find_canvas_item(child)
		if nested:
			return nested
	return null

@export var slot: Control


			
#@tool
#extends Control
#
#@onready var control: Control = $Slot
#
#@export var division:= 3:
	#set(value):
		#if division != value:
			#division = clamp(value,2,15)
			#_on_resized()
#
#@export var character_position := 2:
	#set(value):
		#if character_position!= value:
			#character_position = clamp(value,0,division)
			#_on_resized()
			#
#
#func _on_resized() -> void:
	#if control:
		#control.position.x = -size.x /division * (division - character_position )+ control.size.x/2
