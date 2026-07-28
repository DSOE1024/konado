---
title: Change Actor State
order: 4
---

# Change Actor State

## Description
Switch the state of the specified actor. By default, Konado fades out the current state, applies the new state, fades it in, and resumes the story after the transition finishes.

## Syntax

```text
actor change <character name> <new state>
```

## Parameters

| Parameter | Required | Example | Description |
|------|------|------|------|
| Character | Yes | kona | Name of the actor whose state should be changed |
| New state | Yes | happy | New state to switch to |

## Example

```text
actor change kona happy
```

## State transition

The default `actor change` sequence is:

1. Fade out the current actor.
2. Apply the new state to the character scene.
3. Fade in the actor with the new state.
4. Continue with the next story command after the transition finishes.

Configure the transition in the Inspector for the `KND_ActingInterface` node:

| Property | Default | Description |
|------|------|------|
| `enable_actor_state_fade` | `true` | Enables the fade transition for actor state changes |
| `actor_state_fade_duration` | `0.3` | Total transition duration in seconds; fade-out and fade-in each use half |

Disable `enable_actor_state_fade` or set `actor_state_fade_duration` to `0` to switch states immediately.

The transition fades the stable character mount and does not duplicate the character scene, so the same flow supports textures, video, Spine, Live2D, and custom character scenes. If the target actor is missing or its scene cannot apply the state, Konado completes the command and continues the story instead of waiting indefinitely.
