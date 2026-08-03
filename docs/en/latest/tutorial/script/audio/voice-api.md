---
title: Voice Playback API
order: 4
---

# Voice Playback API

`KND_AudioInterface` provides runtime APIs for playing voice audio, waiting for playback, and stopping playback from GDScript.

## Getting the audio interface

Export a `KND_AudioInterface` reference and assign the dialogue scene's `KonadoAudioInterface` node to it in the Inspector:

```gdscript
@export var audio_interface: KND_AudioInterface
@export var voice: AudioStream
```

## Non-blocking playback

`play_voice()` starts playback and returns immediately:

```gdscript
audio_interface.play_voice(voice)
```

If another voice is already playing, the new voice replaces it.

## Playing and waiting

Use `play_voice_and_wait()` when you need the playback result:

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("Voice playback completed naturally")
else:
	print("Voice playback was stopped, replaced, or could not start")
```

Return values:

| Value | Meaning |
|---|---|
| `true` | The voice completed naturally |
| `false` | The voice was stopped with `stop_voice()`, replaced by another voice, or could not start |

## Stopping playback

```gdscript
audio_interface.stop_voice()
```

## Listening for natural completion

The `voice_finish_playing` signal is emitted only when playback completes naturally. It is not emitted when playback is stopped or replaced:

```gdscript
func _ready() -> void:
	audio_interface.voice_finish_playing.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("Voice playback completed naturally")
```
