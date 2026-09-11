extends RefCounted
class_name KonadoDialogueHistoryCoordinator

## 将对话、选项与全屏文本的记录绑定到 KonadoDialogueManager 的原子事务。
##
## 协调器持有唯一的 KonadoDialogueHistory，并在事务开始时暂存条目、在 VM 提交时落库、
## 在取消或失败时整体丢弃。所有副作用都通过 host 的当前 token 判定，因此不会出现
## 被取代事务的残留记录。

var _host_ref: WeakRef
var _history := KonadoDialogueHistory.new()


func _init(host: KonadoDialogueManager) -> void:
	_host_ref = weakref(host)


func history() -> KonadoDialogueHistory:
	return _history


func stage_dialogue(
	token: Dictionary, instruction: KonadoInstruction, speaker: String, content: String
) -> void:
	(
		_history
		. stage(
			token,
			{
				"kind": "dialogue",
				"speaker": speaker,
				"text": content,
				"instruction_id": instruction.stable_key(),
				"shot_path": _shot_path(),
				"line": instruction.source_line(),
			},
		)
	)


func stage_choice(token: Dictionary, instruction: KonadoInstruction, choice: Dictionary) -> void:
	if instruction == null:
		return
	var option_texts: Array[String] = []
	for option: Dictionary in instruction.value(&"options", []):
		option_texts.append(String(option.get("text", "")))
	(
		_history
		. stage(
			token,
			{
				"kind": "choice",
				"speaker": "",
				"text": String(choice.get("text", "")),
				"options": option_texts,
				"instruction_id": instruction.stable_key(),
				"shot_path": _shot_path(),
				"line": instruction.source_line(),
			},
		)
	)


func stage_screen_text(
	token: Dictionary, instruction: KonadoInstruction, lines: PackedStringArray
) -> void:
	(
		_history
		. stage(
			token,
			{
				"kind": "screen_text",
				"speaker": "",
				"text": "\n".join(lines),
				"lines": Array(lines),
				"instruction_id": instruction.stable_key(),
				"shot_path": _shot_path(),
				"line": instruction.source_line(),
			},
		)
	)


## 仅在暂存事务与传入 token 一致且 VM 已提交时落库。
func commit(token: Dictionary) -> void:
	if _history.has_pending():
		_history.commit(token, _last_commit_serial())


func discard() -> void:
	_history.discard()


func clear() -> void:
	_history.clear()


## 回滚或恢复检查点后，让历史与 VM 当前保留的时间线边界保持一致。
func trim_to_vm() -> void:
	if _history.rollback_policy != KonadoDialogueHistory.RollbackPolicy.TRIM:
		return
	_history.discard()
	_history.truncate_after(_last_commit_serial())


func _last_commit_serial() -> int:
	var host := _host_ref.get_ref() as KonadoDialogueManager
	if host == null:
		return 0
	var records := host._vm.history(1)
	return int(records[0].get("serial", 0)) if not records.is_empty() else 0


func _shot_path() -> String:
	var host := _host_ref.get_ref() as KonadoDialogueManager
	if host == null or host.current_shot == null:
		return ""
	return host.current_shot.source_path
