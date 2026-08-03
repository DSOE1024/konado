---
title: 음성 재생 API
order: 4
---

# 음성 재생 API

`KND_AudioInterface`는 GDScript에서 음성을 재생하고, 재생 완료를 기다리거나 재생을 중지할 수 있는 런타임 API를 제공합니다.

## 오디오 인터페이스 가져오기

스크립트에서 `KND_AudioInterface` 참조를 내보낸 다음 Inspector에서 대화 장면의 `KonadoAudioInterface` 노드를 할당합니다.

```gdscript
@export var audio_interface: KND_AudioInterface
@export var voice: AudioStream
```

## 비차단 재생

`play_voice()`는 재생을 시작한 뒤 음성이 끝날 때까지 기다리지 않고 즉시 반환합니다.

```gdscript
audio_interface.play_voice(voice)
```

이미 다른 음성이 재생 중이면 새 음성이 기존 음성을 대체합니다.

## 재생 후 완료 기다리기

재생 결과를 기다려야 할 때는 `play_voice_and_wait()`를 사용합니다.

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("음성이 자연스럽게 재생 완료됨")
else:
	print("음성이 중지 또는 교체되었거나 재생을 시작하지 못함")
```

반환값:

| 값 | 의미 |
|---|---|
| `true` | 음성이 자연스럽게 재생 완료됨 |
| `false` | `stop_voice()`로 중지됨, 새 음성으로 교체됨 또는 재생을 시작하지 못함 |

## 재생 중지

```gdscript
audio_interface.stop_voice()
```

## 자연 재생 완료 감지

`voice_finish_playing` 신호는 음성이 자연스럽게 재생 완료된 경우에만 발생합니다. 재생이 중지되거나 다른 음성으로 교체되면 발생하지 않습니다.

```gdscript
func _ready() -> void:
	audio_interface.voice_finish_playing.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("음성이 자연스럽게 재생 완료됨")
```
