extends Node
class_name KND_AudioInterface

## 音频接口类

## Bgm播放成功
signal finish_playbgm
## 语音播放成功
signal finish_playvoice
## 音效播放成功
signal finish_playsoundeffect

## 语音播放完成
signal voice_finish_playing


class VoicePlaybackWaiter:
	extends RefCounted

	signal settled(completed: bool)

	var result: Variant = null

	func settle(completed: bool) -> void:
		if result != null:
			return
		result = completed
		settled.emit(completed)


## BGM播放器
@export var bgm_player: AudioStreamPlayer
## 对话播放器
@export var voice_player: AudioStreamPlayer
## 音效播放器
@export var sound_effect_player: AudioStreamPlayer

## 设置桥接器引用
@export var _settings_bridge: KND_SettingsBridge

## 缓存的音量值
var _master_volume: float = 1.0
var _music_volume: float = 0.8
var _sfx_volume: float = 1.0
var _voice_volume: float = 1.0
var _bgm_loop_enabled: bool = false
var _connected_bgm_player: AudioStreamPlayer
var _connected_voice_player: AudioStreamPlayer
var _voice_playing: bool = false
var _voice_generation: int = 0
var _voice_waiters: Dictionary[int, VoicePlaybackWaiter] = {}


func _exit_tree() -> void:
	_bgm_loop_enabled = false
	_cancel_voice_playback()
	var pending_generations: Array[int] = []
	pending_generations.assign(_voice_waiters.keys())
	for generation: int in pending_generations:
		_settle_voice_playback(generation, false)
	_disconnect_audio_connections()


## 从设置更新音量
func _update_volume_from_settings() -> void:
	if _settings_bridge == null:
		return

	_master_volume = _settings_bridge.get_master_volume()
	_music_volume = _settings_bridge.get_music_volume()
	_sfx_volume = _settings_bridge.get_sfx_volume()
	_voice_volume = _settings_bridge.get_voice_volume()

	# 应用音量
	if bgm_player:
		bgm_player.volume_db = linear_to_db(_master_volume * _music_volume)
	if voice_player:
		voice_player.volume_db = linear_to_db(_master_volume * _voice_volume)
	if sound_effect_player:
		sound_effect_player.volume_db = linear_to_db(_master_volume * _sfx_volume)


## 设置变更处理
func _on_setting_changed(category: String, _key: String, _value: Variant) -> void:
	if category == "audio":
		_update_volume_from_settings()


## 将线性音量转换为分贝
func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


## 播放BGM的方法（循环播放）
func play_bgm(audio: AudioStream, _audio_id: String) -> void:
	if not bgm_player:
		push_error("没找到bgm_player")
		finish_playbgm.emit()
		return
	_ensure_bgm_connection()
	_bgm_loop_enabled = true
	if bgm_player.is_playing():
		bgm_player.stop()
	bgm_player.stream = audio
	bgm_player.play()
	finish_playbgm.emit()


## 停止播放BGM的方法
func stop_bgm() -> void:
	if not bgm_player:
		push_error("没找到bgm_player")
		return
	_bgm_loop_enabled = false
	if bgm_player.is_playing():
		bgm_player.stop()


## 非阻塞地开始播放语音。自然播放完成时发出 voice_finish_playing。
func play_voice(audio: AudioStream) -> void:
	_begin_voice_playback(audio, false)


## 播放并等待当前语音结束。
##
## 自然播放完成返回 true；被 stop_voice() 中断、被新语音替换或无法开始播放时返回 false。
func play_voice_and_wait(audio: AudioStream) -> bool:
	var generation := _begin_voice_playback(audio, true)
	if generation < 0:
		return false
	var waiter := _voice_waiters.get(generation)
	if waiter == null:
		return false
	if waiter.result != null:
		var immediate_result := bool(waiter.result)
		_voice_waiters.erase(generation)
		return immediate_result
	var result: bool = await waiter.settled
	_voice_waiters.erase(generation)
	return result


## 停止播放语音的方法
func stop_voice() -> void:
	if not voice_player and not is_instance_valid(_connected_voice_player):
		push_error("没找到voice_player")
	_cancel_voice_playback()


func _begin_voice_playback(audio: AudioStream, track_result: bool) -> int:
	var previous_generation := _voice_generation
	var had_previous_playback := _voice_playing
	_voice_generation += 1
	var generation := _voice_generation
	if track_result:
		_voice_waiters[generation] = VoicePlaybackWaiter.new()

	_voice_playing = false
	if had_previous_playback:
		_stop_connected_voice_player()
		_settle_voice_playback(previous_generation, false)
		if generation != _voice_generation:
			_settle_voice_playback(generation, false)
			return generation if track_result else -1

	if not voice_player:
		push_error("没找到voice_player")
		finish_playvoice.emit()
		_settle_voice_playback(generation, false)
		return generation if track_result else -1
	if audio == null:
		push_error("无法播放空的语音资源")
		finish_playvoice.emit()
		_settle_voice_playback(generation, false)
		return generation if track_result else -1

	_ensure_voice_connection()
	voice_player.stream = audio
	_voice_playing = true
	voice_player.play()
	finish_playvoice.emit()
	if not _did_voice_playback_start():
		_voice_playing = false
		_stop_connected_voice_player()
		_settle_voice_playback(generation, false)
	return generation


func _did_voice_playback_start() -> bool:
	return is_instance_valid(voice_player) and voice_player.playing


func _cancel_voice_playback() -> void:
	if not _voice_playing:
		if is_instance_valid(voice_player) and voice_player.is_playing():
			voice_player.stop()
		return
	var generation := _voice_generation
	_voice_playing = false
	_stop_connected_voice_player()
	_settle_voice_playback(generation, false)


func _stop_connected_voice_player() -> void:
	var player := (
		_connected_voice_player if is_instance_valid(_connected_voice_player) else voice_player
	)
	if is_instance_valid(player) and player.is_playing():
		player.stop()


func _settle_voice_playback(generation: int, completed: bool) -> void:
	var waiter := _voice_waiters.get(generation)
	if waiter == null:
		return
	waiter.settle(completed)


func _disconnect_audio_connections() -> void:
	if (
		is_instance_valid(_connected_bgm_player)
		and _connected_bgm_player.finished.is_connected(_on_bgm_player_finished)
	):
		_connected_bgm_player.finished.disconnect(_on_bgm_player_finished)
	if (
		is_instance_valid(_connected_voice_player)
		and _connected_voice_player.finished.is_connected(_on_voice_player_finished)
	):
		_connected_voice_player.finished.disconnect(_on_voice_player_finished)
	_connected_bgm_player = null
	_connected_voice_player = null


func _ensure_bgm_connection() -> void:
	if (
		_connected_bgm_player == bgm_player
		and _connected_bgm_player.finished.is_connected(_on_bgm_player_finished)
	):
		return
	if (
		is_instance_valid(_connected_bgm_player)
		and _connected_bgm_player.finished.is_connected(_on_bgm_player_finished)
	):
		_connected_bgm_player.finished.disconnect(_on_bgm_player_finished)
	_connected_bgm_player = bgm_player
	if not _connected_bgm_player.finished.is_connected(_on_bgm_player_finished):
		_connected_bgm_player.finished.connect(_on_bgm_player_finished)


func _ensure_voice_connection() -> void:
	if (
		_connected_voice_player == voice_player
		and _connected_voice_player.finished.is_connected(_on_voice_player_finished)
	):
		return
	if (
		is_instance_valid(_connected_voice_player)
		and _connected_voice_player.finished.is_connected(_on_voice_player_finished)
	):
		_connected_voice_player.finished.disconnect(_on_voice_player_finished)
	_connected_voice_player = voice_player
	if not _connected_voice_player.finished.is_connected(_on_voice_player_finished):
		_connected_voice_player.finished.connect(_on_voice_player_finished)


func _on_bgm_player_finished() -> void:
	if _bgm_loop_enabled and is_instance_valid(bgm_player) and bgm_player.stream != null:
		bgm_player.play()


func _on_voice_player_finished() -> void:
	if not _voice_playing:
		return
	var generation := _voice_generation
	_voice_playing = false
	voice_finish_playing.emit()
	_settle_voice_playback(generation, true)


## 播放音效的方法
func play_sound_effect(audio: AudioStream) -> void:
	if not sound_effect_player:
		push_error("没找到sound_effect_player")
		finish_playsoundeffect.emit()
		return
	sound_effect_player.stop()
	sound_effect_player.stream = audio
	sound_effect_player.play()
	finish_playsoundeffect.emit()
