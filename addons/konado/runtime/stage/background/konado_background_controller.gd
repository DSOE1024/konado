extends RefCounted
class_name KonadoBackgroundController

## Owns background scene lifecycle and transition coordination for a stage.

signal transition_finished(succeeded: bool)

const BACKGROUND_TRANSITION_LAYER_SCRIPT := preload(
	"res://addons/konado/runtime/stage/background/konado_background_transition_layer.gd"
)

var current_background_id: String = ""
var current_background: KonadoBackgroundSceneBase

var _container: Control
var _transition_layer: BACKGROUND_TRANSITION_LAYER_SCRIPT
var _outgoing_background: KonadoBackgroundSceneBase
var _pending_background: KonadoBackgroundSceneBase
var _pending_transition_parts := 0


func setup(container: Control, transition_layer: BACKGROUND_TRANSITION_LAYER_SCRIPT) -> void:
	_container = container
	_transition_layer = transition_layer
	if (
		_transition_layer != null
		and not _transition_layer.transition_finished.is_connected(_on_shader_transition_finished)
	):
		_transition_layer.transition_finished.connect(_on_shader_transition_finished)


func clear(effect_name: String) -> void:
	cancel_pending()
	current_background_id = ""
	if current_background == null:
		transition_finished.emit(true)
		return
	_outgoing_background = current_background
	current_background = null
	_pending_transition_parts = 1
	_outgoing_background.background_exit_finished.connect(
		_on_transition_part_finished.bind(_outgoing_background), ConnectFlags.CONNECT_ONE_SHOT
	)
	_outgoing_background.play_exit(effect_name)


func change(
	scene: PackedScene, background_id: String, effect_name: String, duration: float = -1.0
) -> void:
	if scene == null:
		push_error("切换背景失败：背景场景为空")
		transition_finished.emit(false)
		return
	if _container == null or _transition_layer == null:
		push_error("切换背景失败：舞台背景控制器尚未初始化")
		transition_finished.emit(false)
		return

	cancel_pending()
	var instance := scene.instantiate()
	if not (instance is KonadoBackgroundSceneBase):
		push_error("背景场景必须继承 KonadoBackgroundSceneBase：" + background_id)
		instance.free()
		transition_finished.emit(false)
		return

	var next_background := instance as KonadoBackgroundSceneBase
	current_background_id = background_id
	next_background.name = background_id
	_prepare_background(next_background)
	var transition_parameters := {}
	if duration >= 0.0:
		transition_parameters["duration"] = duration
	next_background.setup_background(background_id, transition_parameters)

	var previous_background := current_background
	if _transition_layer.supports_effect(effect_name):
		_pending_background = next_background
		_outgoing_background = previous_background
		_transition_layer.play_transition(
			previous_background, next_background, effect_name, duration
		)
		return

	_container.add_child(next_background)
	current_background = next_background
	_outgoing_background = previous_background
	_pending_transition_parts = 1
	next_background.background_enter_finished.connect(
		_on_transition_part_finished.bind(next_background), ConnectFlags.CONNECT_ONE_SHOT
	)
	if previous_background != null and is_instance_valid(previous_background):
		_pending_transition_parts += 1
		previous_background.background_exit_finished.connect(
			_on_transition_part_finished.bind(previous_background), ConnectFlags.CONNECT_ONE_SHOT
		)
		previous_background.play_exit(effect_name, transition_parameters)
	next_background.play_enter(effect_name, transition_parameters)


func cancel_pending() -> void:
	if _transition_layer != null and _transition_layer.is_transitioning():
		_transition_layer.cancel_transition(true)
		current_background = null
		_pending_background = null
	if _outgoing_background != null and is_instance_valid(_outgoing_background):
		_outgoing_background.stop_background_transition()
		if _outgoing_background != current_background:
			_outgoing_background.queue_free()
	_outgoing_background = null
	_pending_transition_parts = 0


func get_pending_background() -> KonadoBackgroundSceneBase:
	return _pending_background


func _prepare_background(background: KonadoBackgroundSceneBase) -> void:
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	background.set_offsets_preset(Control.PRESET_FULL_RECT)


func _on_transition_part_finished(_background: KonadoBackgroundSceneBase) -> void:
	_pending_transition_parts -= 1
	if _pending_transition_parts > 0:
		return
	if _outgoing_background != null and is_instance_valid(_outgoing_background):
		_outgoing_background.queue_free()
	_outgoing_background = null
	transition_finished.emit(true)


func _on_shader_transition_finished(
	previous_background: KonadoBackgroundSceneBase, next_background: KonadoBackgroundSceneBase
) -> void:
	if previous_background != null and is_instance_valid(previous_background):
		previous_background.queue_free()
	if next_background != null and is_instance_valid(next_background):
		var parent := next_background.get_parent()
		if parent != null:
			parent.remove_child(next_background)
		_container.add_child(next_background)
		_prepare_background(next_background)
		next_background.show()
		current_background = next_background
	else:
		current_background = null
	_pending_background = null
	_outgoing_background = null
	_pending_transition_parts = 0
	transition_finished.emit(true)
