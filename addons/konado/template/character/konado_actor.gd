@tool
extends Control
class_name KND_Actor

## Konado对话角色类，用于在对话中显示角色

## 是否使用补间动画，将会在角色移动时显示动画效果
@export var use_tween: bool = true
## 动画时间，为0时则等于禁用动画效果
@export var animation_time: float = 0.2:
	set(value):
		if animation_time != value:
			animation_time = max(value, 0)

@export var texture_rect: TextureRect

## 屏幕分块数，不得小于2，将屏幕分为从左到右递增的块，每个块大小相同
@export var division: int = 6:
	set(value):
		if division != value:
			division = clamp(value, 2, 15)
			_on_resized()

## 当前角色位置所在区块分割线索引，从0开始，从左到右递增
@export var character_position: int = 3:
	set(value):
		if character_position!= value:
			character_position = clamp(value, 1, division - 1)
			_on_resized()
			
			
func _ready() -> void:
	if not self.resized.is_connected(_on_resized):
		self.resized.connect(_on_resized)
	# 首次正确计算坐标（此时size已由布局系统计算完成）
	_on_resized()

func _on_resized() -> void:
	if not texture_rect:
		print("警告：texture_rect未赋值")
		return
	
	# 恢复你原本的坐标计算公式
	var target_x = -size.x / division * (division - character_position ) + texture_rect.size.x / 2
	
	if use_tween:
		var tween: Tween = texture_rect.create_tween()
		tween.tween_property(texture_rect, "position", Vector2(target_x, texture_rect.position.y), animation_time)
		tween.play()
	else:
		texture_rect.position.x = target_x
	
	print(target_x)

func set_character_texture(texture: Texture) -> void:
	if not texture_rect:
		return
	texture_rect.texture = texture
	_on_resized()

func set_texture_scale(scale: float) -> void:
	if not texture_rect:
		return
	texture_rect.scale = Vector2(scale, scale)
	_on_resized()
