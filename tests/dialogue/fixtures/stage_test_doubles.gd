extends RefCounted


class FakeActor:
	extends KonadoActor

	var requested_statuses: Array[String] = []
	var last_transition_duration := -1.0
	var next_result := true
	var before_status_applied := Callable()
	var delay_next_move := false
	var delay_next_status := false
	var validation_result := true
	var validation_count := 0
	var validation_results: Array[bool] = []
	var before_status_validation := Callable()
	var fake_move_in_progress := false
	var fake_move_serial := 0
	var fake_position_request_serial := 0
	var fake_framing: StringName = &"default"
	var fake_framing_serial := 0

	func _submit_character_status_request(
		status_name: String, transition_duration: float = 0.0, completion: Callable = Callable()
	) -> bool:
		requested_statuses.append(status_name)
		last_transition_duration = transition_duration
		var hook := before_status_applied
		before_status_applied = Callable()
		if hook.is_valid():
			hook.call()
		if delay_next_status:
			delay_next_status = false
			_finish_fake_status.call_deferred(status_name, completion, next_result)
			return true
		_finish_fake_status(status_name, completion, next_result)
		return true

	func _finish_fake_status(status_name: String, completion: Callable, succeeded: bool) -> void:
		if succeeded:
			actor_status_applied.emit(status_name)
		if completion.is_valid():
			completion.call(succeeded)

	func set_stage_position(
		target_h_division: int, target_position: int, _duration: float = 0.0
	) -> bool:
		fake_position_request_serial += 1
		var next_division := clampi(target_h_division, 2, 5)
		var next_position := clampi(target_position, 0, next_division)
		if horizontal_division == next_division and horizontal_position == next_position:
			return false
		fake_move_serial += 1
		var request_serial := fake_move_serial
		_suspend_layout_update = true
		horizontal_division = next_division
		horizontal_position = next_position
		_suspend_layout_update = false
		if not delay_next_move:
			fake_move_in_progress = false
			if slot != null:
				actor_moved.emit()
			return true
		delay_next_move = false
		fake_move_in_progress = true
		_emit_fake_move.call_deferred(request_serial)
		return true

	func _emit_fake_move(request_serial: int) -> void:
		if request_serial != fake_move_serial:
			return
		fake_move_in_progress = false
		actor_moved.emit()

	func _is_stage_position_moving() -> bool:
		return fake_move_in_progress

	func _get_stage_position_request_serial() -> int:
		return fake_position_request_serial

	func get_actor_framing() -> StringName:
		return fake_framing

	func get_actor_framing_ids() -> PackedStringArray:
		return PackedStringArray(["default", "close"])

	func has_actor_framing(preset_id: StringName) -> bool:
		return preset_id in [&"default", &"close"]

	func apply_actor_framing(
		preset_id: StringName,
		_duration: float = -1.0,
		_transition: String = "",
		completion: Callable = Callable(),
	) -> bool:
		if not restore_actor_framing(preset_id):
			return false
		if completion.is_valid():
			completion.call(true, "")
		return true

	func restore_actor_framing(preset_id: StringName) -> bool:
		if preset_id not in [&"default", &"close"]:
			return false
		fake_framing = preset_id
		fake_framing_serial += 1
		return true

	func _get_actor_framing_request_serial() -> int:
		return fake_framing_serial

	func _can_apply_character_status(_status_name: String) -> bool:
		validation_count += 1
		var hook := before_status_validation
		before_status_validation = Callable()
		if hook.is_valid():
			hook.call()
		if not validation_results.is_empty():
			return validation_results.pop_front()
		return validation_result


class DeferredActor:
	extends KonadoActor

	var saved_completion := Callable()

	func _submit_character_status_request(
		_status_name: String, _transition_duration: float = 0.0, completion: Callable = Callable()
	) -> bool:
		saved_completion = completion
		return true

	func _can_apply_character_status(_status_name: String) -> bool:
		return true


class FakeStageController:
	extends KonadoStageController

	func _init() -> void:
		_actor_layer = Control.new()
		add_child(_actor_layer)
		_konado_actor_template = (
			load("res://addons/konado/templates/default/character/character_template.tscn")
			as PackedScene
		)

	func apply_background_tint_to_actors() -> void:
		pass
