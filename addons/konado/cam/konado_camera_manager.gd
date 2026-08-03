@tool
extends Node
class_name KonadoCameraManager

## Konado相机管理器

@export var current: Camera2D

@export var bg_container: Node

@export var cameras: Array[KonadoCamera2D] = []

var tween: Tween

## 异步相机 Tween 追踪列表（用于 asyncam stop 强制终止）
var _async_tweens: Array[Tween] = []
## 异步相机最终目标位置（用于 asyncam stop 瞬间定格）
var _async_target_pos: Vector2 = Vector2.ZERO
## 异步相机最终目标缩放
var _async_target_zoom: Vector2 = Vector2.ONE
## 晃动开始前的用户相机偏移，取消或完成后必须恢复。
var _shake_base_offset: Vector2 = Vector2.ZERO
var _shake_tweens: Array[Tween] = []


func _ready() -> void:
	current.position = get_window().size / 2


## 递归获取指定节点下所有 KonadoCamera2D 节点列表
func get_all_konado_cameras() -> void:
	cameras = []
	_traverse(bg_container, cameras)


## 递归遍历辅助函数
func _traverse(node: Node, out_list: Array[KonadoCamera2D]) -> void:
	for child in node.get_children():
		if child is KonadoCamera2D:
			out_list.append(child)
		_traverse(child, out_list)


func move_cam(
	cam_name: String,
	time: float,
	callback: Callable = Callable(),
	transition_type: String = "linear",
) -> void:
	for cam in cameras:
		if cam.camera_setup == cam_name:
			camera_trans(cam, time, callback, transition_type)
			return
	if callback.is_valid():
		callback.call()


func camera_trans(
	next_cam: Camera2D,
	ft: float = 2.0,
	callback: Callable = Callable(),
	transition_type: String = "linear",
) -> void:
	_cancel_pending_shakes()
	if tween:
		tween.kill()
	tween = create_tween()
	_apply_transition(tween, transition_type)
	tween.set_parallel(true)
	tween.tween_property(current, "position", next_cam.position, ft)
	tween.tween_property(current, "zoom", next_cam.zoom, ft)
	tween.set_parallel(false)
	tween.tween_callback(callback)


func reset_cam(
	use_tween: bool,
	ft: float = 2.0,
	callback: Callable = Callable(),
	transition_type: String = "linear",
) -> void:
	var pos: Vector2 = get_window().size / 2
	_cancel_pending_shakes()
	if use_tween:
		if tween:
			tween.kill()
		tween = create_tween()
		_apply_transition(tween, transition_type)
		tween.set_parallel(true)
		tween.tween_property(current, "position", pos, ft)
		tween.tween_property(current, "zoom", Vector2(1.0, 1.0), ft)
		tween.set_parallel(false)
		tween.tween_callback(callback)
	else:
		current.position = pos
		current.zoom = Vector2(1.0, 1.0)
		if callback.is_valid():
			callback.call()


func shake_cam(duration: float, callback: Callable = Callable()) -> void:
	if duration <= 0:
		if callback.is_valid():
			callback.call()
		return

	_cancel_pending_shakes()
	if tween:
		tween.kill()

	_shake_base_offset = current.offset
	tween = create_tween()
	var shake_tween := tween
	_shake_tweens.append(shake_tween)
	tween.tween_method(Callable(self, "_apply_shake"), 0.0, 1.0, duration)
	tween.tween_callback(_complete_shake.bind(shake_tween, callback))


# ============================================================
# 异步相机操作（不阻塞对话）
# ============================================================


## 异步移动镜头到目标机位，不阻塞对话；返回后 Tween 在后台运行
func async_move_cam(cam_name: String, time: float, transition_type: String = "linear") -> void:
	for cam in cameras:
		if cam.camera_setup == cam_name:
			_async_target_pos = cam.position
			_async_target_zoom = cam.zoom
			_start_async_tween(cam.position, cam.zoom, time, transition_type)
			return


## 异步重置镜头到默认位置，不阻塞对话
func async_reset_cam(time: float, transition_type: String = "linear") -> void:
	_async_target_pos = get_window().size / 2
	_async_target_zoom = Vector2.ONE
	_start_async_tween(_async_target_pos, _async_target_zoom, time, transition_type)


## 异步镜头晃动，不阻塞对话
func async_shake_cam(duration: float) -> void:
	if duration <= 0:
		return

	_cancel_pending_shakes()
	_shake_base_offset = current.offset
	var shake_tween := create_tween()
	_shake_tweens.append(shake_tween)
	shake_tween.tween_method(Callable(self, "_apply_shake"), 0.0, 1.0, duration)
	shake_tween.tween_callback(_complete_shake.bind(shake_tween, Callable()))
	_async_tweens.append(shake_tween)
	# 将初始偏移也记录为最终目标，以便 stop 时恢复
	_async_target_pos = current.position
	_async_target_zoom = current.zoom


## 强制终止所有异步相机 Tween，瞬间定格到最终目标位置
func async_stop_all() -> void:
	_cancel_pending_shakes()
	for t in _async_tweens:
		if t and t.is_valid():
			t.kill()
	_async_tweens.clear()
	# 瞬间定格到最终目标
	current.position = _async_target_pos
	current.zoom = _async_target_zoom


## 取消当前镜头遗留的同步与异步动画，但保持已经到达的位置和缩放。
func cancel_pending_operations() -> void:
	_cancel_pending_shakes()
	if tween and tween.is_valid():
		tween.kill()
	tween = null
	for pending_tween in _async_tweens:
		if pending_tween and pending_tween.is_valid():
			pending_tween.kill()
	_async_tweens.clear()


func _complete_shake(shake_tween: Tween, callback: Callable) -> void:
	_shake_tweens.erase(shake_tween)
	_async_tweens.erase(shake_tween)
	if tween == shake_tween:
		tween = null
	if current and _shake_tweens.is_empty():
		current.offset = _shake_base_offset
	if callback.is_valid():
		callback.call()


func _cancel_pending_shakes() -> void:
	if _shake_tweens.is_empty():
		return
	for shake_tween in _shake_tweens:
		if shake_tween and shake_tween.is_valid():
			shake_tween.kill()
		_async_tweens.erase(shake_tween)
		if tween == shake_tween:
			tween = null
	_shake_tweens.clear()
	if current:
		current.offset = _shake_base_offset


## 启动异步 Tween（无回调，不阻塞）
func _start_async_tween(
	target_pos: Vector2,
	target_zoom: Vector2,
	ft: float,
	transition_type: String,
) -> void:
	var async_tween := create_tween()
	_apply_transition(async_tween, transition_type)
	async_tween.set_parallel(true)
	async_tween.tween_property(current, "position", target_pos, ft)
	async_tween.tween_property(current, "zoom", target_zoom, ft)
	async_tween.set_parallel(false)
	# Tween 完成后自动从追踪列表移除
	async_tween.finished.connect(func(): _async_tweens.erase(async_tween))
	_async_tweens.append(async_tween)


func _apply_transition(target_tween: Tween, transition_type: String) -> void:
	if transition_type == "ease_in_out":
		target_tween.set_trans(Tween.TRANS_SINE)
		target_tween.set_ease(Tween.EASE_IN_OUT)
	else:
		target_tween.set_trans(Tween.TRANS_LINEAR)
		target_tween.set_ease(Tween.EASE_IN_OUT)


func _apply_shake(progress: float) -> void:
	var shake_intensity := (1.0 - progress) * 65.0

	var time := Time.get_ticks_msec() / 1000.0
	var offset_x := (
		(sin(time * 20.0) * 0.5 + sin(time * 37.0) * 0.3 + sin(time * 67.0) * 0.2) * shake_intensity
	)
	var offset_y := (
		(cos(time * 17.0) * 0.5 + cos(time * 31.0) * 0.3 + cos(time * 59.0) * 0.2) * shake_intensity
	)

	current.offset = _shake_base_offset + Vector2(offset_x, offset_y)
