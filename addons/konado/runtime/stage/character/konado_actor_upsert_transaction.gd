extends RefCounted

## Coordinates an existing actor's state, stage position and framing as one
## operation. A rejected state restores only values still owned by this request,
## so independent newer movement/framing commands are never overwritten.

const STAGE_FAILURE_REPORTER := preload(
	"res://addons/konado/runtime/stage/konado_stage_failure_reporter.gd"
)

var _host: Variant


func _init(host: Variant) -> void:
	_host = host


func execute(
	actor: KonadoActor,
	actor_id: String,
	horizontal_division: int,
	horizontal_position: int,
	state: String,
	duration: float,
	report_errors: bool,
	request_id: int,
	framing_id: StringName,
) -> void:
	var had_previous_actor_state: bool = _host.actor_states.has(actor_id)
	var previous_actor_state: Dictionary = (
		_host.actor_states[actor_id].duplicate(true) if had_previous_actor_state else {}
	)
	var previous_state := ""
	if had_previous_actor_state:
		previous_state = str(previous_actor_state.get("state", ""))
	var previous_horizontal_division := actor.horizontal_division
	var previous_horizontal_position := actor.horizontal_position
	var previous_framing := actor.get_actor_framing()

	var next_horizontal_division := clampi(horizontal_division, 2, 5)
	var next_horizontal_position := clampi(horizontal_position, 0, next_horizontal_division)
	var position_changed := (
		actor.horizontal_division != next_horizontal_division
		or actor.horizontal_position != next_horizontal_position
	)
	var movement_in_progress := actor._is_stage_position_moving()
	# A running transition must be explicitly superseded even if its committed
	# source state happens to equal this request's target.
	var state_changed: bool = previous_state != state or _host._actor_pending_states.has(actor_id)

	_host.actor_instances[actor_id] = actor
	var next_actor_state: Dictionary = previous_actor_state.duplicate(true)
	(
		next_actor_state
		. merge(
			{
				"id": actor_id,
				"horizontal_division": next_horizontal_division,
				"horizontal_position": next_horizontal_position,
				"state": previous_state,
				"framing": String(previous_framing),
			},
			true,
		)
	)
	var framing_changed := false
	if not framing_id.is_empty():
		if not actor.restore_actor_framing(framing_id):
			_reject_missing_framing(actor, actor_id, framing_id, report_errors, request_id)
			return
		next_actor_state["framing"] = String(framing_id)
		framing_changed = framing_id != previous_framing
	if not state_changed:
		next_actor_state["state"] = state
	_host.actor_states[actor_id] = next_actor_state

	var waits := {
		"succeeded": true,
		"failure": {},
		"state_done": not state_changed,
		"movement_done":
		not (
			movement_in_progress
			or (
				position_changed
				and actor.slot != null
				and actor.use_tween
				and actor.animation_time > 0.0
			)
		),
		"finished": false,
	}
	var actor_ref := weakref(actor)
	var rollback_context := {
		"actor_ref": actor_ref,
		"actor_id": actor_id,
		"rolled_back": false,
		"position_changed": position_changed,
		"framing_changed": framing_changed,
		"framing_id": framing_id,
		"next_horizontal_division": next_horizontal_division,
		"next_horizontal_position": next_horizontal_position,
		"previous_horizontal_division": previous_horizontal_division,
		"previous_horizontal_position": previous_horizontal_position,
		"previous_framing": previous_framing,
		"next_actor_state": next_actor_state,
		"had_previous_actor_state": had_previous_actor_state,
		"previous_actor_state": previous_actor_state,
		"position_request_serial": -1,
		"framing_request_serial":
		actor._get_actor_framing_request_serial() if framing_changed else -1,
	}
	var rollback_if_current := _rollback_if_current.bind(rollback_context)
	var finish_if_ready := func() -> void:
		if waits.finished or not waits.state_done or not waits.movement_done:
			return
		waits.finished = true
		if _host.actor_states.has(actor_id) and waits.succeeded:
			var committed_state := str(_host.actor_states[actor_id].get("state", ""))
			print("复用已有演员：" + actor_id + " 演员状态：" + committed_state)
		else:
			waits.succeeded = false
		_host._emit_actor_shown(bool(waits.succeeded), request_id, waits.failure)

	var movement_exit_handler_ref := [Callable()]
	var movement_handler := func() -> void:
		waits.movement_done = true
		var active_actor := actor_ref.get_ref() as KonadoActor
		var movement_exit_handler: Callable = movement_exit_handler_ref[0]
		movement_exit_handler_ref[0] = Callable()
		if (
			active_actor != null
			and movement_exit_handler.is_valid()
			and active_actor.tree_exiting.is_connected(movement_exit_handler)
		):
			active_actor.tree_exiting.disconnect(movement_exit_handler)
		finish_if_ready.call()
	if not waits.movement_done:
		var movement_exit_handler := func() -> void:
			movement_exit_handler_ref[0] = Callable()
			if waits.movement_done:
				return
			waits.movement_done = true
			waits.succeeded = false
			waits.failure = _actor_removed_failure(actor_id)
			var active_actor := actor_ref.get_ref() as KonadoActor
			if active_actor != null and active_actor.actor_moved.is_connected(movement_handler):
				active_actor.actor_moved.disconnect(movement_handler)
			finish_if_ready.call()
		movement_exit_handler_ref[0] = movement_exit_handler
		actor.actor_moved.connect(movement_handler, ConnectFlags.CONNECT_ONE_SHOT)
		actor.tree_exiting.connect(movement_exit_handler, ConnectFlags.CONNECT_ONE_SHOT)
	if position_changed:
		var movement_started := actor.set_stage_position(
			next_horizontal_division, next_horizontal_position, duration
		)
		rollback_context.position_request_serial = actor._get_stage_position_request_serial()
		if not movement_started and not waits.movement_done:
			_disconnect_movement_wait(actor, movement_handler, movement_exit_handler_ref)
			waits.movement_done = true

	if state_changed:
		_host._request_actor_state(
			actor,
			actor_id,
			state,
			duration if duration >= 0.0 else 0.0,
			"显示角色失败：角色[%s]无法应用状态[%s]" % [actor_id, state],
			"actor.show",
			report_errors,
			func(succeeded: bool, actor_exited: bool, owned_request: bool) -> void:
				waits.succeeded = waits.succeeded and succeeded
				if not succeeded:
					if owned_request and not actor_exited:
						rollback_if_current.call()
					waits.failure = (
						_host._last_failure.duplicate(true)
						if owned_request
						else _host._operation_tracker().superseded_failure(
							"actor.show", "actor", actor_id
						)
					)
				if actor_exited:
					waits.movement_done = true
				waits.state_done = true
				finish_if_ready.call()
		)

	finish_if_ready.call()


func _reject_missing_framing(
	actor: KonadoActor,
	actor_id: String,
	framing_id: StringName,
	report_errors: bool,
	request_id: int,
) -> void:
	_host._last_failure = (
		STAGE_FAILURE_REPORTER
		. record_actor(
			&"stage.actor_framing_missing",
			"显示角色失败：角色[%s]没有景别[%s]" % [actor_id, framing_id],
			"actor.show",
			actor_id,
			report_errors,
			"可用景别=%s" % ", ".join(actor.get_actor_framing_ids()),
			true,
		)
	)
	_host._emit_actor_shown(false, request_id)


func _rollback_if_current(context: Dictionary) -> void:
	if context.rolled_back:
		return
	context.rolled_back = true
	var actor := (context.actor_ref as WeakRef).get_ref() as KonadoActor
	if actor == null or not is_instance_valid(actor):
		return
	var actor_id := String(context.actor_id)
	var current_state: Dictionary = _host.actor_states.get(actor_id, {})
	var owns_position: bool = (
		context.position_changed
		and actor._get_stage_position_request_serial() == context.position_request_serial
		and actor.horizontal_division == context.next_horizontal_division
		and actor.horizontal_position == context.next_horizontal_position
		and int(current_state.get("horizontal_division", -1)) == context.next_horizontal_division
		and int(current_state.get("horizontal_position", -1)) == context.next_horizontal_position
	)
	var owns_framing: bool = (
		context.framing_changed
		and actor._get_actor_framing_request_serial() == context.framing_request_serial
		and actor.get_actor_framing() == context.framing_id
		and StringName(current_state.get("framing", "")) == context.framing_id
	)
	if owns_position:
		actor.set_stage_position(
			context.previous_horizontal_division, context.previous_horizontal_position, 0.0
		)
	if owns_framing:
		actor.restore_actor_framing(context.previous_framing)
	if not _host.actor_states.has(actor_id):
		return
	if not context.had_previous_actor_state:
		# An actor without a prior logical record is an inconsistent but supported
		# host state. Remove only the exact synthetic record still wholly owned by
		# this transaction; otherwise preserve newer independent writes.
		if (
			current_state == context.next_actor_state
			and (not context.position_changed or owns_position)
			and (not context.framing_changed or owns_framing)
		):
			_host.actor_states.erase(actor_id)
		return
	var restored_state: Dictionary = _host.actor_states[actor_id].duplicate(true)
	# The state coordinator already proved that this request still owns the state
	# transition. Restore only fields this upsert introduced; never replace the
	# whole dictionary because newer subsystems may have committed other fields.
	for field: String in ["id", "state"]:
		if restored_state.get(field) != context.next_actor_state.get(field):
			continue
		if context.previous_actor_state.has(field):
			restored_state[field] = context.previous_actor_state[field]
		else:
			restored_state.erase(field)
	if owns_position:
		restored_state["horizontal_division"] = context.previous_actor_state.get(
			"horizontal_division", context.previous_horizontal_division
		)
		restored_state["horizontal_position"] = context.previous_actor_state.get(
			"horizontal_position", context.previous_horizontal_position
		)
	if owns_framing:
		restored_state["framing"] = context.previous_actor_state.get(
			"framing", String(context.previous_framing)
		)
	_host.actor_states[actor_id] = restored_state


func _disconnect_movement_wait(
	actor: KonadoActor, movement_handler: Callable, movement_exit_handler_ref: Array
) -> void:
	if actor.actor_moved.is_connected(movement_handler):
		actor.actor_moved.disconnect(movement_handler)
	var movement_exit_handler: Callable = movement_exit_handler_ref[0]
	movement_exit_handler_ref[0] = Callable()
	if movement_exit_handler.is_valid() and actor.tree_exiting.is_connected(movement_exit_handler):
		actor.tree_exiting.disconnect(movement_exit_handler)


func _actor_removed_failure(actor_id: String) -> Dictionary:
	return {
		"code": "stage.actor_node_removed",
		"message": "显示角色失败：角色[%s]在操作完成前离开舞台" % actor_id,
		"subsystem": "stage",
		"operation": "actor.show",
		"resource_kind": "actor",
		"resource_id": actor_id,
	}
