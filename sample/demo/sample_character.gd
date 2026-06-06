extends KND_CharacterSceneBase

## 这个 demo 只演示 AnimatedSprite2D 的实现方式。
## 换成 Spine、Live2D 或视频时，保留基类入口，替换 _apply_status 内部逻辑即可。

## 导出 NodePath 是为了让用户复制模板后，可以在编辑器里换成自己的显示节点。
@export var animated_sprite_path: NodePath = ^"AnimatedSprite2D"

var sprite: AnimatedSprite2D

func _ready() -> void:
	sprite = get_node_or_null(animated_sprite_path) as AnimatedSprite2D

## 对 AnimatedSprite2D 来说，状态名最终落到同名动画。
## 其他媒体类型可以把这里改成播放 Spine 动画、设置 Live2D 表情或切换视频流。
func _apply_status(resolved_status_name: String, original_status_name: String) -> void:
	var sprite_node := _get_sprite()
	if sprite_node == null or sprite_node.sprite_frames == null:
		push_warning("角色场景缺少 AnimatedSprite2D 或 SpriteFrames")
		return

	var animation_name := StringName(resolved_status_name)
	if sprite_node.sprite_frames.has_animation(animation_name):
		sprite_node.play(animation_name)
		return

	push_warning("角色场景未找到动画：" + original_status_name)

## demo 里先把动作当作一次性状态播放。
## 后续如果接入真正的 actor action，可以在这里做不改变 current_status 的短动画。
func _play_action(action_name: String) -> void:
	apply_status(action_name)
	finish_action(action_name)

func _get_sprite() -> AnimatedSprite2D:
	if sprite == null:
		sprite = get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	return sprite
