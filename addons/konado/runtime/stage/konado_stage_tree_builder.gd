extends RefCounted

## Builds and repairs the stable visual layer hierarchy used by the stage.


static func ensure(host: Control, current: Dictionary, transition_script: Script) -> Dictionary:
	var background := current.get("background") as ColorRect
	var background_container := current.get("background_container") as Control
	var background_transition_layer := current.get("background_transition_layer") as Control
	var actor_layer := current.get("actor_layer") as Control
	var effect_layer := current.get("effect_layer") as ColorRect

	if background == null:
		background = ColorRect.new()
		background.name = "BackgroundLayer"
		background.color = Color.BLACK
		host.add_child(background)
	elif background.get_parent() != host:
		_reparent(background, host)
	if background_container == null:
		background_container = Control.new()
		background_container.name = "BackgroundContainer"
		background.add_child(background_container)
	elif background_container.get_parent() != background:
		_reparent(background_container, background)

	if background_transition_layer == null:
		background_transition_layer = transition_script.new() as Control
		background_transition_layer.name = "BackgroundTransitionLayer"
		host.add_child(background_transition_layer)
	elif background_transition_layer.get_parent() != host:
		_reparent(background_transition_layer, host)

	if actor_layer == null:
		actor_layer = host.get_node_or_null("BackgroundLayer/ActorLayer") as Control
	if actor_layer == null:
		actor_layer = Control.new()
		actor_layer.name = "ActorLayer"
		host.add_child(actor_layer)
	elif actor_layer.get_parent() != host:
		_reparent(actor_layer, host)

	if effect_layer == null:
		effect_layer = ColorRect.new()
		effect_layer.name = "EffectLayer"
		effect_layer.color = Color(0, 0, 0, 0)
		host.add_child(effect_layer)
	elif effect_layer.get_parent() != host:
		_reparent(effect_layer, host)

	for node in [
		background,
		background_container,
		background_transition_layer,
		actor_layer,
		effect_layer,
	]:
		KonadoStageUtilities.set_full_rect(node)

	# Layer order is a runtime invariant: background -> transition -> actors -> overlay.
	if background.get_parent() == host:
		host.move_child(background, 0)
	if background_transition_layer.get_parent() == host:
		host.move_child(background_transition_layer, mini(1, host.get_child_count() - 1))
	if actor_layer.get_parent() == host:
		host.move_child(actor_layer, mini(2, host.get_child_count() - 1))
	if effect_layer.get_parent() == host:
		host.move_child(effect_layer, host.get_child_count() - 1)

	return {
		"background": background,
		"background_container": background_container,
		"background_transition_layer": background_transition_layer,
		"actor_layer": actor_layer,
		"effect_layer": effect_layer,
	}


static func _reparent(node: Node, parent: Node) -> void:
	var current_parent := node.get_parent()
	if current_parent != null:
		current_parent.remove_child(node)
	parent.add_child(node)
