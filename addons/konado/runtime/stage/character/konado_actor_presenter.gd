extends RefCounted

## Creates actor nodes transactionally. A pending actor is never published to
## stage state until its motion layer, framing profile and initial state all pass.

const STAGE_FAILURE_REPORTER := preload(
	"res://addons/konado/runtime/stage/konado_stage_failure_reporter.gd"
)

var _host: Variant


func _init(host: Variant) -> void:
	_host = host


func create_actor(
	actor_id: String,
	horizontal_division: int,
	horizontal_position: int,
	state: String,
	character_scene: PackedScene,
	options: Dictionary,
) -> void:
	var motion_layer_scene := options.get("motion_layer_scene") as PackedScene
	var framing_profile := options.get("framing_profile") as KonadoActorFramingProfile
	var framing_id := StringName(options.get("framing", ""))
	var duration := float(options.get("duration", -1.0))
	var report_errors := bool(options.get("report_errors", true))
	var request_id := int(options.get("request_id", 0))

	# actor_states 可能残留旧数据；没有有效节点时按新建处理。
	_host._invalidate_actor_state_request(actor_id)
	if _host.actor_states.has(actor_id):
		_host.actor_states.erase(actor_id)

	if character_scene == null:
		_host._last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_scene_missing",
				"显示角色失败：角色[%s]没有配置角色场景" % actor_id,
				"actor.show",
				actor_id,
				report_errors,
				"目标状态=%s" % state,
			)
		)
		_host._emit_actor_shown(false, request_id)
		return

	var initial_horizontal_division: int = clamp(horizontal_division, 2, 5)
	var initial_horizontal_position: int = clamp(
		horizontal_position, 0, initial_horizontal_division
	)
	var actor_state: Dictionary = {
		"id": actor_id,
		"horizontal_division": initial_horizontal_division,
		"horizontal_position": initial_horizontal_position,
		"state": state,
		"framing": String(framing_id),
	}

	var node_name: String = str(actor_state["id"])
	var temp_node: KonadoActor = _host._konado_actor_template.instantiate() as KonadoActor
	if temp_node == null:
		_host._last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_template_failed",
				"显示角色失败：无法实例化演员模板",
				"actor.show",
				actor_id,
				report_errors,
			)
		)
		_host._emit_actor_shown(false, request_id)
		return
	var state_request_token: int = _host._begin_actor_state_request(actor_id)
	# 初始化阶段使用内部名称并隐藏根节点。这样角色场景能够正常进入 SceneTree、执行
	# @onready/_ready，又不会被 get_actor 当成已经公开的演员。
	temp_node.name = "_KonadoPendingActor_%d" % temp_node.get_instance_id()
	temp_node.visible = false
	temp_node.use_tween = false
	temp_node.set_stage_position(horizontal_division, horizontal_position)
	temp_node.actor_motion_started.connect(_host._on_actor_motion_started.bind(actor_id))
	temp_node.actor_motion_finished.connect(_host._on_actor_motion_finished.bind(actor_id))
	_host._actor_layer.add_child(temp_node)
	if not temp_node.set_motion_layer_scene(motion_layer_scene):
		_host._last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_motion_layer_invalid",
				"显示角色失败：角色[%s]的动作层配置无效" % actor_id,
				"actor.show",
				actor_id,
				report_errors,
				"",
				true,
			)
		)
		if _host._is_actor_state_request_current(actor_id, state_request_token):
			_host._invalidate_actor_state_request(actor_id)
		_host._discard_pending_actor(temp_node)
		_host._emit_actor_shown(false, request_id)
		return
	var framing_result: Dictionary = _host._framing_coordinator().configure_actor(
		temp_node, framing_profile, framing_id
	)
	if not bool(framing_result.get("ok", false)):
		_host._last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				StringName(framing_result.get("code", &"stage.actor_framing_profile_invalid")),
				"显示角色失败：角色[%s]%s" % [actor_id, framing_result.get("message", "")],
				"actor.show",
				actor_id,
				report_errors,
				String(framing_result.get("cause", "")),
				true,
			)
		)
		if _host._is_actor_state_request_current(actor_id, state_request_token):
			_host._invalidate_actor_state_request(actor_id)
		_host._discard_pending_actor(temp_node)
		_host._emit_actor_shown(false, request_id)
		return
	actor_state["framing"] = String(framing_result["preset_id"])

	if not temp_node.set_character_scene(character_scene, state):
		_host._last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_state_invalid",
				"显示角色失败：角色[%s]无法应用状态[%s]" % [actor_id, state],
				"actor.show",
				actor_id,
				report_errors,
				"目标状态=%s" % state,
				true,
			)
		)
		if _host._is_actor_state_request_current(actor_id, state_request_token):
			_host._invalidate_actor_state_request(actor_id)
		_host._discard_pending_actor(temp_node)
		_host._emit_actor_shown(false, request_id)
		return
	if not _host._is_actor_state_request_current(actor_id, state_request_token):
		# 初始化期间若同一演员已被更新请求取代，不允许旧请求进入场景树。
		_host._discard_pending_actor(temp_node)
		_host._last_failure = (
			STAGE_FAILURE_REPORTER
			. record_actor(
				&"stage.actor_request_superseded",
				"显示角色失败：角色[%s]的请求已被更新操作取代" % actor_id,
				"actor.show",
				actor_id,
				report_errors,
			)
		)
		_host._emit_actor_shown(false, request_id)
		return
	# 初始化事务成功后才使用公开名称并写入运行时索引。
	temp_node.name = node_name
	# 只有节点和初始状态都创建成功后，才提交存档使用的演员数据。
	_host.actor_states[actor_state["id"]] = actor_state
	# 角色场景创建完成后应用色调混合，确保新角色在显示前就已带有正确的色调
	_host.apply_background_tint_to_actors()
	_host.actor_instances[actor_id] = temp_node
	temp_node.actor_moved.connect(_host._on_actor_moved.bind(actor_id))
	temp_node.actor_entered.connect(
		_host._on_actor_entered.bind(actor_id, state, request_id), ConnectFlags.CONNECT_ONE_SHOT
	)
	temp_node.use_tween = true
	temp_node.visible = true
	temp_node.enter_actor(true, duration)
