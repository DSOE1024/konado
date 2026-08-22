extends RefCounted

## Owns validation, request correlation and prevalidated multi-actor framing.
## The stage controller remains the public boundary while this coordinator keeps
## actor-local composition independent from the global camera implementation.

const TRANSITIONS := [&"linear", &"ease_in", &"ease_out", &"ease_in_out"]

var _host: Variant


func _init(host: Variant) -> void:
	_host = host


func set_actor(
	actor_id: String,
	preset_id: StringName,
	duration: float,
	transition: String,
	report_errors: bool,
	request_id: int,
) -> bool:
	_host._last_failure.clear()
	var actor := _host.get_actor(actor_id) as KonadoActor
	var validation := _validate_request(actor, actor_id, preset_id, duration, transition)
	if not validation.is_empty():
		_reject(validation, actor_id, preset_id, report_errors, request_id)
		return false

	_host._operation_tracker().register_actor_framing(actor_id, String(preset_id), request_id)
	var previous_framing := actor.get_actor_framing()
	_host.actor_states[actor_id]["framing"] = String(preset_id)
	var completion := _complete_actor.bind(actor_id, preset_id, request_id)
	if actor.apply_actor_framing(preset_id, duration, transition, completion):
		return true

	_host._operation_tracker().take_actor_framing(actor_id, request_id)
	actor.restore_actor_framing(previous_framing)
	_host.actor_states[actor_id]["framing"] = String(previous_framing)
	var failure := {
		"code": &"stage.actor_framing_failed",
		"message": "调整演员景别失败：角色[%s]无法应用景别[%s]" % [actor_id, preset_id],
		"cause": "",
	}
	_reject(failure, actor_id, preset_id, report_errors, request_id)
	return false


func set_actors(
	framings: Dictionary, duration: float, transition: String, report_errors: bool
) -> bool:
	_host._last_failure.clear()
	if framings.is_empty():
		return true
	var validation := _validate_batch(framings, duration, transition)
	if not validation.is_empty():
		_reject_batch(validation, report_errors)
		return false

	var previous_framings: Dictionary[String, StringName] = {}
	for actor_value: Variant in framings:
		var actor_id := String(actor_value)
		previous_framings[actor_id] = _host.get_actor(actor_id).get_actor_framing()

	var applied_actor_ids := PackedStringArray()
	for actor_value: Variant in framings:
		var actor_id := String(actor_value)
		if set_actor(actor_id, StringName(framings[actor_value]), duration, transition, false, 0):
			applied_actor_ids.append(actor_id)
			continue
		_rollback_batch(applied_actor_ids, previous_framings)
		return false
	return true


func configure_actor(
	actor: KonadoActor,
	profile: KonadoActorFramingProfile,
	requested_preset_id: StringName,
) -> Dictionary:
	if not actor.set_framing_profile(profile):
		return {
			"ok": false,
			"code": &"stage.actor_framing_profile_invalid",
			"message": "演员景别配置无效",
			"cause": "目标景别=%s" % requested_preset_id,
		}
	var preset_id := requested_preset_id
	if preset_id.is_empty():
		preset_id = actor.get_actor_framing()
	if actor.restore_actor_framing(preset_id):
		return {"ok": true, "preset_id": preset_id}
	return {
		"ok": false,
		"code": &"stage.actor_framing_missing",
		"message": "没有景别[%s]" % preset_id,
		"cause": "可用景别=%s" % ", ".join(actor.get_actor_framing_ids()),
	}


func _validate_batch(framings: Dictionary, duration: float, transition: String) -> Dictionary:
	var shared_validation := _validate_options(duration, transition)
	if not shared_validation.is_empty():
		shared_validation["batch"] = true
		return shared_validation
	var actor_ids := {}
	for actor_value: Variant in framings:
		var validation := _validate_batch_entry(
			framings, actor_value, actor_ids, duration, transition
		)
		if not validation.is_empty():
			validation["batch"] = true
			return validation
	return {}


func _validate_batch_entry(
	framings: Dictionary,
	actor_value: Variant,
	actor_ids: Dictionary,
	duration: float,
	transition: String,
) -> Dictionary:
	if typeof(actor_value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return {
			"code": &"stage.actor_framing_batch_invalid",
			"message": "演员 ID 必须是 String 或 StringName",
			"cause": "收到类型=%s" % type_string(typeof(actor_value)),
			"reason": "actor_id_invalid",
		}
	var actor_id := String(actor_value)
	if actor_id.is_empty():
		return {
			"code": &"stage.actor_framing_batch_invalid",
			"message": "演员 ID 不能为空",
			"reason": "actor_id_invalid",
		}
	if actor_ids.has(actor_id):
		return {
			"code": &"stage.actor_framing_batch_invalid",
			"message": "演员 ID 重复：%s" % actor_id,
			"reason": "actor_id_duplicate",
		}
	actor_ids[actor_id] = true
	var preset_value: Variant = framings[actor_value]
	if typeof(preset_value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return {
			"code": &"stage.actor_framing_batch_invalid",
			"message": "角色[%s]的景别必须是 String 或 StringName" % actor_id,
			"cause": "收到类型=%s" % type_string(typeof(preset_value)),
			"reason": "preset_id_invalid",
		}
	return _validate_request(
		_host.get_actor(actor_id), actor_id, StringName(preset_value), duration, transition
	)


func _validate_request(
	actor: KonadoActor,
	actor_id: String,
	preset_id: StringName,
	duration: float,
	transition: String,
) -> Dictionary:
	if actor == null:
		return {
			"code": &"stage.actor_not_present",
			"message": "角色ID[%s]不在舞台上" % actor_id,
			"cause": "目标景别=%s" % preset_id,
			"reason": "actor_not_present",
		}
	if not _host.actor_states.has(actor_id):
		return {
			"code": &"stage.actor_state_missing",
			"message": "角色[%s]缺少舞台状态记录" % actor_id,
			"cause": "目标景别=%s" % preset_id,
			"reason": "actor_state_missing",
		}
	if preset_id.is_empty() or not actor.has_actor_framing(preset_id):
		return {
			"code": &"stage.actor_framing_missing",
			"message": "角色[%s]没有景别[%s]" % [actor_id, preset_id],
			"cause": "可用景别=%s" % ", ".join(actor.get_actor_framing_ids()),
			"reason": "preset_missing",
		}
	return _validate_options(duration, transition)


func _validate_options(duration: float, transition: String) -> Dictionary:
	if not is_finite(duration) or (duration < 0.0 and not is_equal_approx(duration, -1.0)):
		return {
			"code": &"stage.actor_framing_duration_invalid",
			"message": "duration 必须为 -1 或非负有限数值",
			"cause": "duration=%s" % duration,
			"reason": "duration_invalid",
		}
	if not transition.is_empty() and StringName(transition) not in TRANSITIONS:
		return {
			"code": &"stage.actor_framing_transition_invalid",
			"message": "不支持过渡类型[%s]" % transition,
			"cause": "可用过渡=%s" % ", ".join(TRANSITIONS),
			"reason": "transition_invalid",
		}
	return {}


func _reject(
	failure: Dictionary,
	actor_id: String,
	preset_id: StringName,
	report_errors: bool,
	request_id: int,
) -> void:
	var message := "调整演员景别失败：%s" % String(failure.get("message", "未知错误"))
	_host._last_failure = (
		KonadoStageFailureReporter
		. record_actor(
			StringName(failure.get("code", &"stage.actor_framing_failed")),
			message,
			"actor.framing",
			actor_id,
			report_errors,
			String(failure.get("cause", "")),
		)
	)
	_host._operation_tracker().complete(request_id, false, _host._last_failure)
	_host.actor_framing_changed.emit(
		actor_id, String(preset_id), false, String(failure.get("reason", "apply_failed"))
	)


func _reject_batch(failure: Dictionary, report_errors: bool) -> void:
	_host._last_failure = (
		KonadoStageFailureReporter
		. record(
			StringName(failure.get("code", &"stage.actor_framing_failed")),
			"调整多演员景别失败：%s" % String(failure.get("message", "未知错误")),
			"actor.framings",
			"actor",
			"",
			report_errors,
			String(failure.get("cause", "")),
		)
	)


func _complete_actor(
	succeeded: bool,
	reason: String,
	actor_id: String,
	preset_id: StringName,
	request_id: int,
) -> void:
	var owned_request: bool = (
		request_id <= 0
		or _host._operation_tracker().take_actor_framing(actor_id, request_id) == request_id
	)
	if not owned_request:
		# Request ownership controls the atomic runtime completion only. Public
		# observers still receive one terminal event for every accepted transition.
		_host.actor_framing_changed.emit(actor_id, String(preset_id), false, reason)
		return
	var failure := {}
	if not succeeded:
		failure = (
			_host._operation_tracker().superseded_failure("actor.framing", "actor", actor_id)
			if reason == "superseded"
			else {
				"code": "stage.actor_framing_cancelled",
				"message": "演员景别操作已取消",
				"subsystem": "stage",
				"operation": "actor.framing",
				"resource_kind": "actor",
				"resource_id": actor_id,
				"cause": reason,
			}
		)
	_host._operation_tracker().complete(request_id, succeeded, failure)
	_host.actor_framing_changed.emit(actor_id, String(preset_id), succeeded, reason)


func _rollback_batch(
	applied_actor_ids: PackedStringArray,
	previous_framings: Dictionary[String, StringName],
) -> void:
	for actor_id in applied_actor_ids:
		var actor := _host.get_actor(actor_id) as KonadoActor
		if actor == null:
			continue
		var previous_id: StringName = previous_framings[actor_id]
		actor.restore_actor_framing(previous_id)
		if _host.actor_states.has(actor_id):
			_host.actor_states[actor_id]["framing"] = String(previous_id)
