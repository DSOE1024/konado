extends Control

@export var dialogue_manager: KND_DialogueManager

func _ready() -> void:
	dialogue_manager.custom_signal.connect(_on_konado_dialogue_manager_play_sfx)

# 这一部分非插件内容，为demo演示所需
func _on_konado_dialogue_manager_play_sfx(content: Variant) -> void:
	if content == "好感度上升":
		$KonadoDialogueManager.dialogue_variables["love"] += 1
