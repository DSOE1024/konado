---
title: Dialogue History (Backlog)
order: 8
---

# Dialogue History (Backlog)

The dialogue history (backlog) lets players review lines they have already read. It is maintained by the runtime service `KonadoDialogueHistory`, and the default dialogue template ships with a ready-to-open history panel.

## Behavior

- The history is **session-scoped**: it lives in memory only and is never written to a save file, so the existing save format is untouched and old saves keep loading.
- Entries are recorded per **atomic transaction**: only dialogue instructions committed by the virtual machine enter the history. Cancelled, failed, or superseded instructions leave no trace.
- The line currently on screen but not yet advanced is exposed as a **pending entry**, so a panel can show the current line when it opens.
- The number of entries is bounded by `max_dialogue_history_entries` (default `256`); the oldest entries are evicted first.

## Runtime API

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

```gdscript
# Entries in chronological order; include_pending also returns the current line
var entries: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, true)

# Committed entries only
var committed: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, false)

# Number of committed entries
var count: int = dialogue_manager.dialogue_history.size()

# Clear the history (also drops the pending entry)
dialogue_manager.dialogue_history.clear()
```

Each entry contains the following fields:

| Field | Description |
| --- | --- |
| `kind` | Entry type: `dialogue`, `choice`, or `screen_text` |
| `speaker` | The resolved speaker name |
| `text` | The interpolated, localized body text; for `choice`, the selected option |
| `options` | Every option text presented for that choice (only for `choice` entries) |
| `instruction_id` | The stable instruction ID, e.g. `ks:id:start` |
| `shot_path` | The source script path of the shot |
| `line` | The source line number of the line or choice |
| `serial` | The matching virtual machine commit serial |
| `pending` | Whether this is the current, not-yet-advanced line |

### Live notifications

```gdscript
dialogue_manager.dialogue_history.entry_committed.connect(
    func(entry: Dictionary) -> void:
        print("New line: ", entry["speaker"], entry["text"])
)
```

## Choice history

Player choices are recorded as well. Selecting a branch writes a `kind` of `choice` whose `text` is the **selected option** and whose `options` lists **every option presented at the time**. The default panel lists all options and highlights the selected one with `▶`. Choices follow the same atomic transaction rules: only a committed selection enters the history.

## Screen text history

Screen text (the `screentext` command, the NVL full-screen body) is recorded as one entry with a `kind` of `screen_text`: `text` joins every line with newlines and `lines` holds the per-line text. The default panel renders each line separately. It follows the same atomic transaction rules: the block enters the history only after it finishes playing and commits.

## Transactions and rollback

History entries map one-to-one onto virtual machine atomic transactions. The default `TRIM` policy keeps the history consistent with the timeline after a rollback or checkpoint restore: rolled-back lines are removed. Use `KEEP` for the classic visual novel behavior where everything seen is retained:

```gdscript
dialogue_manager.dialogue_history.rollback_policy = (
    KonadoDialogueHistory.RollbackPolicy.KEEP
)
```

Every row of the backlog is also a **rollback entry point**: clicking a committed entry rolls back to that line (see "Backlog jump" in [Dialogue Rollback (Previous Line)](./dialogue-rollback.md)). Entries carry the VM commit serial, so a custom UI can drive the same path:

```gdscript
dialogue_manager.timeline.can_rollback_to_entry(serial)
dialogue_manager.timeline.rollback_to_entry(serial)
```

## Default template

The default dialogue template adds a "Backlog" button to the function bar and instantiates `res://addons/konado/templates/default/backlog_panel.tscn`, whose script is `res://addons/konado/runtime/ui/backlog/konado_backlog_panel.gd`. If a custom template leaves these exports unset, the feature is disabled automatically and nothing else is affected.
