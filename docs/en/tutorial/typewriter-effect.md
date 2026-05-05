---
title: Typewriter Effect
order: 5
---

# Typewriter Effect

## Overview

Konado provides a powerful typewriter effect component with GPU-accelerated character-by-character fade-in, bringing your game's dialogue to life.

## Core Features

- **GPU-accelerated rendering** — Uses a dedicated shader for per-character rendering with excellent performance
- **BBCode rich text support** — Supports bold, italic, colour, underline and strikethrough
- **Multiple fade-in directions** — Set fade-in direction at any angle
- **Spatial blend** — Mix character order and spatial order for fade-in effects
- **CJK multilingual support** — Full support for Chinese, Japanese, Korean and other multi-byte characters

## Basic Usage

### Using in a Dialogue Box

In the `KND_DialogueBox` component, you can enable the typewriter effect directly:

1. Select the `KND_DialogueBox` node in your scene
2. Find the relevant settings in the Inspector panel
3. Enable typewriter mode

### Using via Code

```gdscript
# Get the typewriter component
var typewriter = $KND_TypewriterText

# Set the text to display (supports BBCode)
typewriter.set_bbcode("[color=yellow]Hello[/color], [b]player[/b]!")

# Start the typewriter effect manually
typewriter.start()

# Skip the typewriter effect, show all text immediately
typewriter.skip()

# Reset, hiding all text
typewriter.reset()
```

## BBCode Rich Text

### Supported Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `[b]` | Bold | `[b]bold text[/b]` |
| `[i]` | Italic | `[i]italic text[/i]` |
| `[u]` | Underline | `[u]underlined text[/u]` |
| `[s]` | Strikethrough | `[s]strikethrough text[/s]` |
| `[color=colour]` | Text colour | `[color=red]red text[/color]` |
| `[font=font]` | Specify font | `[font=my_font]custom font[/font]` |

### Colour Examples

```bbcode
[color=#FF5733]orange text[/color]
[color=green]green text[/color]
[color=#3498db]blue text[/color]
[color=yellow]yellow text[/color]
```

## Fade-in Effect Configuration

### Fade Angle

Sets the directional angle of character fade-in:

- `0°` — Left to right (default)
- `90°` — Top to bottom
- `-90°` — Bottom to top
- `180°` — Right to left
- Any angle value — Custom direction

### Spatial Blend

Controls the blend between character order and spatial position:

- `0.0` — Strictly in character order
- `0.5` — Blended mode
- `1.0` — Strictly by spatial position

### Softness

Controls the softness of the fade-in effect. Higher values produce softer edges.

## Signals

The typewriter component provides the following signals for monitoring state changes:

| Signal | Description |
|--------|-------------|
| `typewriter_started` | Emitted when the typewriter effect begins |
| `typewriter_finished` | Emitted when the typewriter effect completes |
| `typewriter_skipped` | Emitted when the typewriter effect is skipped |
| `character_revealed(index)` | Emitted when each character is revealed; index is the character index |

### Signal Usage Example

```gdscript
func _ready():
    var typewriter = $KND_TypewriterText
    typewriter.typewriter_started.connect(_on_typewriter_started)
    typewriter.typewriter_finished.connect(_on_typewriter_finished)
    typewriter.character_revealed.connect(_on_character_revealed)

func _on_typewriter_started():
    print("Typewriter effect started!")

func _on_typewriter_finished():
    print("Typewriter effect finished!")

func _on_character_revealed(index: int):
    print("Character revealed: ", index)
```

## API Reference

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `bbcode_text` | String | "" | BBCode text to display |
| `font` | Font | null | Custom font |
| `font_size` | int | 20 | Font size |
| `font_color` | Color | WHITE | Text colour |
| `chars_per_second` | float | 25.0 | Characters revealed per second |
| `fade_width` | float | 3.0 | Fade-in width |
| `fade_angle` | float | 0.0 | Fade-in angle (degrees) |
| `spatial_blend` | float | 0.15 | Spatial blend ratio |
| `auto_start` | bool | true | Whether to start automatically |

### Methods

| Method | Description |
|--------|-------------|
| `start()` | Begin the typewriter effect |
| `skip()` | Skip and show all text immediately |
| `reset()` | Reset and hide all text |
| `set_bbcode(text, autoplay)` | Set BBCode text |
| `is_playing()` | Whether the effect is currently playing |
| `is_finished()` | Whether the effect has finished |
| `get_progress()` | Get the current progress |

## Advanced Usage

### Custom Typing Speed

```gdscript
# Fast display
typewriter.chars_per_second = 100.0

# Slow typing for atmosphere
typewriter.chars_per_second = 5.0
```

### Custom Fade-in Effect

```gdscript
# Set fade-in direction (45-degree angle)
typewriter.fade_angle = 45.0

# Set softness
typewriter.fade_width = 5.0

# Set spatial blend
typewriter.spatial_blend = 0.5
```

### Listening for Typewriter Completion

```gdscript
func _ready():
    var typewriter = $KND_TypewriterText
    typewriter.typewriter_finished.connect(_on_finished)

func _on_finished():
    # Perform actions after typing completes
    show_continue_button()
```

## Performance Optimisation

- GPU shader rendering for excellent performance
- Handles large amounts of text without stuttering
- On mobile platforms, consider reducing `chars_per_second`

## Notes

1. **BBCode tags must be paired** — Ensure every opening tag has a corresponding closing tag
2. **Colour values can be customised** — Supports hex colour codes such as `#FF5733`
3. **Editor preview** — When running in the editor, text is displayed in full for easy previewing
4. **Line breaks** — Use `\n` for line breaks
