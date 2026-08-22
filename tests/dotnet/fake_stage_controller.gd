extends RefCounted

var last_actor_framing: Dictionary = {}
var last_actor_framings: Dictionary = {}


func set_actor_framing(
	actor_id: String, preset_id: StringName, duration := -1.0, transition := ""
) -> bool:
	last_actor_framing = {
		"actor_id": actor_id,
		"preset_id": String(preset_id),
		"duration": duration,
		"transition": transition,
	}
	return true


func set_actor_framings(framings: Dictionary, duration := -1.0, transition := "") -> bool:
	last_actor_framings = {
		"framings": framings.duplicate(true),
		"duration": duration,
		"transition": transition,
	}
	return true
