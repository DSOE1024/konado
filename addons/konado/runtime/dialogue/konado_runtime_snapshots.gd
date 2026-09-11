extends RefCounted
class_name KonadoRuntimeSnapshots

## 有界的“可显示行”运行时快照存储。
##
## 回退时按快照精确恢复镜头、角色、背景、音频与界面状态，避免依赖逐指令增量
## 累加导致的漂移（异步镜头、带过渡的演出等在提交时机的状态并不可靠）。

const DEFAULT_CAPACITY := 128
const DEFAULT_BYTES_CAPACITY := 4 * 1024 * 1024

## 保留的最大行数；超出后按“最近访问”顺序淘汰最久未访问的一行。
var capacity := DEFAULT_CAPACITY
## 保留的最大估算字节数，与 KonadoVirtualMachine 的历史/检查点预算保持同一纪律，
## 避免超长剧本或超大状态把快照缓存撑成无上限内存。
var bytes_capacity := DEFAULT_BYTES_CAPACITY

var _snapshots: Dictionary = {}
var _order := PackedStringArray()
var _bytes_total := 0


func store(key: String, state: Dictionary) -> void:
	if key.is_empty() or state.is_empty():
		return
	if not _snapshots.has(key):
		_order.append(key)
	else:
		# 回读到某一行会刷新它的位置：淘汰顺序按“最近访问”，回退窗口才跟着玩家的阅读前进。
		_bytes_total -= KonadoStateDelta.estimate_bytes(_snapshots[key])
		var position := _order.find(key)
		if position >= 0:
			_order.remove_at(position)
		_order.append(key)
	_snapshots[key] = state
	_bytes_total += KonadoStateDelta.estimate_bytes(state)
	# 至少保留最新一行：单行超预算时只丢历史行，不把回退整条关掉。
	while (
		_order.size() > 1
		and (_order.size() > maxi(1, capacity) or _bytes_total > maxi(1, bytes_capacity))
	):
		_drop_oldest()


func has(key: String) -> bool:
	return _snapshots.has(key)


## 返回内部快照。调用方只读，KonadoRuntimeState 的校验与恢复不会修改它。
func get_snapshot(key: String) -> Dictionary:
	return _snapshots.get(key, {})


func size() -> int:
	return _snapshots.size()


func bytes_used() -> int:
	return _bytes_total


func clear() -> void:
	_snapshots.clear()
	_order.clear()
	_bytes_total = 0


func _drop_oldest() -> void:
	var oldest := _order[0]
	_order.remove_at(0)
	_bytes_total -= KonadoStateDelta.estimate_bytes(_snapshots.get(oldest, {}))
	_snapshots.erase(oldest)
