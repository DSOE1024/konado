@tool
extends RefCounted
class_name KND_ActorStateTransitionController

## 角色状态转场控制器。
## 交叉淡入淡出：旧状态淡出的同时新状态淡入，中间不留空隙。

signal transition_started(status_name: String)
signal status_applied(status_name: String)
signal transition_cancelled(status_name: String)
signal transition_finished(status_name: String, succeeded: bool)

var _host: Node
var _visual_provider: Callable
var _status_applier: Callable
var _active_tween: Tween
var _active_visual: CanvasItem
var _overlay_visual: CanvasItem
var _active_status_name := ""
var _active_completion: Callable
var _active_target_alpha := 1.0
var _active_request_id := 0
var _apply_succeeded := false
var _has_active_request := false


func _init(host: Node, visual_provider: Callable, status_applier: Callable) -> void:
	_host = host
	_visual_provider = visual_provider
	_status_applier = status_applier


## 请求切换状态。duration 表示交叉淡入淡出的总时长。
## 新请求会先取消旧请求；每个请求的 completion 都保证只调用一次。
func request(status_name: String, duration: float, completion: Callable = Callable()) -> void:
	cancel()
	_active_request_id += 1
	var request_id := _active_request_id
	_active_status_name = status_name
	_active_completion = completion
	_apply_succeeded = false
	_has_active_request = true
	transition_started.emit(status_name)

	var visual := _get_visual()
	if duration <= 0.0 or visual == null or not _can_animate():
		_apply_succeeded = _apply_status(status_name)
		if _apply_succeeded:
			status_applied.emit(status_name)
		_finish(request_id)
		return

	_active_visual = visual
	_active_target_alpha = visual.modulate.a

	# 创建旧状态快照作为覆盖层，用于交叉淡入淡出
	_create_overlay(visual)

	# 先应用新状态（会替换 visual 的子节点）
	_apply_succeeded = _apply_status(status_name)
	if _apply_succeeded:
		status_applied.emit(status_name)

	# 新视觉节点初始 alpha 为 0
	_set_alpha(visual, 0.0)

	# 同时执行：旧快照淡出 + 新视觉淡入
	_start_crossfade(request_id, maxf(duration, 0.0))


## 取消当前请求并恢复视觉透明度。取消请求会以失败状态完成。
func cancel() -> void:
	if not _has_active_request:
		return
	var status_name := _active_status_name
	var completion := _active_completion
	_active_request_id += 1
	_stop_tween()
	_remove_overlay()
	_restore_visual()
	_clear_active_state()
	transition_cancelled.emit(status_name)
	transition_finished.emit(status_name, false)
	_call_completion(completion, false)


func is_transitioning() -> bool:
	return _has_active_request


## 创建旧视觉内容的快照覆盖层，作为交叉淡入淡出的淡出对象。
func _create_overlay(visual: CanvasItem) -> void:
	if visual.get_child_count() == 0:
		return
	var parent := visual.get_parent()
	if parent == null:
		return

	var overlay := Control.new()
	overlay.name = "_CrossfadeOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if visual is Control:
		var vc := visual as Control
		overlay.anchor_left = vc.anchor_left
		overlay.anchor_top = vc.anchor_top
		overlay.anchor_right = vc.anchor_right
		overlay.anchor_bottom = vc.anchor_bottom
		overlay.offset_left = vc.offset_left
		overlay.offset_top = vc.offset_top
		overlay.offset_right = vc.offset_right
		overlay.offset_bottom = vc.offset_bottom
		overlay.grow_horizontal = vc.grow_horizontal
		overlay.grow_vertical = vc.grow_vertical
		overlay.size = vc.size
		overlay.position = vc.position

	overlay.modulate = visual.modulate

	# 复制所有子节点（旧状态的视觉内容，如 TextureRect 等）
	for child in visual.get_children():
		var dup := child.duplicate(Node.DUPLICATE_GROUPS)
		overlay.add_child(dup)

	parent.add_child(overlay)
	parent.move_child(overlay, visual.get_index())
	_overlay_visual = overlay


## 启动交叉淡入淡出：旧快照淡出 + 新视觉淡入。
func _start_crossfade(request_id: int, duration: float) -> void:
	if duration <= 0.0:
		_remove_overlay()
		_restore_visual()
		_finish(request_id)
		return

	_active_tween = _host.create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)

	# 旧快照淡出
	if _overlay_visual and is_instance_valid(_overlay_visual):
		_active_tween.tween_property(_overlay_visual, "modulate:a", 0.0, duration)

	# 新视觉淡入
	_active_tween.tween_property(_active_visual, "modulate:a", _active_target_alpha, duration)

	_active_tween.finished.connect(
		_on_crossfade_finished.bind(request_id), ConnectFlags.CONNECT_ONE_SHOT
	)


func _on_crossfade_finished(request_id: int) -> void:
	if not _is_current_request(request_id):
		return
	_active_tween = null
	_remove_overlay()
	_restore_visual()
	_finish(request_id)


func _remove_overlay() -> void:
	if _overlay_visual and is_instance_valid(_overlay_visual):
		_overlay_visual.queue_free()
	_overlay_visual = null


func _finish(request_id: int) -> void:
	if not _is_current_request(request_id):
		return
	var status_name := _active_status_name
	var completion := _active_completion
	var succeeded := _apply_succeeded
	_stop_tween()
	_remove_overlay()
	_restore_visual()
	_clear_active_state()
	transition_finished.emit(status_name, succeeded)
	_call_completion(completion, succeeded)


func _apply_status(status_name: String) -> bool:
	if not _status_applier.is_valid():
		return false
	return _status_applier.call(status_name) == true


func _get_visual() -> CanvasItem:
	if not _visual_provider.is_valid():
		return null
	var visual: Variant = _visual_provider.call()
	if visual is CanvasItem and is_instance_valid(visual):
		return visual as CanvasItem
	return null


func _can_animate() -> bool:
	return _host != null and is_instance_valid(_host) and _host.is_inside_tree()


func _is_current_request(request_id: int) -> bool:
	return request_id == _active_request_id and _has_active_request


func _stop_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _restore_visual() -> void:
	_restore_canvas_item(_active_visual, _active_target_alpha)


func _restore_canvas_item(visual: CanvasItem, target_alpha: float) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	_set_alpha(visual, target_alpha)


func _set_alpha(visual: CanvasItem, alpha: float) -> void:
	var color := visual.modulate
	color.a = clampf(alpha, 0.0, 1.0)
	visual.modulate = color


func _clear_active_state() -> void:
	_has_active_request = false
	_active_status_name = ""
	_active_completion = Callable()
	_active_visual = null
	_active_target_alpha = 1.0
	_apply_succeeded = false
	_overlay_visual = null


func _call_completion(completion: Callable, succeeded: bool) -> void:
	if completion.is_valid():
		completion.call(succeeded)
