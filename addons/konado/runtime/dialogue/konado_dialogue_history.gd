extends RefCounted
class_name KonadoDialogueHistory

## Bounded, session-scoped dialogue, choice, and screen-text history (backlog) for one manager.
##
## 该服务与 KonadoDialogueManager 的原子事务一一对应：stage 暂存当前对话指令，
## 只有事务被 VM 成功提交时才 commit 落库，事务取消或失败时 discard 整体失效。
## 它不参与存档快照，因此 KonadoSaveData / KonadoRuntimeState 的 schema 不受影响。

signal entry_committed(entry: Dictionary)
signal cleared

## 回滚策略：KEEP 保留全部历史；TRIM 与 VM 时间线严格一致（回滚后裁剪）。
enum RollbackPolicy { KEEP, TRIM }

const DEFAULT_MAX_ENTRIES := 256
const MAX_MAX_ENTRIES := 4096

var max_entries := DEFAULT_MAX_ENTRIES
var rollback_policy := RollbackPolicy.TRIM

var _entries: Array[Dictionary] = []
var _pending_token: Dictionary = {}
var _pending_entry: Dictionary = {}


## 暂存当前事务将要显示的对话行。使用单槽位，新的 stage 会覆盖遗留的旧事务。
func stage(token: Dictionary, entry: Dictionary) -> void:
	if token.is_empty() or entry.is_empty():
		return
	_pending_token = token.duplicate(true)
	_pending_entry = entry.duplicate(true)


## 仅当暂存事务与传入 token 一致时提交，保证每条对话恰好落库一次。
func commit(token: Dictionary, serial := 0) -> bool:
	if _pending_token.is_empty() or _pending_token != token:
		return false
	var entry := _pending_entry.duplicate(true)
	entry["serial"] = serial
	entry["pending"] = false
	_pending_token.clear()
	_pending_entry.clear()
	_append(entry)
	return true


## 丢弃暂存事务。传入空 token 时无条件丢弃，用于取消与失败路径。
func discard(token: Dictionary = {}) -> void:
	if _pending_token.is_empty():
		return
	if not token.is_empty() and _pending_token != token:
		return
	_pending_token.clear()
	_pending_entry.clear()


func has_pending() -> bool:
	return not _pending_entry.is_empty()


## 返回按时间正序排列的条目副本；include_pending 会把尚未推进的当前行附加在末尾。
func entries(limit := 0, include_pending := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start := 0 if limit <= 0 or limit >= _entries.size() else _entries.size() - limit
	for index in range(start, _entries.size()):
		result.append(_entries[index].duplicate(true))
	if include_pending and not _pending_entry.is_empty():
		var pending := _pending_entry.duplicate(true)
		pending["serial"] = 0
		pending["pending"] = true
		result.append(pending)
	return result


func size() -> int:
	return _entries.size()


func clear() -> void:
	if _pending_token.is_empty() and _entries.is_empty():
		return
	_pending_token.clear()
	_pending_entry.clear()
	_entries.clear()
	cleared.emit()


## 裁剪到 VM 提交序号边界；serial <= 0 表示没有可靠边界，等价于整表清空。
func truncate_after(serial: int) -> void:
	if serial <= 0:
		clear()
		return
	var kept: Array[Dictionary] = []
	for entry in _entries:
		if int(entry.get("serial", 0)) <= serial:
			kept.append(entry)
	if kept.size() == _entries.size():
		return
	_entries = kept


func _append(entry: Dictionary) -> void:
	var capacity := clampi(max_entries, 0, MAX_MAX_ENTRIES)
	if capacity <= 0:
		return
	_entries.append(entry)
	while _entries.size() > capacity:
		_entries.remove_at(0)
	entry_committed.emit(entry.duplicate(true))
