---
title: Scene-based assets
order: 8
---

# Scene-based assets

Character and background entries now reference `PackedScene` resources. A scene may contain textures, video, Spine, Live2D, shaders, or custom nodes.

Character scenes should inherit `KND_CharacterSceneBase` and implement their states in `apply_state(state_name)`. Optional stage motion belongs in a `KND_ActorMotionLayer` scene whose `AnimationPlayer` animation names match KS motion names.

Background scenes should inherit `KND_BackgroundSceneBase`. Assign the scene to `background_scene`; add uniquely named `KonadoCamera2D` nodes when camera commands are needed. Built-in transitions are handled by `KND_BackgroundTransitionLayer`.

Configure the corresponding `character_scene` or `background_scene` in the resource list. Keep node paths stable and make scene roots fill their parent when they are UI-based.
