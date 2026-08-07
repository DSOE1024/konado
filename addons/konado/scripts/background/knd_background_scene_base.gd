@tool
extends Control
class_name KND_BackgroundSceneBase

## 背景场景基类。
## 背景切换时，系统只调用 enter/exit；具体是图片、视频、Spine、Live2D 或 shader，由场景内部决定。
## 内置的双纹理背景转场 shader 由 KND_BackgroundTransitionLayer 统一处理；
## 这里更适合放背景自己的入场、退场、循环表现和自定义 effect 动画。

signal background_enter_finished
signal background_exit_finished

## 可选动画播放器。存在 enter_<effect> 或 exit_<effect> 动画时优先播放。
@export var animation_player: AnimationPlayer
## 当没有对应动画时，非 none 效果默认用淡入淡出兜底，避免剧情卡住。
@export var use_default_fade: bool = true
@export var default_transition_duration: float = 0.35

## 场景独立的染色加权系数（1.0 为默认，0 彻底无染色），没有特殊需求不用调整
@export var scene_tint_intensity: float = 1.0:
	set(value):
		scene_tint_intensity = clamp(value, 0.0, 2.0)

## 当无法从纹理中提取色调时，使用的默认环境色
@export var default_env_color: Color = Color.WHITE

var _transition_tween: Tween
var _active_animation: StringName = &""
var _active_phase: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if (
		animation_player
		and not animation_player.animation_finished.is_connected(_on_animation_finished)
	):
		animation_player.animation_finished.connect(_on_animation_finished)


func setup_background(_background_name: String, _params: Dictionary = {}) -> void:
	pass


## 给系统内置 shader 转场使用的静态纹理。
## 图片背景默认会递归寻找第一个 TextureRect / Sprite2D；视频、Live2D、Spine 等动态场景可保持为空，
## 交给 KND_BackgroundTransitionLayer 使用 SubViewport 渲染。
## 注意：这里返回的是原始纹理资源，不包含 modulate、材质 shader 等场景内的表现。
func get_transition_texture() -> Texture2D:
	return _find_transition_texture(self)


## 系统内置 shader 转场是否必须整场景渲染（SubViewport 捕获）。
## 静态纹理快速通道成立的前提是「整个场景在视觉上等价于那张原始纹理」。
## 一旦场景里存在 modulate / self_modulate 染色、材质 shader、多个可绘制节点、
## 自动播放的动画等，就必须走 SubViewport，否则这些表现会在转场期间整体丢失。
func requires_viewport_capture() -> bool:
	var state := {"drawables": 0, "capture": false}
	_collect_capture_state(self, true, state)
	if bool(state["capture"]):
		return true
	return int(state["drawables"]) > 1


func _collect_capture_state(node: Node, is_root: bool, state: Dictionary) -> void:
	if bool(state["capture"]):
		return

	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		# 不可见分支不参与最终画面，整棵子树直接跳过。
		if not canvas_item.visible:
			return
		# 命中任一"必须走 SubViewport"的条件即标记 capture，
		# 用 elif 链收敛出口，避免在每个分支里各 return 一次。
		if canvas_item.material != null:
			state["capture"] = true
		elif canvas_item.self_modulate != Color.WHITE:
			state["capture"] = true
		# 根节点的 modulate 由转场层统一接管，只检查子节点上的染色。
		elif not is_root and canvas_item.modulate != Color.WHITE:
			state["capture"] = true
		elif canvas_item is TextureRect:
			var texture_rect := canvas_item as TextureRect
			if (
				texture_rect.stretch_mode != TextureRect.STRETCH_SCALE
				or texture_rect.flip_h
				or texture_rect.flip_v
			):
				state["capture"] = true
			elif texture_rect.texture:
				state["drawables"] += 1
		elif canvas_item is Sprite2D:
			if (canvas_item as Sprite2D).texture:
				state["drawables"] += 1
		elif canvas_item is ColorRect or canvas_item is NinePatchRect:
			state["drawables"] += 1
		elif canvas_item is AnimatedSprite2D or canvas_item is VideoStreamPlayer:
			state["capture"] = true
	elif node is AnimationPlayer:
		var player := node as AnimationPlayer
		# shader 转场期间不会调用 play_enter / play_exit，
		# 只有自动播放或已在播放的动画才会让画面持续变化。
		if player.is_playing() or not player.autoplay.is_empty():
			state["capture"] = true
	elif node is AnimationTree:
		if (node as AnimationTree).active:
			state["capture"] = true

	# 一旦命中 capture，当前节点不再下探子节点（与原有提前 return 等价）。
	if bool(state["capture"]):
		return

	for child in node.get_children():
		_collect_capture_state(child, false, state)
		if bool(state["capture"]):
			return


func play_enter(effect_name: String = "none", params: Dictionary = {}) -> void:
	_play_transition("enter", effect_name, params)


func play_exit(effect_name: String = "none", params: Dictionary = {}) -> void:
	_play_transition("exit", effect_name, params)


func stop_background_transition() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	if animation_player:
		animation_player.stop()
	_active_animation = &""
	_active_phase = ""


func _play_transition(phase: String, effect_name: String, _params: Dictionary) -> void:
	stop_background_transition()
	_active_phase = phase
	if _play_animation_for_phase(phase, effect_name):
		return
	if use_default_fade and effect_name != "none":
		_play_default_fade(phase)
		return
	_finish_transition(phase)


func _play_animation_for_phase(phase: String, effect_name: String) -> bool:
	if animation_player == null:
		return false
	var candidates := PackedStringArray()
	if not effect_name.is_empty():
		candidates.append("%s_%s" % [phase, effect_name])
	candidates.append(phase)
	for animation_name in candidates:
		if animation_player.has_animation(animation_name):
			_active_animation = StringName(animation_name)
			animation_player.play(animation_name)
			return true
	return false


func _play_default_fade(phase: String) -> void:
	var from_alpha := 0.0 if phase == "enter" else modulate.a
	var to_alpha := 1.0 if phase == "enter" else 0.0
	modulate.a = from_alpha
	_transition_tween = create_tween()
	_transition_tween.tween_property(self, "modulate:a", to_alpha, default_transition_duration)
	_transition_tween.finished.connect(_finish_transition.bind(phase))


func _finish_transition(phase: String) -> void:
	_transition_tween = null
	_active_animation = &""
	_active_phase = ""
	if phase == "enter":
		background_enter_finished.emit()
	else:
		background_exit_finished.emit()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != _active_animation:
		return
	_finish_transition(_active_phase)


func _find_transition_texture(node: Node) -> Texture2D:
	if node is TextureRect:
		var texture_rect := node as TextureRect
		if texture_rect.texture:
			return texture_rect.texture
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture:
			return sprite.texture
	for child in node.get_children():
		var texture := _find_transition_texture(child)
		if texture:
			return texture
	return null


## 返回当前背景场景的代表色（环境光颜色）
func get_scene_tint_color() -> Color:
	var tex = get_transition_texture()
	if tex == null:
		return default_env_color
	return _calculate_average_color(tex)


## 从 Texture2D 中计算全图平均色
func _calculate_average_color(texture: Texture2D) -> Color:
	var img = texture.get_image()
	if img == null or img.is_empty():
		return Color.WHITE
	# 缩小到 1x1 线性插值，直接得到平均色
	img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	return img.get_pixel(0, 0)
