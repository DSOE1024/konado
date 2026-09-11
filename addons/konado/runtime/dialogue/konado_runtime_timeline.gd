extends RefCounted
class_name KonadoRuntimeTimeline

## Owns execution history, checkpoints, and portable runtime snapshots for one manager.

## 玩家需要确认的“可显示行”指令：台词、选项、全屏文本。
const DISPLAYABLE_OPCODES := [
	KonadoOpcode.Type.DIALOGUE,
	KonadoOpcode.Type.CHOICE,
	KonadoOpcode.Type.SCREEN_TEXT,
]
## “上一句”回退的边界：仅镜头结束（end/halt）。jump 属于 CHECKPOINT，可跨越并回到上一剧本。
const STEP_BACK_BOUNDARY_OPCODES := [KonadoOpcode.Type.HALT]

var _host_ref: WeakRef
var _shot_program_cache: Dictionary = {}
var _snapshots := KonadoRuntimeSnapshots.new()
var _pending_snapshot: Dictionary = {}


func _init(host: KonadoDialogueManager) -> void:
	_host_ref = weakref(host)


func can_rollback(steps := 1, allow_barriers := false) -> bool:
	var host := _host()
	return host != null and host._vm.can_rollback(steps, true, allow_barriers)


## 回退到 `steps` 条指令之前。use_snapshot=true 时按目标行的完整快照恢复场景，
## 避免逐指令增量累加导致的镜头/角色漂移（用于“上一句”回退）。
func rollback(steps := 1, allow_barriers := false, use_snapshot := false) -> bool:
	var host := _host()
	if host == null:
		return false
	var recovering_failure := host._failure_controller()._has_pending()
	if not host._vm.can_rollback(steps, true, allow_barriers):
		return false
	if not recovering_failure:
		_cancel_active_presentation(host)
	var snapshot := _target_snapshot(steps) if use_snapshot else {}
	# 保存并恢复现场：恢复过程中若有回调再次触发回退，嵌套调用不会打乱外层的目标快照。
	var previous_pending := _pending_snapshot
	_pending_snapshot = snapshot
	var ok := host._vm.rollback(steps, _restore_runtime_state, recovering_failure, allow_barriers)
	_pending_snapshot = previous_pending
	if not ok:
		if not recovering_failure or not host._vm._last_failed_restore_preserved_state():
			host._enter_safe_off_state()
		return false
	if not snapshot.is_empty():
		# 让 VM 的累计状态与精确快照对齐，后续增量才不会基于漂移值计算。
		host._vm.synchronize_state(snapshot)
	_resume_restored_timeline(KonadoRuntimeFailureSession.RESOLUTION_ROLLBACK)
	return true


## 回退/恢复前取消进行中的演出。选项展示不属于快照状态，必须显式移除，
## 否则从选项退回更早的台词时按钮会残留在画面上。
func _cancel_active_presentation(host: KonadoDialogueManager) -> void:
	host._cancel_active_instruction()
	if host.choice_controller != null:
		host.choice_controller.distroy_options()


func create_checkpoint(label := "") -> String:
	var host := _host()
	return (
		host._vm.create_checkpoint(label, KonadoRuntimeState.capture(host)) if host != null else ""
	)


func restore_checkpoint(checkpoint_id: String) -> bool:
	var host := _host()
	if host == null:
		return false
	var recovering_failure := host._failure_controller()._has_pending()
	if not host._vm._can_restore_checkpoint(checkpoint_id, true):
		return false
	if not recovering_failure:
		_cancel_active_presentation(host)
	var ok := host._vm.restore_checkpoint(checkpoint_id, _restore_runtime_state, recovering_failure)
	if not ok:
		if not recovering_failure or not host._vm._last_failed_restore_preserved_state():
			host._enter_safe_off_state()
		return false
	_resume_restored_timeline(KonadoRuntimeFailureSession.RESOLUTION_RESTORE_CHECKPOINT)
	return true


func execution_history(limit := 0) -> Array[Dictionary]:
	var host := _host()
	return host._vm.history(limit) if host != null else []


func clear_execution_history() -> void:
	var host := _host()
	if host != null:
		host._vm.clear_history()
		# 行快照只服务于这段执行历史，历史清空后一并释放，避免残留键继续占内存。
		_snapshots.clear()


## 在每个可显示行开始前记录完整快照，供“上一句”回退精确恢复场景。
func remember_line(instruction: KonadoInstruction) -> void:
	var host := _host()
	if host == null or instruction == null:
		return
	if not (instruction.opcode() in DISPLAYABLE_OPCODES):
		return
	var source_path := host._vm.program.source_path if host._vm.program != null else ""
	var key := _snapshot_key(source_path, instruction.stable_key())
	_snapshots.store(key, KonadoRuntimeState.capture(host))


## 返回到上一句需要回退的已提交指令数；0 表示当前无法回退（与 can_step_back() 一致）。
func previous_dialogue_steps() -> int:
	return int(_step_back_target().get("steps", 0))


func can_step_back() -> bool:
	return not _step_back_target().is_empty()


## 原子回退到上一句：按该行快照精确恢复场景，并在同一帧内同步重放，避免闪出更早的画面。
func step_back() -> bool:
	return _perform_step_back(_step_back_target())


## Backlog 条目（按 VM 提交序号定位）是否可以作为回退落点。
func can_rollback_to_entry(serial: int) -> bool:
	return not _entry_step_back_target(serial).is_empty()


## 回退到 Backlog 记录中的某一句；跨剧本、不可逆副作用跳过等语义与「上一句」完全一致。
func rollback_to_entry(serial: int) -> bool:
	return _perform_step_back(_entry_step_back_target(serial))


## 「上一句」与 Backlog 跳转共用的回退执行体：落点已校验，这里只做原子回退 + 同帧重放。
func _perform_step_back(target: Dictionary) -> bool:
	var host := _host()
	if target.is_empty() or host == null:
		return false
	var steps := int(target.get("steps", 0))
	var skipped := _barrier_keys(steps)
	if not rollback(steps, true, true):
		return false
	host._vm._prepare_rewind_skips(skipped)
	host._pump()
	return true


## 返回当前可用的上一句落点（{steps, key}）；{} 表示此刻不可回退。
## 校验与执行共用同一份结果，避免“先判定可用、再重新定位”之间出现状态分歧。
func _step_back_target() -> Dictionary:
	var host := _host()
	if host == null or host._failure_controller()._has_pending():
		return {}
	var line := _previous_line()
	if line.is_empty() or not _snapshots.has(String(line.get("key", ""))):
		return {}
	return line if can_rollback(int(line.get("steps", 0)), true) else {}


## 把 Backlog 的提交序号换算成回退落点；只有仍在执行历史中、属于可显示行、
## 且留有快照的条目可回退（当前未提交的行序号为 0，因此天然被拒绝）。
func _entry_step_back_target(serial: int) -> Dictionary:
	var host := _host()
	if host == null or serial <= 0 or host._failure_controller()._has_pending():
		return {}
	var records := execution_history(0)
	for index in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[index]
		if int(record.get("serial", 0)) != serial:
			continue
		if not (int(record.get("opcode", -1)) in DISPLAYABLE_OPCODES):
			return {}
		var source_path := String(record.get("source_path", ""))
		var key := _snapshot_key(source_path, String(record.get("key", "")))
		if not _snapshots.has(key):
			return {}
		var steps := records.size() - index
		return {"steps": steps, "key": key} if can_rollback(steps, true) else {}
	return {}


## 定位最近的上一句；返回 {steps, key}，{} 表示没有可回退的上一句或遇到剧本流边界。
## 选项不会改变对话框文本，它旁边那句台词其实还留在屏幕上：此时跳过该句，
## 否则玩家会点到一个“画面完全没有变化”的空白步。
func _previous_line() -> Dictionary:
	var records := execution_history(0)
	var skip_adjacent_line := _current_is_choice()
	var fallback := {}
	var displayable_count := 0
	for offset in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[offset]
		var opcode := int(record.get("opcode", -1))
		if opcode in DISPLAYABLE_OPCODES:
			displayable_count += 1
			var source_path := String(record.get("source_path", ""))
			var instruction_key := String(record.get("key", ""))
			var candidate := {
				"steps": records.size() - offset,
				"key": _snapshot_key(source_path, instruction_key),
			}
			# 至少保留一个落点：即使跳过了相邻句也不会让回退变成空操作。
			if fallback.is_empty():
				fallback = candidate
			if (
				skip_adjacent_line
				and displayable_count == 1
				and opcode == KonadoOpcode.Type.DIALOGUE
			):
				continue
			return candidate
		# 只有镜头结束构成边界；不可逆副作用允许被回退，但会在重放时跳过（见 _barrier_keys），
		# jump 也可以跨越并回到上一剧本（快照带有目标行的剧本信息）。
		if opcode in STEP_BACK_BOUNDARY_OPCODES:
			return fallback
	return fallback


## 当前是否停在选项上（选项展示不会改写对话框文本）。
func _current_is_choice() -> bool:
	var host := _host()
	if host == null:
		return false
	var instruction := host._current_instruction()
	return instruction != null and instruction.opcode() == KonadoOpcode.Type.CHOICE


func _target_snapshot(steps: int) -> Dictionary:
	var records := execution_history(steps)
	if records.is_empty():
		return {}
	var record := records[0]
	return _snapshots.get_snapshot(
		_snapshot_key(String(record.get("source_path", "")), String(record.get("key", "")))
	)


## 快照键带上剧本来源路径，避免不同剧本复用相同稳定键时误用旧快照。
func _snapshot_key(source_path: String, instruction_key: String) -> String:
	if instruction_key.is_empty():
		return ""
	return "%s|%s" % [source_path, instruction_key]


## 收集本次回退范围内已生效的不可逆指令键，供重放时跳过。
func _barrier_keys(steps: int) -> PackedStringArray:
	var keys := PackedStringArray()
	for record in execution_history(steps):
		if bool(record.get("barrier", false)):
			keys.append(
				"%s|%s" % [String(record.get("source_path", "")), String(record.get("key", ""))]
			)
	return keys


func capture_execution_snapshot() -> Dictionary:
	var host := _host()
	if (
		host == null
		or host.current_shot == null
		or host.current_shot.source_path.is_empty()
		or host.current_shot.source_path == "null"
		or host._vm.program == null
		or host._vm.pc == KonadoProgram.INVALID_PC
	):
		return {}
	var state := host._vm.snapshot_state()
	if state.is_empty():
		state = KonadoRuntimeState.capture(host)
	return {
		"execution":
		{
			"shot_path": host.current_shot.source_path,
			"program_fingerprint": host._vm.program.fingerprint(),
			"instruction_id": host._vm.program.key_for_pc(host._vm.pc),
		},
		"runtime_state": state,
	}


func restore_execution_snapshot(snapshot: Dictionary) -> bool:
	var host := _host()
	if host == null:
		return false
	var execution: Dictionary = snapshot.get("execution", {})
	var runtime_state: Dictionary = snapshot.get("runtime_state", {})
	var resolved := _resolve_snapshot_target(execution)
	if resolved.is_empty() or not KonadoRuntimeState.validate(runtime_state, host):
		return false
	var shot: KonadoShot = resolved.shot
	var pc := int(resolved.pc)
	var failure_report := host._failure_controller()._detach_pending_report()
	host._cancel_execution()
	host.current_shot = shot.duplicate() as KonadoShot
	if not host._vm.restore_boundary(host.current_shot.program, pc, runtime_state):
		host._enter_safe_off_state()
		_publish_snapshot_resolution(
			failure_report, KonadoRuntimeFailureSession.RESOLUTION_CANCELLED
		)
		return false
	if not KonadoRuntimeState.restore(runtime_state, host):
		host._enter_safe_off_state()
		_publish_snapshot_resolution(
			failure_report, KonadoRuntimeFailureSession.RESOLUTION_CANCELLED
		)
		return false
	host._shot_active = true
	host.dialogue_state = KonadoDialogueManager.DialogState.EXECUTING
	_publish_snapshot_resolution(
		failure_report, KonadoRuntimeFailureSession.RESOLUTION_RESTORE_SNAPSHOT
	)
	if host._shot_active and host.dialogue_state == KonadoDialogueManager.DialogState.EXECUTING:
		host._schedule_pump()
	return true


func remember_shot(shot: KonadoShot) -> void:
	if shot == null or shot.program == null or not shot.program.is_valid():
		return
	_shot_program_cache[shot.program_fingerprint()] = shot.duplicate() as KonadoShot


func _resume_restored_timeline(resolution: StringName) -> void:
	var host := _host()
	if host == null:
		return
	host._history_coordinator().trim_to_vm()
	var restored_program := host._vm.program
	var failure_report := host._failure_controller()._detach_pending_report()
	host._playback_generation += 1
	host._active_token.clear()
	host._cancel_pending_callbacks()
	host._shot_active = true
	host.dialogue_state = KonadoDialogueManager.DialogState.EXECUTING
	host._failure_controller()._publish_external_resolution(failure_report, resolution)
	if (
		host._shot_active
		and host.dialogue_state == KonadoDialogueManager.DialogState.EXECUTING
		and host._vm.program == restored_program
	):
		host._schedule_pump()


func _restore_runtime_state(state: Dictionary) -> bool:
	var host := _host()
	if host == null:
		return false
	# 优先使用目标行的完整快照；否则回退到增量重建的状态。
	var effective := _pending_snapshot if not _pending_snapshot.is_empty() else state
	var execution: Dictionary = effective.get("execution", {})
	var shot_path := String(execution.get("shot_path", ""))
	var expected_fingerprint := String(execution.get("program_fingerprint", ""))
	if expected_fingerprint.is_empty():
		return false
	var shot := _shot_program_cache.get(expected_fingerprint) as KonadoShot
	if shot == null and not shot_path.is_empty():
		shot = host._load_localized_shot(load(shot_path) as KonadoShot)
	if shot == null and not shot_path.is_empty() and FileAccess.file_exists(shot_path):
		shot = KonadoScriptCompiler.new().compile_file(shot_path)
	if (
		shot == null
		or not shot.ensure_script_ready()
		or shot.program == null
		or shot.program_fingerprint() != expected_fingerprint
		or host._vm.program == null
		or host._vm.program.fingerprint() != expected_fingerprint
	):
		return false
	var previous_shot := host.current_shot
	host.current_shot = shot.duplicate() as KonadoShot
	if not KonadoRuntimeState.restore(effective, host):
		host.current_shot = previous_shot
		return false
	return true


func _resolve_snapshot_target(execution: Dictionary) -> Dictionary:
	var host := _host()
	var shot_path := String(execution.get("shot_path", ""))
	if host == null or shot_path.is_empty() or not ResourceLoader.exists(shot_path):
		return {}
	var shot := host._load_localized_shot(load(shot_path) as KonadoShot)
	if shot == null or not shot.ensure_script_ready() or shot.program == null:
		return {}
	if shot.program.fingerprint() != String(execution.get("program_fingerprint", "")):
		return {}
	var pc := shot.pc_for_key(String(execution.get("instruction_id", "")))
	if pc == KonadoProgram.INVALID_PC:
		return {}
	return {"shot": shot, "pc": pc}


func _publish_snapshot_resolution(report: Dictionary, resolution: StringName) -> void:
	var host := _host()
	if host != null:
		host._failure_controller()._publish_external_resolution(report, resolution)


func _host() -> KonadoDialogueManager:
	return _host_ref.get_ref() as KonadoDialogueManager
