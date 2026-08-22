@tool
extends Control

## Stable actor-local composition layer. Motions live above this node and the
## character scene lives below it, so neither operation overwrites framing.

const TRANSITIONS := [&"linear", &"ease_in", &"ease_out", &"ease_in_out"]

var current_preset_id: StringName = &"default"
var target_preset_id: StringName = &"default"
var framing_pivot := Vector2(0.5, 0.5):
	set(value):
		framing_pivot = value
		pivot_offset = _pivot_pixels(value)

var _profile: KonadoActorFramingProfile
var _active_tween: Tween
var _completion: Callable
var _request_serial := 0


func _ready() -> void:
	resized.connect(_on_resized)
	if _profile == null:
		_profile = KonadoActorFramingProfile.create_builtin()
	# A custom motion layer can be fully configured before it enters SceneTree.
	# Preserve that validated state instead of silently resetting it in _ready().
	var initial_preset_id := (
		current_preset_id
		if _profile.has_preset(current_preset_id)
		else _profile.get_default_preset_id()
	)
	apply_immediately(initial_preset_id)


func set_profile(profile: KonadoActorFramingProfile) -> bool:
	var candidate := profile if profile != null else KonadoActorFramingProfile.create_builtin()
	if not candidate.validate().is_empty():
		return false
	var previous_completion := _take_active_completion()
	_profile = candidate
	var next_id := (
		current_preset_id
		if candidate.has_preset(current_preset_id)
		else candidate.default_preset_id
	)
	var preset := candidate.get_preset(next_id)
	if preset == null:
		return false
	target_preset_id = next_id
	_apply_transform(preset)
	current_preset_id = next_id
	_request_serial += 1
	_notify(previous_completion, false, "profile_changed")
	return true


func has_preset(preset_id: StringName) -> bool:
	return _profile != null and _profile.has_preset(preset_id)


func get_preset_ids() -> PackedStringArray:
	return _profile.get_preset_ids() if _profile != null else PackedStringArray()


func get_default_preset_id() -> StringName:
	return _profile.get_default_preset_id() if _profile != null else &"default"


func can_apply(
	preset_id: StringName, duration_override: float = -1.0, transition_override: String = ""
) -> bool:
	if _profile == null:
		_profile = KonadoActorFramingProfile.create_builtin()
	return (
		_profile.has_preset(preset_id)
		and is_finite(duration_override)
		and (duration_override >= 0.0 or is_equal_approx(duration_override, -1.0))
		and (transition_override.is_empty() or StringName(transition_override) in TRANSITIONS)
	)


func apply(
	preset_id: StringName,
	duration_override: float = -1.0,
	transition_override: String = "",
	completion: Callable = Callable(),
) -> bool:
	if not can_apply(preset_id, duration_override, transition_override):
		return false
	var preset := _profile.get_preset(preset_id)
	if preset == null:
		return false
	var previous_completion := _take_active_completion()
	target_preset_id = preset_id
	_completion = completion
	_request_serial += 1
	var request_serial := _request_serial
	# Install this request before notifying the superseded one. A listener may
	# synchronously start a newer request, which must remain the final owner.
	_notify(previous_completion, false, "superseded")
	if request_serial != _request_serial:
		return true
	var duration := preset.transition_duration if duration_override < 0.0 else duration_override
	if duration <= 0.0 or not is_inside_tree():
		_apply_transform(preset)
		current_preset_id = preset_id
		_finish(true, "")
		return true

	var tween := create_tween()
	_active_tween = tween
	_configure_tween(tween, preset, transition_override)
	# Pivot participates in the interpolation, preventing a discontinuity when
	# close-ups use a face-biased focal point.
	tween.set_parallel(true)
	tween.tween_property(self, "position", preset.offset, duration)
	tween.tween_property(self, "scale", Vector2.ONE * preset.scale, duration)
	tween.tween_property(self, "framing_pivot", preset.pivot, duration)
	tween.set_parallel(false)
	tween.tween_callback(_complete_tween.bind(tween, preset_id))
	return true


func apply_immediately(preset_id: StringName) -> bool:
	if _profile == null:
		_profile = KonadoActorFramingProfile.create_builtin()
	var preset := _profile.get_preset(preset_id)
	if preset == null:
		return false
	var previous_completion := _take_active_completion()
	target_preset_id = preset_id
	_apply_transform(preset)
	current_preset_id = preset_id
	_request_serial += 1
	_notify(previous_completion, false, "restored")
	return true


func cancel(reason := "cancelled") -> void:
	var completion := _take_active_completion()
	_request_serial += 1
	_notify(completion, false, reason)


func complete(reason := "") -> void:
	if not _has_active_request():
		return
	var completion := _take_active_completion()
	_snap_to_target()
	_request_serial += 1
	_notify(completion, true, reason)


## Cancel the asynchronous request while keeping the accepted logical target and
## the rendered actor in sync. Shot boundaries use this deterministic endpoint so
## save/restore never observes a transient Tween frame as a stable composition.
func settle_to_target(reason := "cancelled") -> void:
	if not _has_active_request():
		return
	var completion := _take_active_completion()
	_snap_to_target()
	_request_serial += 1
	_notify(completion, false, reason)


func _apply_transform(preset: KonadoActorFramingPreset) -> void:
	position = preset.offset
	scale = Vector2.ONE * preset.scale
	framing_pivot = preset.pivot


func _pivot_pixels(normalized_pivot: Vector2) -> Vector2:
	return size * normalized_pivot


func _configure_tween(
	tween: Tween, preset: KonadoActorFramingPreset, transition_override: String
) -> void:
	if transition_override.is_empty():
		tween.set_trans(preset.transition_type)
		tween.set_ease(preset.ease_type)
		return
	match transition_override:
		"linear":
			tween.set_trans(Tween.TRANS_LINEAR)
			tween.set_ease(Tween.EASE_IN_OUT)
		"ease_in":
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN)
		"ease_out":
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
		_:
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN_OUT)


func _complete_tween(tween: Tween, preset_id: StringName) -> void:
	if _active_tween != tween:
		return
	_active_tween = null
	var preset := _profile.get_preset(preset_id) if _profile != null else null
	if preset != null:
		# Finish on the exact resource values. This also recomputes the pivot from
		# the latest slot size if the viewport changed during the transition.
		_apply_transform(preset)
	current_preset_id = preset_id
	_finish(true, "")


func _take_active_completion() -> Callable:
	_stop_tween()
	var completion := _completion
	_completion = Callable()
	return completion


func _has_active_request() -> bool:
	return _active_tween != null or _completion.is_valid()


func _stop_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _snap_to_target() -> void:
	var preset := _profile.get_preset(target_preset_id) if _profile != null else null
	if preset == null:
		return
	_apply_transform(preset)
	current_preset_id = target_preset_id


func _notify(completion: Callable, succeeded: bool, reason: String) -> void:
	if completion.is_valid():
		completion.call(succeeded, reason)


func _finish(succeeded: bool, reason: String) -> void:
	if not _completion.is_valid():
		return
	var callback := _completion
	_completion = Callable()
	callback.call(succeeded, reason)


func _on_resized() -> void:
	if _profile == null:
		return
	# The profile stores a normalized composition pivot. Keep its pixel-space
	# representation correct even while the viewport is resized mid-transition.
	pivot_offset = _pivot_pixels(framing_pivot)
