extends Resource
class_name KonadoActorFramingPreset

## A named, actor-local composition. The transform is applied to the stable
## framing layer and therefore survives character state changes and motions.

@export var preset_id: StringName = &"default":
	set(value):
		if preset_id == value:
			return
		preset_id = value
		emit_changed()
@export_range(0.05, 8.0, 0.01, "or_greater") var scale: float = 1.0:
	set(value):
		if is_equal_approx(scale, value):
			return
		scale = value
		emit_changed()
## Offset in the project's design-space pixels.
@export var offset: Vector2 = Vector2.ZERO:
	set(value):
		if offset.is_equal_approx(value):
			return
		offset = value
		emit_changed()
## Normalized pivot inside the actor slot. Values outside 0..1 are supported
## for deliberately off-canvas compositions.
@export var pivot: Vector2 = Vector2(0.5, 0.5):
	set(value):
		if pivot.is_equal_approx(value):
			return
		pivot = value
		emit_changed()
@export_range(0.0, 10.0, 0.01, "or_greater") var transition_duration: float = 0.3:
	set(value):
		if is_equal_approx(transition_duration, value):
			return
		transition_duration = value
		emit_changed()
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE:
	set(value):
		if transition_type == value:
			return
		transition_type = value
		emit_changed()
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT:
	set(value):
		if ease_type == value:
			return
		ease_type = value
		emit_changed()


func is_valid() -> bool:
	return (
		not preset_id.is_empty()
		and is_finite(scale)
		and scale > 0.0
		and offset.is_finite()
		and pivot.is_finite()
		and is_finite(transition_duration)
		and transition_duration >= 0.0
		and transition_type >= Tween.TRANS_LINEAR
		and transition_type <= Tween.TRANS_SPRING
		and ease_type >= Tween.EASE_IN
		and ease_type <= Tween.EASE_OUT_IN
	)


func duplicate_preset() -> KonadoActorFramingPreset:
	var copy := KonadoActorFramingPreset.new()
	copy.preset_id = preset_id
	copy.scale = scale
	copy.offset = offset
	copy.pivot = pivot
	copy.transition_duration = transition_duration
	copy.transition_type = transition_type
	copy.ease_type = ease_type
	return copy
