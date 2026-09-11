---
title: Dialogue Rollback (Previous Line)
order: 9
---

# Dialogue Rollback (Previous Line)

Dialogue rollback returns the player to the **previous** displayable line (dialogue, choice, or screen text) and resumes from there. The default dialogue template provides a "Back" button in the function bar.

## Runtime API

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

```gdscript
# Whether stepping back is possible (a reachable previous line exists)
var can: bool = dialogue_manager.timeline.can_step_back()

# Step back to the previous line; returns true on success
if dialogue_manager.timeline.can_step_back():
    dialogue_manager.timeline.step_back()

# How many committed instructions the step back needs (0 = not possible)
var steps: int = dialogue_manager.timeline.previous_dialogue_steps()

# Backlog entry rollback: entries carry the VM commit serial they belong to
var reachable: bool = dialogue_manager.timeline.can_rollback_to_entry(serial)
dialogue_manager.timeline.rollback_to_entry(serial)
```

## Atomicity

Rollback reuses the virtual machine's **reversible transaction rollback** and additionally restores the scene from the target line's **full snapshot** before replaying it deterministically. Throughout:

- the in-flight transaction (typing, voice, pending async work) is cancelled and its token invalidated;
- the snapshot restores the camera, actors, background, audio, UI and variables exactly, instead of relying on accumulated per-instruction deltas, so asynchronous camera moves and animated transitions are restored precisely (the latest 128 lines are kept);
- the UI is refreshed only after the replay completes **within the same frame**, so no earlier frame is ever shown;
- if restoring fails, the runtime enters its safe stopped state instead of leaving a half-restored scene.

## Boundaries

Only `end` (`halt`) is a boundary. `jump` (`jump.script`) **can** be crossed: the rewind restores the line together with the script it belongs to, so a step back moves into the script you jumped from, and advancing replays the `jump` again.

Crossable side effects: `signal` and `asyncam` **run again** when playback passes them (the signal is re-emitted, the camera moves again), so a branch the player re-picks re-triggers its signal handler. Achievement commands (`achievement unlock` / `increment` / `set_flag`) are external counters: they are crossed but **not replayed**, so an achievement is neither revoked nor counted twice. A rewound asynchronous camera cancels its in-flight tween and restores the transform from the snapshot. If a signal handler mutates state **outside** the snapshot, make it idempotent (see "Variables and side effects").

Stepping back is still **refused** (`can_step_back()` returns `false`) when:

- an `end` (`halt`) sits before the previous line;
- a runtime error is pending;
- the execution history was cleared or exceeds its retention capacity (512 instructions by default), or the snapshot the target line needs has already been evicted (the snapshot cache keeps the 128 most recently read lines inside a 4 MiB budget);

## Branch rollback

When the previous line is a **choice**, stepping back presents every option again so the player can choose differently:

```gdscript
dialogue_manager.timeline.step_back()  # the options appear again
```

Re-selecting writes a new choice entry. Under the default `TRIM` history policy the abandoned selection is removed from the history; under `KEEP` both selections remain.

Stepping back once more lands on the line *before* the question: a choice does not rewrite the dialogue box, so the line the options sit on is already on screen and is skipped in a single step instead of costing a click that changes nothing. The cancelled presentation is dismissed with it, so the option buttons never stay on screen over an earlier dialogue.

## Backlog jump (roll back to any line)

The default template's backlog panel supports **clicking any line to roll back to it** — Ren'Py's history screen is read-only, so jumping back there needs custom code:

```gdscript
# Backlog entries carry the VM commit serial they belong to.
var entries: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, false)

# Whether the entry can be used as a rollback target.
if dialogue_manager.timeline.can_rollback_to_entry(entries[0]["serial"]):
    # Roll back to that line: the same atomic path as "previous line".
    dialogue_manager.timeline.rollback_to_entry(entries[0]["serial"])
```

The semantics match "previous line" exactly: the line's snapshot restores the scene, the target line is replayed in the same frame, a `jump` between scripts may be crossed, crossed irreversible side effects follow their policy, and a failed restore enters the safe stop state.

These entries cannot be rolled back:

- **the line currently on screen** (not committed yet, serial `0`) — the panel shows it as a plain row;
- an unknown serial, or a line whose snapshot has already been evicted (the most recent 128 lines, see "Boundaries").

After the rollback the panel is trimmed to the target line; advancing again re-runs crossed replayable side effects (`signal`), so the final state matches the first playthrough.

## Variables and side effects

A rollback only rewinds **state inside the snapshot** (script variables, camera, actors, background, audio, UI and execution position); everything else follows the rules below:

| What is written | On rollback | When playback passes the instruction again |
| --- | --- | --- |
| `$` temporary / `%` persistent variables (`set`, `add`, ...) | restored exactly to the target line — the snapshot replaces the whole set, so variables created after it are removed too | runs again normally |
| `signal` | changes the handler made to **snapshot** state are rewound with the line | **re-emitted**, the handler runs again |
| `achievement unlock` / `increment` / `set_flag` | not undone (achievements only grow) | **not replayed**, never counted twice |
| State outside the snapshot (singletons, external saves, custom Resources) | cannot be undone | your handler must be idempotent (see example 3) |

**Persistent (`%`) and temporary (`$`) variables both live inside the snapshot**, so a rollback restores them wholesale to the target line; they differ in when they change:

- `%` persistent variables survive shot changes (they stay valid after a `jump` into another script) and are written to saves; a rollback restores the value they had **at the target line**.
- `$` temporary variables are cleared when the shot changes (`jump`); a rollback restores the value they had at the target line, so temporary variables of the previous script reappear after a cross-script rollback.

> ⚠️ Because the `%` set is replaced with the target line's snapshot, `%` variables changed **outside** the dialogue between those two lines (a shop, a menu, external code writing `variable_store`) are rewound too — this is time-travel semantics. If a number must survive dialogue rollback (platform currency, account progress), keep it outside the Konado snapshot instead of in `%`.

### Example 1: keep the numbers in script variables (recommended)

```text
set %love = 0
Kona "Do you want the tutorial?"
choice "Start the tutorial" -> start_choice
choice "Not now" -> exit_choice

branch start_choice
    add %love 1
    Kona "Let us learn together!"
    end
```

Rolling back to the choice and picking the same branch again: `%love` is first restored to `0` by the snapshot, then `add %love 1` runs once more → the result is still `1`. It never stays at `2` and is never lost.

### Example 2: `signal` plus a handler that only touches snapshot state

This is what the bundled demo does (`sample/demo/demo.gd`):

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content == "affection_up":
        # Writes a Konado persistent variable, which lives inside the snapshot.
        dialogue_manager.variable_store.apply_operation(
            "love", KonadoVariableStore.Operation.ADD, 1
        )
```

```text
choice "Start the tutorial" -> start_choice

branch start_choice
    ...
    signal affection_up
    Kona "Thanks for playing!"
    jump res://sample/demo/demo_02.ks
```

Rolling back across that branch and picking again: the signal **is re-emitted**, the handler adds `+1` again, and the `%love` it wrote was rewound with the line first — so the net result is still `+1` (not `+2`, and not stuck at `0`).

### Example 3: `signal` plus a handler that touches state outside the snapshot

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content != "unlock_gallery":
        return
    # Only touches a system outside the snapshot: a rollback cannot undo it.
    external_save.unlock_gallery("cg_01")
```

When the rewind crosses this instruction the signal is re-emitted, so `unlock_gallery` is called again. Make it idempotent by nature, or guard it with a **variable that lives inside the snapshot**:

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content != "unlock_gallery":
        return
    if dialogue_manager.variable_store.get_bool("gallery_cg_01"):
        return
    dialogue_manager.variable_store.set_value("gallery_cg_01", true)
    external_save.unlock_gallery("cg_01")
```

> To keep rollback fully predictable, keep the **authoritative numbers** in `%` persistent or `$` temporary variables and let external systems be presentation only (audio, UI, platform achievement sync) and safe to call repeatedly.

### Achievements are never replayed

`achievement unlock` / `achievement increment` / `achievement set_flag` represent external counters: a rollback may cross them, but playback **does not execute them again** — an achievement is never revoked and never recorded twice. If something must be re-triggerable after a rollback, express it with script variables instead.

## Saving and history

Rollback is an in-memory operation and does not change the save format; saving and loading keep working on the existing atomic execution boundary. History trimming follows `KonadoDialogueHistory.RollbackPolicy` (see "Dialogue History").
