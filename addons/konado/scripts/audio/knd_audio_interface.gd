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

## BGM播放器
@export var bgm_player: AudioStreamPlayer
## 对话播放器
@export var voice_player: AudioStreamPlayer
## 音效播放器
@export var sound_effect_player: AudioStreamPlayer


## 播放BGM的方法（循环播放）
func play_bgm(audio: AudioStream, audio_id: String) -> void:
	if not bgm_player:
		push_error("没找到bgm_player")
		finish_playbgm.emit()
		return
	if bgm_player.is_playing():
		bgm_player.stop()
	bgm_player.stream = audio
	bgm_player.play()
	finish_playbgm.emit()
	bgm_player.finished.connect(func():
		bgm_player.play())
		
	
## 停止播放BGM的方法
func stop_bgm() -> void:
	if not bgm_player:
		push_error("没找到bgm_player")
		return
	if bgm_player.is_playing():
		bgm_player.stop()


## 播放语音的方法
func play_voice(audio: AudioStream) -> void:
	if not voice_player:
		push_error("没找到voice_player")
		finish_playvoice.emit()
		return
	if voice_player.is_playing():
		voice_player.stop()
	voice_player.stream=audio
	voice_player.play()
	finish_playvoice.emit()
	await voice_player.finished
	voice_finish_playing.emit()

## 停止播放语音的方法
func stop_voice() -> void:
	if not voice_player:
		push_error("没找到voice_player")
		return
	voice_player.stop()

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
