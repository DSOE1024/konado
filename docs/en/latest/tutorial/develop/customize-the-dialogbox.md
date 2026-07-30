---
title: Custom Dialogue Box
order: 4
---

# Custom Dialogue Interface

## Introduction

To customize the dialogue interface, first copy the selected template scene into your project's own directory, such as `res://ui/dialogue/`. Edit that copy or assign it a custom Godot theme.

Do not edit files under `res://addons/konado/` directly; plugin upgrades replace the plugin directory. A project-owned copy remains safe when Konado is upgraded.

## Edit Template Files

`res://addons/konado/template/` contains the built-in dialogue templates. Copy the required `.tscn` into your project, instantiate the copy in your dialogue scene, and assign its `KND_DialogueBox` node to the `_konado_dialogue_box` property of `KND_DialogueManager`.

In general, do not modify scripts on nodes. Prefer changing node properties to achieve customization.

## Customize Voice Progress

When a regular dialogue line has a voice tag and its audio is playing, the dialogue box displays playback progress. It hides the indicator when no voice is assigned, the resource cannot be resolved, or playback ends. Disable `show_voice_progress` on the `KonadoDialogueBox` node if the project does not need it.

The built-in component source is `res://addons/konado/template/default/voice_progress_display.tscn`. Copy it into the project before changing its colors, corner radii, dimensions, or node structure, then reference that copy from the customized dialogue box. A complete replacement should preserve this interface:

```gdscript
func set_progress(current: float, total: float) -> void
func hide_progress() -> void
```
