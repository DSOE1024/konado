extends Control
class_name KonadoStageController

## 管理剧情舞台中的背景、演员和视觉效果。

## 完成背景切换的信号
signal background_change_finished(succeeded: bool)
## 完成角色显示的信号
signal actor_shown(succeeded: bool)
## 完成角色删除的信号
signal actor_removed(succeeded: bool)
## 完成角色切换状态的信号
signal actor_state_changed(succeeded: bool)
## 完成角色移动的信号
signal actor_moved(succeeded: bool)
## 指定角色舞台动作开始的信号
signal actor_motion_started(actor_id: String, motion_name: String)
## 指定角色舞台动作完成的信号
signal actor_motion_finished(actor_id: String, motion_name: String, succeeded: bool)
## 指定演员景别过渡完成。
signal actor_framing_changed(actor_id: String, preset_id: String, succeeded: bool, reason: String)
## Internal request-scoped completion used by the atomic runtime. Public stage
## signals above remain available for direct integrations.
signal operation_finished(request_id: int, succeeded: bool, failure: Dictionary)

## 特效种类
enum BackgroundTransitionEffect {
	INVALID = -1,
	NONE,
	ERASE,
	BLINDS,
	WAVE,
	ALPHA_FADE,
	VORTEX_SWAP,
	WINDMILL,
	CYBER_GLITCH,
	BLINK,
}

const BACKGROUND_EFFECT_NAMES := {
	BackgroundTransitionEffect.NONE: "none",
	BackgroundTransitionEffect.ERASE: "erase",
	BackgroundTransitionEffect.BLINDS: "blinds",
	BackgroundTransitionEffect.WAVE: "wave",
	BackgroundTransitionEffect.ALPHA_FADE: "fade",
	BackgroundTransitionEffect.VORTEX_SWAP: "vortex",
	BackgroundTransitionEffect.WINDMILL: "windmill",
	BackgroundTransitionEffect.CYBER_GLITCH: "cyberglitch",
	BackgroundTransitionEffect.BLINK: "blink",
}
const ACTOR_STATE_REQUEST_COORDINATOR := preload(
	"res://addons/konado/runtime/stage/character/konado_actor_state_request_coordinator.gd"
)
const BACKGROUND_TRANSITION_LAYER_SCRIPT := preload(
	"res://addons/konado/runtime/stage/background/konado_background_transition_layer.gd"
)
const STAGE_OPERATION_TRACKER := preload(
	"res://addons/konado/runtime/stage/konado_stage_operation_tracker.gd"
)
const STAGE_FAILURE_REPORTER := preload(
	"res://addons/konado/runtime/stage/konado_stage_failure_reporter.gd"
)
const STAGE_UTILITIES := preload("res://addons/konado/runtime/stage/konado_stage_utilities.gd")
const STAGE_TREE_BUILDER := preload(
	"res://addons/konado/runtime/stage/konado_stage_tree_builder.gd"
)
const ACTOR_FRAMING_COORDINATOR := preload(
	"res://addons/konado/runtime/stage/character/konado_actor_framing_coordinator.gd"
)
const ACTOR_PRESENTER := preload(
	"res://addons/konado/runtime/stage/character/konado_actor_presenter.gd"
)
const ACTOR_UPSERT_TRANSACTION := preload(
	"res://addons/konado/runtime/stage/character/konado_actor_upsert_transaction.gd"
)
const ACTOR_SHOW_OPTION_NAMES := [
	"motion_layer_scene",
	"framing_profile",
	"duration",
	"report_errors",
	"request_id",
	"framing",
]

## 启用全局演员背景色调混合
@export var background_tint_enabled: bool = true
## 全局演员背景色调混合
@export var global_tint_intensity: float = 0.3:
	set(value):
		global_tint_intensity = clamp(value, 0.0, 0.5)
		# 如果正在游戏中，立刻刷新所有角色染色
		if is_inside_tree():
			apply_background_tint_to_actors()

## 启用演员状态切换淡入淡出过渡
@export var actor_state_transition_enabled: bool = true
## 演员状态切换总时长（秒）；支持状态帧时交融，否则淡出和淡入各占一半
@export_range(0.0, 5.0, 0.01, "or_greater") var actor_state_transition_duration: float = 0.3:
	set(value):
		actor_state_transition_duration = maxf(value, 0.0)

## 可持久化的演员状态，以演员 ID 为键。
var actor_states: Dictionary[String, Dictionary] = {}
## 舞台上的演员实例缓存，以演员 ID 为键。
var actor_instances: Dictionary[String, KonadoActor] = {}
## 角色列表
var character_list: KonadoCharacterList
## 存档用背景 id
var background_id: String = ""

var _background_controller := KonadoBackgroundController.new()
var _actor_state_request_serial: int = 0
var _actor_state_request_tokens: Dictionary[String, int] = {}
var _actor_pending_states: Dictionary[String, String] = {}
var _actor_state_requests: Dictionary = {}
var _highlighted_actor_id: String = ""
var _last_failure: Dictionary = {}
var _operation_tracker_instance := STAGE_OPERATION_TRACKER.new()
var _actor_framing_coordinator: RefCounted
var _actor_presenter_instance: RefCounted
var _actor_upsert_transaction_instance: RefCounted

## 演员模板
@onready var _konado_actor_template: PackedScene = preload(
	"res://addons/konado/templates/default/character/character_template.tscn"
)
## 背景底色层
@onready var _background: ColorRect = get_node_or_null("BackgroundLayer") as ColorRect
## 背景场景容器
@onready var _background_container: Control = (
	get_node_or_null("BackgroundLayer/BackgroundContainer") as Control
)
## 背景 shader 转场层
@onready var _background_transition_layer: BACKGROUND_TRANSITION_LAYER_SCRIPT = (
	get_node_or_null("BackgroundTransitionLayer") as BACKGROUND_TRANSITION_LAYER_SCRIPT
)
## 角色容器
@onready var _actor_layer: Control = get_node_or_null("ActorLayer") as Control
## 效果层
@onready var _effect_layer: ColorRect = get_node_or_null("EffectLayer") as ColorRect


func _ready() -> void:
	_actor_framing_coordinator = ACTOR_FRAMING_COORDINATOR.new(self)
	_ensure_stage_nodes()
	_background_controller.setup(_background_container, _background_transition_layer)
	_background_controller.transition_finished.connect(_on_background_change_finished)
	for child in _actor_layer.get_children():
		child.queue_free()


func _on_background_change_finished(succeeded: bool) -> void:
	if succeeded:
		apply_background_tint_to_actors()
	else:
		var background_failure := _background_controller.get_last_failure()
		if not background_failure.is_empty():
			_last_failure = background_failure
	var request_id := _operation_tracker().take_background_request()
	_operation_tracker().complete(request_id, succeeded, _last_failure if not succeeded else {})
	background_change_finished.emit(succeeded)


## Allocates a request identity before a stage method is invoked, allowing the
## caller to subscribe before even a synchronous rejection is emitted.
func begin_operation_request() -> int:
	return _operation_tracker().begin_request()


func _operation_tracker() -> KonadoStageOperationTracker:
	var callback := Callable(self, "_on_operation_finished")
	if not _operation_tracker_instance.operation_finished.is_connected(callback):
		_operation_tracker_instance.operation_finished.connect(callback)
	return _operation_tracker_instance


func _on_operation_finished(request_id: int, succeeded: bool, failure: Dictionary) -> void:
	operation_finished.emit(request_id, succeeded, failure)


## Returns the failure produced by the most recently rejected stage operation.
## The atomic runtime reads this immediately when a completion signal reports
## failure, so the final log retains the subsystem's exact cause.
func get_last_failure() -> Dictionary:
	return _last_failure.duplicate(true)


## 确保表演舞台的层级存在。
## 背景已经全面转成场景，这里只兜住“场景挂载层”本身，避免旧模板实例没有 BackgroundContainer 时背景无法显示。
func _ensure_stage_nodes() -> void:
	var nodes := (
		STAGE_TREE_BUILDER
		. ensure(
			self,
			{
				"background": _background,
				"background_container": _background_container,
				"background_transition_layer": _background_transition_layer,
				"actor_layer": _actor_layer,
				"effect_layer": _effect_layer,
			},
			BACKGROUND_TRANSITION_LAYER_SCRIPT,
		)
	)
	_background = nodes["background"]
	_background_container = nodes["background_container"]
	_background_transition_layer = nodes["background_transition_layer"]
	_actor_layer = nodes["actor_layer"]
	_effect_layer = nodes["effect_layer"]


## 返回舞台上的演员实例。
func get_actor(actor_id: String) -> KonadoActor:
	if actor_instances.has(actor_id):
		var cached_node := actor_instances[actor_id]
		if cached_node and is_instance_valid(cached_node):
			return cached_node
		actor_instances.erase(actor_id)

	var actor := _actor_layer.find_child(actor_id, true, false) as KonadoActor
	if actor != null:
		actor_instances[actor_id] = actor
		return actor
	return null


## 清空背景
func clean_background(effects_type: BackgroundTransitionEffect) -> void:
	_operation_tracker().supersede_background(background_id)
	_ensure_stage_nodes()
	background_id = ""
	_background_controller.clear(_background_effect_name(effects_type))


## 显示背景场景的方法
func change_background_scene(
	scene: PackedScene,
	name: String,
	effects_type: BackgroundTransitionEffect,
	duration: float = -1.0,
	report_errors := true,
	request_id := 0,
) -> void:
	_last_failure.clear()
	_operation_tracker().register_background(request_id, background_id)
	_ensure_stage_nodes()
	if scene == null:
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record(
				&"stage.background_scene_missing",
				"切换背景失败：背景场景为空",
				"background",
				"background",
				name,
				report_errors,
			)
		)
		_operation_tracker().take_background_request()
		_operation_tracker().complete(request_id, false, _last_failure)
		background_change_finished.emit(false)
		return
	background_id = name
	_background_controller.change(
		scene, name, _background_effect_name(effects_type), duration, report_errors
	)


func _background_effect_name(effects_type: BackgroundTransitionEffect) -> String:
	return BACKGROUND_EFFECT_NAMES.get(effects_type, "none")


func get_current_background() -> KonadoBackgroundSceneBase:
	return _background_controller.current_background


func get_pending_background() -> KonadoBackgroundSceneBase:
	return _background_controller.get_pending_background()


## 显示角色。角色不存在时创建，已存在时复用节点并更新状态或位置。
func show_actor(
	actor_id: String,
	horizontal_division: int,
	horizontal_position: int,
	state: String,
	character_scene: PackedScene = null,
	options: Dictionary = {},
) -> void:
	_last_failure.clear()
	var option_result := _normalize_actor_show_options(options)
	var normalized_options: Dictionary = option_result.get("options", {})
	if option_result.has("cause"):
		var report_errors := (
			bool(normalized_options.get("report_errors", true))
			if typeof(normalized_options.get("report_errors", true)) == TYPE_BOOL
			else true
		)
		var request_id := (
			int(normalized_options.get("request_id", 0))
			if typeof(normalized_options.get("request_id", 0)) == TYPE_INT
			else 0
		)
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_show_options_invalid",
				"显示角色失败：参数配置无效",
				"actor.show",
				actor_id,
				report_errors,
				String(option_result.get("cause", "")),
			)
		)
		_emit_actor_shown(false, request_id)
		return
	options = normalized_options
	var duration := float(options.get("duration", -1.0))
	var report_errors := bool(options.get("report_errors", true))
	var request_id := int(options.get("request_id", 0))
	var framing_id := StringName(options.get("framing", ""))
	var existing_actor := get_actor(actor_id) as KonadoActor
	if existing_actor != null:
		_update_existing_actor(
			existing_actor,
			actor_id,
			horizontal_division,
			horizontal_position,
			state,
			duration,
			report_errors,
			request_id,
			framing_id,
		)
		return
	_create_actor(
		actor_id, horizontal_division, horizontal_position, state, character_scene, options
	)


func _normalize_actor_show_options(options: Dictionary) -> Dictionary:
	var normalized := {}
	var cause := ""
	for option_key: Variant in options:
		if typeof(option_key) not in [TYPE_STRING, TYPE_STRING_NAME]:
			if cause.is_empty():
				cause = "参数名必须是 String 或 StringName"
			continue
		var option_name := String(option_key)
		if option_name not in ACTOR_SHOW_OPTION_NAMES:
			if cause.is_empty():
				cause = "未知参数=%s" % option_name
			continue
		if normalized.has(option_name):
			if cause.is_empty():
				cause = "参数重复=%s" % option_name
			continue
		normalized[option_name] = options[option_key]
	var motion_layer_scene: Variant = normalized.get("motion_layer_scene")
	if cause.is_empty() and motion_layer_scene != null and not motion_layer_scene is PackedScene:
		cause = "motion_layer_scene 必须是 PackedScene 或 null"
	var framing_profile: Variant = normalized.get("framing_profile")
	if (
		cause.is_empty()
		and framing_profile != null
		and not framing_profile is KonadoActorFramingProfile
	):
		cause = "framing_profile 必须是 KonadoActorFramingProfile 或 null"
	var duration: Variant = normalized.get("duration", -1.0)
	if cause.is_empty() and typeof(duration) not in [TYPE_INT, TYPE_FLOAT]:
		cause = "duration 必须是数值"
	elif cause.is_empty():
		var duration_value := float(duration)
		if (
			not is_finite(duration_value)
			or (duration_value < 0.0 and not is_equal_approx(duration_value, -1.0))
		):
			cause = "duration 必须为 -1 或非负有限数值"
	if cause.is_empty() and typeof(normalized.get("report_errors", true)) != TYPE_BOOL:
		cause = "report_errors 必须是 bool"
	var request_id: Variant = normalized.get("request_id", 0)
	if cause.is_empty() and (typeof(request_id) != TYPE_INT or int(request_id) < 0):
		cause = "request_id 必须是非负整数"
	if (
		cause.is_empty()
		and typeof(normalized.get("framing", &"")) not in [TYPE_STRING, TYPE_STRING_NAME]
	):
		cause = "framing 必须是 String 或 StringName"
	return {"options": normalized} if cause.is_empty() else {"options": normalized, "cause": cause}


func _create_actor(
	actor_id: String,
	horizontal_division: int,
	horizontal_position: int,
	state: String,
	character_scene: PackedScene,
	options: Dictionary,
) -> void:
	_actor_presenter().create_actor(
		actor_id, horizontal_division, horizontal_position, state, character_scene, options
	)


func _actor_presenter() -> RefCounted:
	if _actor_presenter_instance == null:
		_actor_presenter_instance = ACTOR_PRESENTER.new(self)
	return _actor_presenter_instance


func _update_existing_actor(
	actor: KonadoActor,
	actor_id: String,
	horizontal_division: int,
	horizontal_position: int,
	state: String,
	duration: float = -1.0,
	report_errors := true,
	request_id := 0,
	framing_id: StringName = &"",
) -> void:
	(
		_actor_upsert_transaction()
		. execute(
			actor,
			actor_id,
			horizontal_division,
			horizontal_position,
			state,
			duration,
			report_errors,
			request_id,
			framing_id,
		)
	)


func _actor_upsert_transaction() -> RefCounted:
	if _actor_upsert_transaction_instance == null:
		_actor_upsert_transaction_instance = ACTOR_UPSERT_TRANSACTION.new(self)
	return _actor_upsert_transaction_instance


func _on_actor_entered(actor_id: String, state: String, request_id := 0) -> void:
	_emit_actor_shown(true, request_id)
	print("新建了演员：" + str(actor_id) + " 演员状态：" + str(state))


func _emit_actor_shown(succeeded: bool, request_id := 0, failure: Dictionary = {}) -> void:
	var result_failure := failure
	if not succeeded and result_failure.is_empty():
		result_failure = _last_failure.duplicate(true)
	_operation_tracker().complete(request_id, succeeded, result_failure)
	actor_shown.emit(succeeded)


func _discard_pending_actor(actor: KonadoActor) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var parent := actor.get_parent()
	if parent:
		parent.remove_child(actor)
	actor.free()


## 所有已有演员的状态变更都经过这一入口。这里负责业务所有权和存档提交，
## 协调器只负责把同步、异步、拒绝与离树归一为一次完成通知。
func _request_actor_state(
	actor: KonadoActor,
	actor_id: String,
	target_state: String,
	transition_duration: float,
	failure_message: String,
	operation: String,
	report_errors: bool,
	completion: Callable
) -> bool:
	var previous_request := _capture_actor_state_request(actor_id)
	var request_token := _begin_actor_state_request(actor_id)
	_actor_pending_states[actor_id] = target_state
	# 转场帧必须使用请求开始时已经刷新的舞台色调。
	apply_background_tint_to_actors()

	var failure_reported := [false]
	var report_failure := func() -> void:
		if failure_reported[0]:
			return
		failure_reported[0] = true
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_state_invalid",
				failure_message,
				operation,
				actor_id,
				report_errors,
				"目标状态=%s" % target_state,
				true,
			)
		)
	var coordinator := ACTOR_STATE_REQUEST_COORDINATOR.new(
		actor,
		target_state,
		transition_duration,
		func() -> bool: return _is_actor_state_request_current(actor_id, request_token),
		func() -> void: _commit_actor_state(actor_id, target_state, request_token),
		func() -> void:
			report_failure.call()
			_restore_actor_state_request(actor_id, request_token, previous_request),
		func(succeeded: bool, actor_exited: bool) -> void:
			_actor_state_requests.erase(request_token)
			var owned_request := _is_actor_state_request_current(actor_id, request_token)
			if owned_request:
				if succeeded:
					_commit_actor_state(actor_id, target_state, request_token)
				else:
					report_failure.call()
				_actor_pending_states.erase(actor_id)
			if completion.is_valid():
				completion.call(succeeded, actor_exited, owned_request)
	)
	# 在 start() 前持有协调器，保证同步重入和异步扩展实现使用同一生命周期对象。
	_actor_state_requests[request_token] = coordinator
	return coordinator.start()


func _commit_actor_state(actor_id: String, target_state: String, request_token: int) -> void:
	if not _is_actor_state_request_current(actor_id, request_token):
		return
	if actor_states.has(actor_id):
		actor_states[actor_id]["state"] = target_state


func _begin_actor_state_request(actor_id: String) -> int:
	_actor_state_request_serial += 1
	_actor_state_request_tokens[actor_id] = _actor_state_request_serial
	return _actor_state_request_serial


func _capture_actor_state_request(actor_id: String) -> Dictionary:
	return {
		"has_token": _actor_state_request_tokens.has(actor_id),
		"token": _actor_state_request_tokens.get(actor_id, -1),
		"has_pending_state": _actor_pending_states.has(actor_id),
		"pending_state": _actor_pending_states.get(actor_id, ""),
	}


func _restore_actor_state_request(
	actor_id: String, rejected_token: int, previous_request: Dictionary
) -> void:
	if not _is_actor_state_request_current(actor_id, rejected_token):
		return
	if previous_request.has_token:
		_actor_state_request_tokens[actor_id] = previous_request.token
	else:
		_actor_state_request_tokens.erase(actor_id)
	if previous_request.has_pending_state:
		_actor_pending_states[actor_id] = previous_request.pending_state
	else:
		_actor_pending_states.erase(actor_id)


func _is_actor_state_request_current(actor_id: String, request_token: int) -> bool:
	return int(_actor_state_request_tokens.get(actor_id, -1)) == request_token


func _invalidate_actor_state_request(actor_id: String) -> void:
	_actor_state_request_tokens.erase(actor_id)
	_actor_pending_states.erase(actor_id)


## 切换演员的状态
func change_actor_state(
	actor_id: String,
	state_id: String,
	duration: float = -1.0,
	report_errors := true,
	request_id := 0,
) -> void:
	_last_failure.clear()
	var actor: KonadoActor = get_actor(actor_id)
	if actor == null:
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_not_present",
				"切换角色状态失败：角色ID[%s]，目标状态ID[%s]，未找到角色节点" % [actor_id, state_id],
				"actor.change",
				actor_id,
				report_errors,
				"目标状态=%s" % state_id,
			)
		)
		_operation_tracker().complete(request_id, false, _last_failure)
		actor_state_changed.emit(false)
		return

	var transition_duration := (
		duration
		if duration >= 0.0
		else actor_state_transition_duration if actor_state_transition_enabled else 0.0
	)
	_request_actor_state(
		actor,
		actor_id,
		state_id,
		transition_duration,
		"切换角色状态失败：角色[%s]无法应用状态[%s]" % [actor_id, state_id],
		"actor.change",
		report_errors,
		func(succeeded: bool, _actor_exited: bool, owned_request: bool) -> void:
			if succeeded and owned_request:
				print("切换" + actor_id + "到" + str(state_id) + "状态")
			var completed := succeeded and owned_request
			var completion_failure := {}
			if not completed:
				completion_failure = (
					_last_failure
					if owned_request
					else _operation_tracker().superseded_failure("actor.change", "actor", actor_id)
				)
			_operation_tracker().complete(request_id, completed, completion_failure)
			actor_state_changed.emit(completed)
	)


## 播放指定演员的舞台层动作，例如 shake、jump_twice、bounce。
## 这里不进入角色场景，避免把整体位移和内部表情/媒体播放混在一起。
func play_actor_motion(
	actor_id: String,
	motion_name: String,
	params: Dictionary = {},
	report_errors := true,
	request_id := 0,
) -> void:
	_last_failure.clear()
	_operation_tracker().register_actor_motion(actor_id, motion_name, request_id)
	if motion_name.is_empty():
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_motion_empty",
				"播放演员动作失败：角色ID[%s]，动作名为空" % actor_id,
				"actor.motion",
				actor_id,
				report_errors,
			)
		)
		_operation_tracker().take_actor_motion(actor_id, motion_name)
		_operation_tracker().complete(request_id, false, _last_failure)
		actor_motion_finished.emit(actor_id, motion_name, false)
		return
	var actor: KonadoActor = get_actor(actor_id) as KonadoActor
	if actor == null:
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_not_present",
				"播放演员动作失败：角色ID[%s]，动作[%s]，未找到角色节点" % [actor_id, motion_name],
				"actor.motion",
				actor_id,
				report_errors,
				"目标动作=%s" % motion_name,
			)
		)
		_operation_tracker().take_actor_motion(actor_id, motion_name)
		_operation_tracker().complete(request_id, false, _last_failure)
		actor_motion_finished.emit(actor_id, motion_name, false)
		return
	if not actor.can_play_actor_motion(motion_name):
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_motion_missing",
				"播放演员动作失败：角色[%s]没有动作[%s]" % [actor_id, motion_name],
				"actor.motion",
				actor_id,
				report_errors,
				"目标动作=%s" % motion_name,
			)
		)
		_operation_tracker().take_actor_motion(actor_id, motion_name)
		_operation_tracker().complete(request_id, false, _last_failure)
		actor_motion_finished.emit(actor_id, motion_name, false)
		return
	actor.play_actor_motion(motion_name, params)


## 将单个演员切换到持久景别。它不会移动背景、其他演员或全局相机。
func set_actor_framing(
	actor_id: String,
	preset_id: StringName,
	duration: float = -1.0,
	transition: String = "",
	report_errors := true,
	request_id := 0,
) -> bool:
	return _framing_coordinator().set_actor(
		actor_id, preset_id, duration, transition, report_errors, request_id
	)


## 同一帧中接受多个演员的景别更新。所有请求会先完整校验，任一无效时不修改舞台。
func set_actor_framings(
	framings: Dictionary,
	duration: float = -1.0,
	transition: String = "",
	report_errors := true,
) -> bool:
	return _framing_coordinator().set_actors(framings, duration, transition, report_errors)


func _framing_coordinator() -> RefCounted:
	if _actor_framing_coordinator == null:
		_actor_framing_coordinator = ACTOR_FRAMING_COORDINATOR.new(self)
	return _actor_framing_coordinator


## 高亮指定演员并弱化舞台上的其他演员。
func highlight_actor(actor_id: String) -> void:
	_highlighted_actor_id = actor_id if actor_states.has(actor_id) else ""
	if actor_states.size() <= 0:
		return
	for candidate_id in actor_states.keys():
		var candidate := get_actor(candidate_id)
		if candidate == null:
			continue
		candidate.set_highlight(actor_id == candidate_id)


## 从舞台移除指定演员。
func remove_actor(
	actor_id: String, duration: float = -1.0, report_errors := true, request_id := 0
) -> void:
	_last_failure.clear()
	_invalidate_actor_state_request(actor_id)
	if _highlighted_actor_id == actor_id:
		_highlighted_actor_id = ""
	if not actor_states.has(actor_id):
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_not_present",
				"移出演员失败：角色ID[%s]不在舞台上" % actor_id,
				"actor.exit",
				actor_id,
				report_errors,
			)
		)
		_operation_tracker().complete(request_id, false, _last_failure)
		actor_removed.emit(false)
		return
	var actor := get_actor(actor_id)
	actor_states.erase(actor_id)
	actor_instances.erase(actor_id)
	if actor == null:
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_node_missing",
				"移出演员失败：角色ID[%s]的舞台节点不存在" % actor_id,
				"actor.exit",
				actor_id,
				report_errors,
			)
		)
		_operation_tracker().complete(request_id, false, _last_failure)
		actor_removed.emit(false)
		return
	actor._cancel_character_status_transition()
	actor.cancel_actor_framing("actor_removed")
	actor.tree_exited.connect(
		func() -> void:
			_operation_tracker().complete(request_id, true)
			actor_removed.emit(true),
		ConnectFlags.CONNECT_ONE_SHOT,
	)
	actor.exit_actor(true, duration)


## 删除所有演员
func remove_all_actors(immediate: bool = false) -> void:
	_actor_state_request_tokens.clear()
	_actor_pending_states.clear()
	actor_states.clear()
	actor_instances.clear()
	_highlighted_actor_id = ""
	for node in _actor_layer.get_children():
		var actor := node as KonadoActor
		if actor == null:
			continue
		actor._cancel_character_status_transition()
		actor.cancel_actor_framing("actor_removed")
		if immediate:
			actor.free()
		else:
			actor.exit_actor(false)
	print("删除所有演员")


## 移动演员的方法
func move_actor(
	actor_id: String,
	target_h_division: int,
	duration: float = -1.0,
	report_errors := true,
	request_id := 0,
) -> void:
	_last_failure.clear()
	_operation_tracker().register_actor_move(actor_id, request_id)
	var actor: KonadoActor = get_actor(actor_id) as KonadoActor
	if actor == null:
		_last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_not_present",
				"移动角色失败：角色ID[%s]，未找到角色节点" % actor_id,
				"actor.move",
				actor_id,
				report_errors,
			)
		)
		_operation_tracker().take_actor_move(actor_id)
		_operation_tracker().complete(request_id, false, _last_failure)
		actor_moved.emit(false)
		return
	var movement_started := actor.set_stage_position(
		actor.horizontal_division, target_h_division, duration
	)
	if actor_states.has(actor_id):
		# The logical target is committed with the accepted request, matching the
		# save/restore semantics used by background and actor-framing transitions.
		actor_states[actor_id]["horizontal_division"] = actor.horizontal_division
		actor_states[actor_id]["horizontal_position"] = actor.horizontal_position
	if not movement_started:
		# 目标值在补间开始时就会更新。重复请求同一目标时必须继续等待正在运行的
		# 补间，不能提前释放 KonadoScript 的移动指令。
		if not actor._is_stage_position_moving():
			_operation_tracker().take_actor_move(actor_id)
			_operation_tracker().complete(request_id, true)
			actor_moved.emit(true)


func _on_actor_moved(actor_id := "") -> void:
	var request_id := _operation_tracker().take_actor_move(actor_id)
	_operation_tracker().complete(request_id, true)
	actor_moved.emit(true)


func _on_actor_motion_started(motion_name: String, actor_id: String) -> void:
	actor_motion_started.emit(actor_id, motion_name)


func _on_actor_motion_finished(motion_name: String, actor_id: String) -> void:
	var request_id := _operation_tracker().take_actor_motion(actor_id, motion_name)
	_operation_tracker().complete(request_id, true)
	actor_motion_finished.emit(actor_id, motion_name, true)


## 从当前背景获取环境色，并应用到所有角色的视觉层
func apply_background_tint_to_actors() -> void:
	var current_background := _background_controller.current_background
	if current_background == null:
		return

	var raw_color: Color = current_background.get_scene_tint_color()
	var total_intensity: float = 0.0
	if background_tint_enabled:
		total_intensity = clamp(
			global_tint_intensity * current_background.scene_tint_intensity, 0.0, 1.0
		)
	var tint_color: Color = Color.WHITE.lerp(raw_color, total_intensity)

	for actor_id in actor_states.keys():
		var actor := get_actor(actor_id) as KonadoActor
		if actor:
			actor.set_actor_modulate(tint_color)


## 捕获舞台的逻辑状态；角色场景节点和转场 Tween 不进入快照。
func capture_state() -> Dictionary:
	return STAGE_UTILITIES.capture_state(background_id, actor_states, _highlighted_actor_id)


## 中止所有未完成的舞台操作，为确定性恢复建立干净边界。
func cancel_pending_operations() -> void:
	_operation_tracker().cancel()
	_background_controller.cancel_pending()
	for actor_id in actor_states:
		_invalidate_actor_state_request(String(actor_id))
		var actor := get_actor(String(actor_id)) as KonadoActor
		if actor != null:
			actor._cancel_character_status_transition()
			actor.settle_actor_framing_to_target("runtime_cancelled")
