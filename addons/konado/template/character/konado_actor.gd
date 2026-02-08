extends Control
class_name KND_Actor

## Konado对话角色类，用于在对话中显示角色

## 角色进场动画完成信号
signal actor_entered
## 角色退场动画完成信号
signal actor_exited

## 是否使用补间动画，将会在角色移动时显示动画效果
@export var use_tween: bool = true
## 动画时间，为0时则等于禁用动画效果
@export var animation_time: float = 0.2:
	set(value):
		if animation_time != value:
			animation_time = max(value, 0)

@export var texture_rect: TextureRect

## 屏幕横向分块数，不得小于2，将屏幕宽度分为从左到右递增的块，每个块大小相同
@export var division: int = 6:
	set(value):
		if division != value:
			division = clamp(value, 2, 15)
			_on_resized()

## 当前角色横向位置所在区块分割线索引，从0开始，从左到右递增
@export var character_position: int = 3:
	set(value):
		if character_position != value:
			character_position = clamp(value, 1, division - 1)
			_on_resized()

## 屏幕纵向分块数，不得小于3，将屏幕高度分为从上到下递增的块，每个块大小相同
@export var y_division: int = 3:
	set(value):
		if y_division != value:
			y_division = clamp(value, 3, 6)
			_on_resized()

## 当前角色纵向位置所在区块分割线索引，从0开始，从上到下递增
## 数值越小越偏上，数值越大越偏下
@export var character_y_position: int = 2:
	set(value):
		if character_y_position != value:
			character_y_position = clamp(value, 1, y_division - 1)
			_on_resized()
		
## 设置镜像	
@export var mirror: bool = false:
	set(value):
		if mirror != value:
			mirror = value
			set_texture_mirror()

func _ready() -> void:
	if not self.resized.is_connected(_on_resized):
		self.resized.connect(_on_resized)
	# 首次正确计算坐标（此时size已由布局系统计算完成）
	_on_resized()
	# 初始化透明度为1（确保初始状态正常）
	if texture_rect:
		texture_rect.modulate.a = 1.0
		texture_rect.visible = true

func _on_resized() -> void:
	if not texture_rect:
		print("警告：texture_rect未赋值")
		return
		
	var target_x = -size.x / division * (division - character_position) + texture_rect.size.x / 2
	var target_y = -size.y / y_division * (y_division - character_y_position) + texture_rect.size.y / 2
	
	if use_tween:
		var tween: Tween = texture_rect.create_tween()
		tween.tween_property(texture_rect, "position", Vector2(target_x, target_y), animation_time)
		tween.play()
	else:
		texture_rect.position.x = target_x
		texture_rect.position.y = target_y

## 角色进场动画（透明度从0过渡到1）
func enter_actor(play_anim: bool = true) -> void:
	if not texture_rect:
		print("警告：texture_rect未赋值，无法执行进场动画")
		emit_signal("actor_entered")
		return
	
	# 重置基础状态
	texture_rect.visible = true
	texture_rect.modulate.a = 0.0
	
	# 创建补间动画
	var tween: Tween = texture_rect.create_tween()
	# 并行执行多个动画轨道
	tween.set_parallel(true)
	
	# 透明度动画（核心进场效果）
	tween.tween_property(texture_rect, "modulate:a", 1.0, animation_time)
	
	# 如果需要同时播放位置动画，先计算目标位置并添加到动画
	if play_anim:
		var target_x = -size.x / division * (division - character_position) + texture_rect.size.x / 2
		var target_y = -size.y / y_division * (y_division - character_y_position) + texture_rect.size.y / 2
		tween.tween_property(texture_rect, "position", Vector2(target_x, target_y), animation_time)
	
	# 动画完成后触发信号
	tween.finished.connect(_on_enter_animation_finished)
	tween.play()

## 角色退场动画（透明度从1过渡到0）
func exit_actor(play_anim: bool = true) -> void:
	if not texture_rect:
		print("警告：texture_rect未赋值，无法执行退场动画")
		emit_signal("actor_exited")
		return
	
	# 创建补间动画
	var tween: Tween = texture_rect.create_tween()
	# 透明度淡出动画
	tween.tween_property(texture_rect, "modulate:a", 0.0, animation_time)
	
	# 动画完成后删除节点
	tween.finished.connect(func(): self.queue_free())
	tween.play()

## 进场动画完成回调
func _on_enter_animation_finished() -> void:
	actor_entered.emit()

func set_character_texture(texture: Texture) -> void:
	if not texture_rect:
		return
	if texture == null:
		push_error("正在试图设置一个空角色图像")
	texture_rect.texture = texture
	_on_resized()

func set_texture_scale(scale: float) -> void:
	if not texture_rect:
		return
	texture_rect.scale = Vector2(scale, scale)
	_on_resized()
	
func set_texture_mirror() -> void:
	if not texture_rect:
		return
	texture_rect.flip_h = mirror
