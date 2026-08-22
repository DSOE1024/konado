@tool
extends Control
class_name KonadoActorMotionLayer

## 演员动作层。
## Slot 负责角色站位，MotionLayer 只负责临时舞台动作，例如震动、跳跃、弹一下。

signal motion_started(motion_name: String)
signal motion_finished(motion_name: String)

const ACTOR_FRAMING_LAYER := preload(
	"res://addons/konado/runtime/stage/character/konado_actor_framing_layer.gd"
)

## 播放 AnimationPlayer 中的同名动画，方便用户在编辑器里可视化制作动作。
@export var animation_player: AnimationPlayer
## 临时动作目标。动画只应修改这个节点，避免覆盖持久景别。
@export var motion_node: Node
## 持久景别层。
@export var framing_layer: ACTOR_FRAMING_LAYER
## 角色场景挂载点。
@export var mount_node: Node

var _active_motion_name: String = ""


func _ready() -> void:
	_resolve_nodes()


func _resolve_nodes() -> void:
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if motion_node == null:
		motion_node = get_node_or_null("MotionTransform")
	if framing_layer == null:
		framing_layer = get_node_or_null("MotionTransform/FramingLayer") as ACTOR_FRAMING_LAYER
	if mount_node == null:
		mount_node = get_node_or_null("MotionTransform/FramingLayer/CharacterMount")
	if (
		animation_player
		and not animation_player.animation_finished.is_connected(_on_animation_finished)
	):
		animation_player.animation_finished.connect(_on_animation_finished)


func get_mount_node() -> Node:
	_resolve_nodes()
	if mount_node:
		return mount_node
	return self


func set_framing_profile(profile: KonadoActorFramingProfile) -> bool:
	_resolve_nodes()
	return framing_layer != null and framing_layer.set_profile(profile)


func has_framing(preset_id: StringName) -> bool:
	_resolve_nodes()
	return framing_layer != null and framing_layer.has_preset(preset_id)


func get_framing_ids() -> PackedStringArray:
	_resolve_nodes()
	return framing_layer.get_preset_ids() if framing_layer != null else PackedStringArray()


func get_default_framing_id() -> StringName:
	_resolve_nodes()
	return framing_layer.get_default_preset_id() if framing_layer != null else &"default"


func get_current_framing_id() -> StringName:
	_resolve_nodes()
	return framing_layer.current_preset_id if framing_layer != null else &""


func can_apply_framing(preset_id: StringName, duration: float, transition: String) -> bool:
	_resolve_nodes()
	return framing_layer != null and framing_layer.can_apply(preset_id, duration, transition)


func apply_framing(
	preset_id: StringName,
	duration: float,
	transition: String,
	completion: Callable,
) -> bool:
	_resolve_nodes()
	return (
		framing_layer != null and framing_layer.apply(preset_id, duration, transition, completion)
	)


func restore_framing(preset_id: StringName) -> bool:
	_resolve_nodes()
	return framing_layer != null and framing_layer.apply_immediately(preset_id)


func cancel_framing(reason := "cancelled") -> void:
	_resolve_nodes()
	if framing_layer != null:
		framing_layer.cancel(reason)


func complete_framing(reason := "") -> void:
	_resolve_nodes()
	if framing_layer != null:
		framing_layer.complete(reason)


func settle_framing_to_target(reason := "cancelled") -> void:
	_resolve_nodes()
	if framing_layer != null:
		framing_layer.settle_to_target(reason)


func has_motion(motion_name: String) -> bool:
	_resolve_nodes()
	return (
		not motion_name.is_empty()
		and animation_player != null
		and animation_player.has_animation(motion_name)
	)


func play_motion(motion_name: String, params: Dictionary = {}) -> void:
	_resolve_nodes()
	if motion_name.is_empty():
		motion_finished.emit(motion_name)
		return
	_active_motion_name = motion_name

	if animation_player and animation_player.has_animation(motion_name):
		_reset_motion_target()
		var custom_speed := 1.0
		if params.has("duration"):
			var duration := float(params["duration"])
			if duration <= 0.0:
				motion_started.emit(motion_name)
				_finish_motion(motion_name)
				return
			var animation := animation_player.get_animation(motion_name)
			if animation != null and animation.length > 0.0:
				custom_speed = animation.length / duration
		animation_player.play(motion_name, -1.0, custom_speed)
		animation_player.seek(0, true)
		motion_started.emit(motion_name)
		return

	push_warning("未找到演员动作：%s，可用 AnimationPlayer 动画：%s" % [motion_name, _get_animation_names_text()])
	motion_started.emit(motion_name)
	_finish_motion(motion_name)


func stop_motion() -> void:
	_resolve_nodes()
	if animation_player:
		animation_player.stop()
	_reset_motion_target()
	_active_motion_name = ""


func _finish_motion(motion_name: String) -> void:
	_active_motion_name = ""
	motion_finished.emit(motion_name)


func _on_animation_finished(animation_name: StringName) -> void:
	if str(animation_name) != _active_motion_name:
		return
	_finish_motion(_active_motion_name)


func _reset_motion_target() -> void:
	var target := _get_motion_target()
	target.set("position", Vector2.ZERO)
	target.set("scale", Vector2.ONE)
	target.set("rotation", 0.0)
	if target is CanvasItem:
		var canvas_item := target as CanvasItem
		var modulate := canvas_item.modulate
		modulate.a = 1.0
		canvas_item.modulate = modulate


func _get_motion_target() -> Node:
	var target := motion_node
	if target is Control or target is Node2D:
		return target
	return self


func _get_animation_names_text() -> String:
	if animation_player == null:
		return "未配置 AnimationPlayer"
	var names := PackedStringArray()
	for animation_name in animation_player.get_animation_list():
		names.append(str(animation_name))
	if names.is_empty():
		return "无"
	return ", ".join(names)
