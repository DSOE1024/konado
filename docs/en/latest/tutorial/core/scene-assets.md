---
title: Scene-based assets
order: 8
---

# Scene-based assets

Character and background entries now reference `PackedScene` resources. A scene may contain textures, video, Spine, Live2D, shaders, or custom nodes.

Character scenes should inherit `KND_CharacterSceneBase` and override `_apply_status(resolved_status_name, original_status_name)`; the system calls it through `apply_status(status_name)`. By default, `actor change` fades the character mount out, applies the state, and fades it in without duplicating the character scene. Story execution resumes after the transition finishes. See [Change Actor State](../script/actor/actor-change-state.md) for configuration. Optional stage motion belongs in a `KND_ActorMotionLayer` scene whose `AnimationPlayer` animation names match KS motion names.

Background scenes should inherit `KND_BackgroundSceneBase`. Assign the scene to `background_scene`; add uniquely named `KonadoCamera2D` nodes when camera commands are needed. Built-in transitions are handled by `KND_BackgroundTransitionLayer`. Transitions capture the complete scene through `SubViewport` by default. Select `DIRECT_TEXTURE` only when the rendered background is exactly equivalent to one unmodified source texture; backgrounds with layout, transforms, cameras, animation, materials, tinting, or multiple drawables must keep `VIEWPORT_CAPTURE`.

Configure the corresponding `character_scene` or `background_scene` in the resource list. Keep node paths stable and make scene roots fill their parent when they are UI-based.
