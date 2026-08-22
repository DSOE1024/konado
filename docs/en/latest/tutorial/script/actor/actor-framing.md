---
title: Actor Framing
order: 5
---

# Actor Framing

Actor framing changes the scale, offset, and composition pivot of one actor. It does not move the background, other actors, or the stage camera. Use `cam` to move the whole stage and actor framing to change one actor's apparent distance within that stage; both systems can be combined.

## Built-in framings

Konado provides `default`, `full`, `medium`, `close`, and `extreme_close`. Portrait dimensions and face positions vary, so production projects should assign a dedicated `KonadoActorFramingProfile` to each character that needs custom composition.

## KonadoScript

Set the initial framing when showing an actor:

```text
actor show Kona normal at 3 [framing=medium]
```

Transition an actor that is already on stage:

```text
actor framing Kona close [duration=0.4] [transition=ease_in_out]
```

`transition` accepts `linear`, `ease_in`, `ease_out`, or `ease_in_out`. The command waits by default. Use `[wait=false]` to continue immediately and compose multiple actors in the same moment:

```text
actor framing Kona close [duration=0.4] [wait=false]
actor framing Mia medium [duration=0.4] [wait=false]
```

Framing is persistent actor state. It survives state changes, motions, saves, loads, and story rollback. A newer framing request safely supersedes an unfinished one.

## Custom presets

Create a `KonadoActorFramingProfile` resource in Godot, add `KonadoActorFramingPreset` entries, and assign it to the character definition's `actor_framing_profile`. Each preset defines an ID, scale, pixel offset, normalized composition pivot, and default transition timing and easing.

## Calling from code

GDScript can frame one actor or validate and start a multi-actor batch:

```gdscript
dialogue_manager.stage_controller.set_actor_framing("Kona", &"close", 0.4, "ease_in_out")
dialogue_manager.stage_controller.set_actor_framings({"Kona": "close", "Mia": "medium"}, 0.4)
```

The batch API validates every actor and preset before applying any change. Konado.NET exposes the matching `SetActorFraming()` and `SetActorFramings()` methods.
