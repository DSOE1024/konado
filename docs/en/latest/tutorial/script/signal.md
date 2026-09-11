---
title: Signal
order: 6
---

# Signal

## Description

A custom signal in a dialogue scene. It can be used for almost any operation.

## Syntax

```text
signal <custom signal instruction>
```

## Parameters
| Parameter | Required | Example | Description |
|------|------|------|------|
| Custom signal instruction | Yes | affection_up | Specific instruction |

## Example
```text
# Example
signal affection_up
signal affection_down
signal set_affection_gold 50
```

## Rollback behavior

A `signal` is a **replayable** one-shot side effect: a dialogue rollback may cross it, and playback re-emits it when it passes the instruction again, so a branch the player re-picks re-runs its handler.

- If the handler only touches **snapshot** state (script variables, camera, actors, background, audio, UI), rollback plus replay lands on exactly the same result as a fresh playthrough (the demo's `signal affection_up` → `%love + 1` is this case);
- If the handler touches state **outside** the snapshot (singletons, external saves, custom Resources), it must be idempotent;
- Achievement commands (`achievement unlock` / `increment` / `set_flag`) are external counters: they are **never replayed**, so an achievement is not recorded twice.

See "Variables and side effects" in [Dialogue Rollback (Previous Line)](../core/dialogue-rollback.md).
