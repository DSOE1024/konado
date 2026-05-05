---
title: Typewriter Sound Effect
order: 6
---

# Typing Sound Effect

## Overview

Konado's dialogue box component supports typewriter sound effects, playing a "click" sound while typing to enhance immersion and feedback.

## Sound Directory

Typewriter sound effect files are stored in the following directory:

```
res://addons/konado/audioeffect/typewriter/
```

## Supported Audio Formats

| Format | Description |
|--------|-------------|
| `.wav` | Uncompressed audio, recommended |
| `.ogg` | Ogg Vorbis compressed format |
| `.mp3` | MP3 compressed format |

## Basic Configuration

In the `KND_DialogueBox` component's Inspector panel, you can find the typewriter sound effect settings:

### Sound Toggle

```gdscript
@export var enable_typing_effect_audio: bool = true
```

Set to `true` to enable the typewriter sound effect, `false` to disable it.

### Audio Resource

```gdscript
@export var typing_effect_audio: AudioStream
```

Select a sound effect file from the editor dropdown menu, or load it via code:

```gdscript
# Set sound effect via code
dialogue_box.typing_effect_audio = load("res://addons/konado/audioeffect/typewriter/click.wav")
```

## Sound Trigger Configuration

### Trigger Probability

```gdscript
@export var audio_trigger_chance: float = 0.8
```

Controls the probability of triggering the sound effect, ranging from 0.0 to 1.0:

- `1.0` — Always plays
- `0.8` — 80% chance of playing (default)
- `0.5` — 50% chance of playing
- `0.0` — Never plays

### Play Interval

```gdscript
@export var min_audio_interval: float = 0.02   # Minimum interval (seconds)
@export var max_audio_interval: float = 0.08   # Maximum interval (seconds)
```

The random interval range for sound effect playback, used to match different typing rhythms:

- **Fast clicking**: Set a smaller interval, e.g. `0.02 – 0.05`
- **Slow typing**: Set a larger interval, e.g. `0.05 – 0.15`

After each playback, a new random interval value is generated between the minimum and maximum values.

### Volume Control

```gdscript
@export var audio_volumn: float = 0.6
```

Sound effect volume, ranging from 0.0 to 1.0:

- `1.0` — Maximum volume
- `0.6` — 60% volume (default)
- `0.0` — Silent

## Usage Examples

### Basic Usage

1. Place your sound effect files in the `res://addons/konado/audioeffect/typewriter/` directory
2. Select the `KND_DialogueBox` node in your scene
3. In the Inspector, enable `Enable Typing Effect Audio`
4. Select a sound effect file from the dropdown menu
5. Adjust the volume and other parameters

### Via Code

```gdscript
# Get the dialogue box instance
var dialogue_box = $KND_DialogueBox

# Enable sound effect
dialogue_box.enable_typing_effect_audio = true

# Set sound effect
dialogue_box.typing_effect_audio = load("res://addons/konado/audioeffect/typewriter/my_click.wav")

# Set trigger probability (always play)
dialogue_box.audio_trigger_chance = 1.0

# Set volume
dialogue_box.audio_volumn = 0.8

# Set play interval
dialogue_box.min_audio_interval = 0.02
dialogue_box.max_audio_interval = 0.06
```

## Recommended Sound Effects

### Typewriter Clicking

Best suited for fast,密集 typing effects. Use a smaller interval:

```
min_audio_interval: 0.02
max_audio_interval: 0.05
audio_trigger_chance: 0.8
```

### Mechanical Keyboard

Best suited for games with a strong typing feel:

```
min_audio_interval: 0.03
max_audio_interval: 0.08
audio_trigger_chance: 0.9
```

### Gentle Click

Best suited for casual, relaxing game atmospheres:

```
min_audio_interval: 0.05
max_audio_interval: 0.12
audio_trigger_chance: 0.7
audio_volumn: 0.5
```

## Sound Trigger Timing

The typewriter sound effect is triggered under the following conditions:

1. **During typing animation playback** — While dialogue text is being revealed character by character
2. **When the time since the last playback exceeds the random interval** — Prevents sounds from being too密集
3. **When the random probability check passes** — Based on the `audio_trigger_chance` setting
4. **When text has not yet been fully displayed** — Does not trigger if all text is already visible

## Notes

1. **Sound file naming** — Use English names and avoid special characters
2. **Sound duration** — Sound effects under 0.1 seconds work best
3. **Volume balance** — Ensure typing sounds do not overpower the background music
4. **Mobile platforms** — Use compressed formats (ogg/mp3) on mobile devices to save space
5. **Sound synchronisation** — Sound effects are automatically synchronised with typing progress

## Performance Optimisation

- Use short sound files (< 100 KB)
- Prefer `.ogg` format (better compression)
- Avoid playing multiple identical sound instances simultaneously
- Set `enable_typing_effect_audio = false` to disable when sound is not needed

## Troubleshooting

### No Sound Effect Playing

1. Check that `enable_typing_effect_audio` is set to `true`
2. Check that `typing_effect_audio` is correctly configured
3. Verify that the sound effect file path exists
4. Check if the volume is set to 0

### Sound Plays Too Frequently

1. Increase the values of `min_audio_interval` and `max_audio_interval`
2. Reduce the `audio_trigger_chance` value

### Sound Plays Too Infrequently

1. Decrease the values of `min_audio_interval` and `max_audio_interval`
2. Increase the `audio_trigger_chance` value
