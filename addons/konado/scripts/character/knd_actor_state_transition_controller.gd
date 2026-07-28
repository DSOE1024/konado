@tool
extends RefCounted
class_name KND_ActorStateTransitionController

## 角色状态转场控制器。
## 只操作当前视觉节点的透明度，不复制角色场景，避免脚本、音频和动态媒体被重复实例化。

signal transition_started(status_name: String)
signal status_applied(status_name: String)
signal transition_cancelled(status_name: String)
signal transition_finished(status_name: String, succeeded: bool)

var _host: Node
var _visual_provider: Callable
var _status_applier: Callable
var _active_tween: Tween
var _active_visual: CanvasItem
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


## 请求切换状态。duration 表示淡出和淡入的总时长。
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
	_start_fade_out(request_id, maxf(duration, 0.0) * 0.5)


## 取消当前请求并恢复视觉透明度。取消请求会以失败状态完成。
func cancel() -> void:
	if not _has_active_request:
		return
	var status_name := _active_status_name
	var completion := _active_completion
	_active_request_id += 1
	_stop_tween()
	_restore_visual()
	_clear_active_state()
	transition_cancelled.emit(status_name)
	transition_finished.emit(status_name, false)
	_call_completion(completion, false)


func is_transitioning() -> bool:
	return _has_active_request


func _start_fade_out(request_id: int, duration: float) -> void:
	if duration <= 0.0:
		_on_fade_out_finished(request_id, duration)
		return
	_active_tween = _host.create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.tween_property(_active_visual, "modulate:a", 0.0, duration)
	_active_tween.finished.connect(
		_on_fade_out_finished.bind(request_id, duration), ConnectFlags.CONNECT_ONE_SHOT
	)


func _on_fade_out_finished(request_id: int, fade_in_duration: float) -> void:
	if not _is_current_request(request_id):
		return
	_active_tween = null
	var previous_visual := _active_visual
	var previous_target_alpha := _active_target_alpha
	_apply_succeeded = _apply_status(_active_status_name)
	if _apply_succeeded:
		status_applied.emit(_active_status_name)

	var next_visual := _get_visual()
	if next_visual == null or not _can_animate():
		_restore_canvas_item(previous_visual, previous_target_alpha)
		_finish(request_id)
		return

	_active_visual = next_visual
	_active_target_alpha = (
		previous_target_alpha if next_visual == previous_visual else next_visual.modulate.a
	)
	_set_alpha(next_visual, 0.0)
	if fade_in_duration <= 0.0:
		_restore_visual()
		_finish(request_id)
		return

	_active_tween = _host.create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(
		_active_visual, "modulate:a", _active_target_alpha, fade_in_duration
	)
	_active_tween.finished.connect(
		_on_fade_in_finished.bind(request_id), ConnectFlags.CONNECT_ONE_SHOT
	)


func _on_fade_in_finished(request_id: int) -> void:
	if not _is_current_request(request_id):
		return
	_active_tween = null
	_restore_visual()
	_finish(request_id)


func _finish(request_id: int) -> void:
	if not _is_current_request(request_id):
		return
	var status_name := _active_status_name
	var completion := _active_completion
	var succeeded := _apply_succeeded
	_stop_tween()
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


func _call_completion(completion: Callable, succeeded: bool) -> void:
	if completion.is_valid():
		completion.call(succeeded)
