@tool
extends Node

## 管理剧情镜头的定位、缩放、晃动与快照恢复。

@export var active_camera: Camera2D

@export var marker_root: Node

@export var camera_markers: Array[KonadoCameraMarker] = []

var _active_tween: Tween

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
	if active_camera == null:
		push_error("KonadoCameraController.active_camera must reference a Camera2D")
		return
	active_camera.position = get_window().size / 2


## 递归获取指定节点下所有 KonadoCameraMarker 节点列表
func refresh_camera_markers() -> void:
	camera_markers = []
	_collect_camera_markers(marker_root, camera_markers)


## 递归遍历辅助函数
func _collect_camera_markers(node: Node, output: Array[KonadoCameraMarker]) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is KonadoCameraMarker:
			output.append(child)
		_collect_camera_markers(child, output)


func move_to_marker(
	marker_id: String,
	duration: float,
	callback: Callable = Callable(),
	transition_type: String = "linear",
) -> bool:
	if active_camera == null:
		push_error(
			"Konado: camera.move 失败：active_camera 未配置（请在 KonadoCameraController 中指定 Camera2D）"
		)
		return false
	if duration < 0.0:
		push_error("Konado: camera.move 失败：duration 不能为负数（%f）" % duration)
		return false
	if camera_markers.is_empty():
		push_error("Konado: camera.move 失败：camera_markers 为空，未找到机位 '%s'。" % marker_id)
		return false
	for marker in camera_markers:
		if is_instance_valid(marker) and marker.marker_id == marker_id:
			_transition_to_marker(marker, duration, callback, transition_type)
			return true
	var known: String = ", ".join(camera_markers.map(
		func(m): 
			return m.marker_id if is_instance_valid(m) else "<invalid>")
		)
	push_error("Konado: camera.move 失败：未注册机位 '%s'。已注册的机位：%s" % [marker_id, known])
	return false


func _transition_to_marker(
	next_marker: Camera2D,
	duration: float = 2.0,
	callback: Callable = Callable(),
	transition_type: String = "linear",
) -> void:
	_cancel_pending_shakes()
	if _active_tween:
		_active_tween.kill()
	_active_tween = create_tween()
	_apply_transition(_active_tween, transition_type)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(active_camera, "position", next_marker.position, duration)
	_active_tween.tween_property(active_camera, "zoom", next_marker.zoom, duration)
	_active_tween.set_parallel(false)
	_active_tween.tween_callback(callback)


func reset_camera(
	use_tween: bool,
	duration: float = 2.0,
	callback: Callable = Callable(),
	transition_type: String = "linear",
) -> bool:
	if active_camera == null or duration < 0.0:
		return false
	var pos: Vector2 = get_window().size / 2
	_cancel_pending_shakes()
	if use_tween:
		if _active_tween:
			_active_tween.kill()
		_active_tween = create_tween()
		_apply_transition(_active_tween, transition_type)
		_active_tween.set_parallel(true)
		_active_tween.tween_property(active_camera, "position", pos, duration)
		_active_tween.tween_property(active_camera, "zoom", Vector2.ONE, duration)
		_active_tween.set_parallel(false)
		_active_tween.tween_callback(callback)
	else:
		active_camera.position = pos
		active_camera.zoom = Vector2.ONE
		if callback.is_valid():
			callback.call()
	return true


func shake_camera(duration: float, callback: Callable = Callable()) -> bool:
	if active_camera == null or duration < 0.0:
		return false
	if duration <= 0:
		if callback.is_valid():
			callback.call()
		return true

	_cancel_pending_shakes()
	if _active_tween:
		_active_tween.kill()

	_shake_base_offset = active_camera.offset
	_active_tween = create_tween()
	var shake_tween := _active_tween
	_shake_tweens.append(shake_tween)
	_active_tween.tween_method(Callable(self, "_apply_shake"), 0.0, 1.0, duration)
	_active_tween.tween_callback(_complete_shake.bind(shake_tween, callback))
	return true


# ============================================================
# 异步相机操作（不阻塞对话）
# ============================================================


## 异步移动镜头到目标机位，不阻塞对话；返回后 Tween 在后台运行
func move_to_marker_async(
	marker_id: String, duration: float, transition_type: String = "linear"
) -> bool:
	if active_camera == null:
		push_error(
			"Konado: camera.move.async 失败：active_camera 未配置（请在 KonadoCameraController 中指定 Camera2D）"
		)
		return false
	if duration < 0.0:
		push_error("Konado: camera.move.async 失败：duration 不能为负数（%f）" % duration)
		return false
	if camera_markers.is_empty():
		push_error(
			"Konado: camera.move.async 失败：camera_markers 为空，未找到机位 '%s'。"
			% marker_id
		)
		return false
	for marker in camera_markers:
		if is_instance_valid(marker) and marker.marker_id == marker_id:
			_async_target_pos = marker.position
			_async_target_zoom = marker.zoom
			return _start_async_tween(marker.position, marker.zoom, duration, transition_type)
	var known: String = ", ".join(camera_markers.map(
		func(m): 
			return m.marker_id if is_instance_valid(m) else "<invalid>")
			)
	push_error(
		"Konado: camera.move.async 失败：未注册机位 '%s'。已注册的机位：%s" % [marker_id, known]
	)
	return false


## 异步重置镜头到默认位置，不阻塞对话
func reset_camera_async(duration: float, transition_type: String = "linear") -> bool:
	if active_camera == null or duration < 0.0:
		return false
	_async_target_pos = get_window().size / 2
	_async_target_zoom = Vector2.ONE
	return _start_async_tween(_async_target_pos, _async_target_zoom, duration, transition_type)


## 异步镜头晃动，不阻塞对话
func shake_camera_async(duration: float) -> bool:
	if active_camera == null or duration < 0.0:
		return false
	if duration == 0.0:
		return true

	_cancel_pending_shakes()
	_shake_base_offset = active_camera.offset
	var shake_tween := create_tween()
	_shake_tweens.append(shake_tween)
	shake_tween.tween_method(Callable(self, "_apply_shake"), 0.0, 1.0, duration)
	shake_tween.tween_callback(_complete_shake.bind(shake_tween, Callable()))
	_async_tweens.append(shake_tween)
	# 将初始偏移也记录为最终目标，以便 stop 时恢复
	_async_target_pos = active_camera.position
	_async_target_zoom = active_camera.zoom
	return true


## 强制终止所有异步相机 Tween，瞬间定格到最终目标位置
func finish_async_operations() -> bool:
	if active_camera == null:
		return false
	_cancel_pending_shakes()
	for pending_tween in _async_tweens:
		if pending_tween and pending_tween.is_valid():
			pending_tween.kill()
	_async_tweens.clear()
	# 瞬间定格到最终目标
	active_camera.position = _async_target_pos
	active_camera.zoom = _async_target_zoom
	return true


## 取消当前镜头遗留的同步与异步动画，但保持已经到达的位置和缩放。
func cancel_pending_operations() -> void:
	_cancel_pending_shakes()
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	for pending_tween in _async_tweens:
		if pending_tween and pending_tween.is_valid():
			pending_tween.kill()
	_async_tweens.clear()


## 捕获当前相机变换。进行中的 Tween 会以当前画面为快照边界。
func capture_state() -> Dictionary:
	if active_camera == null:
		return {}
	return {
		"position": active_camera.position,
		"zoom": active_camera.zoom,
		"offset": active_camera.offset,
	}


## 取消所有待处理动画并立即恢复确定性的相机变换。
func restore_state(state: Dictionary) -> bool:
	if active_camera == null or state.is_empty():
		return active_camera != null
	cancel_pending_operations()
	active_camera.position = state.get("position", active_camera.position)
	active_camera.zoom = state.get("zoom", active_camera.zoom)
	active_camera.offset = state.get("offset", Vector2.ZERO)
	_async_target_pos = active_camera.position
	_async_target_zoom = active_camera.zoom
	_shake_base_offset = active_camera.offset
	return true


func _complete_shake(shake_tween: Tween, callback: Callable) -> void:
	_shake_tweens.erase(shake_tween)
	_async_tweens.erase(shake_tween)
	if _active_tween == shake_tween:
		_active_tween = null
	if active_camera and _shake_tweens.is_empty():
		active_camera.offset = _shake_base_offset
	if callback.is_valid():
		callback.call()


func _cancel_pending_shakes() -> void:
	if _shake_tweens.is_empty():
		return
	for shake_tween in _shake_tweens:
		if shake_tween and shake_tween.is_valid():
			shake_tween.kill()
		_async_tweens.erase(shake_tween)
		if _active_tween == shake_tween:
			_active_tween = null
	_shake_tweens.clear()
	if active_camera:
		active_camera.offset = _shake_base_offset


## 启动异步 Tween（无回调，不阻塞）
func _start_async_tween(
	target_pos: Vector2,
	target_zoom: Vector2,
	duration: float,
	transition_type: String,
) -> bool:
	if active_camera == null or duration < 0.0:
		return false
	var async_tween := create_tween()
	_apply_transition(async_tween, transition_type)
	async_tween.set_parallel(true)
	async_tween.tween_property(active_camera, "position", target_pos, duration)
	async_tween.tween_property(active_camera, "zoom", target_zoom, duration)
	async_tween.set_parallel(false)
	# Tween 完成后自动从追踪列表移除
	async_tween.finished.connect(func(): _async_tweens.erase(async_tween))
	_async_tweens.append(async_tween)
	return true


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

	active_camera.offset = _shake_base_offset + Vector2(offset_x, offset_y)
