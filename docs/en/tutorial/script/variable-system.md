---
title: Variable System
order: 8
---

# Variable System

## Overview

The variable system lets scripts define, read, modify, and test variables. It can be used for dynamic dialogue text, conditional branches, and state tracking. Variable values can be referenced directly in dialogue text or used as conditions to control the story flow.

There are two variable types:

| Type | Prefix | Lifetime | Persistence | Initialization |
|------|--------|----------|-------------|----------------|
| Persistent variable | `%` | Preserved across shots | Saved with save data | Preset in the Inspector / initialized in code |
| Temporary variable | `$` | Current shot only | Not saved | Initialized with `set` in scripts |

---

## Variable Operations

Five basic operations are supported:

```text
<operation> <variable_name> <value>
```

or with an equals sign:

```text
<operation> <variable_name> = <value>
```

### Operations

| Operation | Description | Example |
|-----------|-------------|---------|
| `set` | Sets the variable value | `set %love = 10` |
| `add` | Addition for numbers, concatenation for strings | `add %love 5` |
| `sub` | Subtraction | `sub %love 3` |
| `mul` | Multiplication | `mul %love 2` |
| `div` | Division, reports an error when dividing by zero | `div %love 4` |

### Parameters

| Parameter | Required | Example | Description |
|-----------|----------|---------|-------------|
| Operation | Yes | `set` | One of the five supported operations |
| Variable name | Yes | `%love` | `%` starts a persistent variable, `$` starts a temporary variable |
| Value | Yes | `10` | Integer, float, boolean (`true`/`false`), or a quoted string |

### Example

```text
set %love = 10
add %love 5
sub %love 3
mul %love 2
div %love 4

set $round = 1
add $round 1

set %player_name "Player"
set $stage "Beginner Village"
set %unlocked true
```

---

## Variable Interpolation

Use `%variable_name` or `$variable_name` directly in dialogue text. At runtime, it is replaced with the actual value.

### Syntax

```text
"Character" "Dialogue text containing %variable_name or $variable_name"
```

### Example

```text
set %player_name "Ming"
set $stage "Beginner Village"

"Kona" "Hello, %player_name! You are now in $stage."
"Kona" "Your favorability is %love, and this is round $round."
```

Runtime output:

```text
Kona: "Hello, Ming! You are now in Beginner Village."
Kona: "Your favorability is 12, and this is round 2."
```

---

## Conditions

Use `if` / `else` / `endif` to choose which dialogue content to play based on variable values. Six comparison operators are supported.

### Syntax

```text
if <variable_name> <operator> <value>:
    <dialogue content>
else:
    <dialogue content>
endif
```

The `else:` block is optional. If it is omitted and the condition is false, the entire `if` block is skipped.

### Supported Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal to | `if %love == 5:` |
| `!=` | Not equal to | `if %love != 10:` |
| `>` | Greater than | `if %love > 3:` |
| `<` | Less than | `if %love < 10:` |
| `>=` | Greater than or equal to | `if %love >= 5:` |
| `<=` | Less than or equal to | `if %love <= 5:` |

### Parameters

| Parameter | Required | Example | Description |
|-----------|----------|---------|-------------|
| Variable name | Yes | `%love` | A persistent `%` variable or temporary `$` variable |
| Operator | Yes | `==` | One of the six comparison operators |
| Value | Yes | `5` | Integer value to compare |

### Example

```text
if %love == 5:
    "Kona" "Favorability is exactly 5!"
else:
    "Kona" "Favorability is not 5."
endif

if $score >= 80:
    "Kona" "Good!"
endif

if $score >= 60:
    "Kona" "Passed."
endif
```

### Notes

1. `if` / `else` / `endif` must use the same indentation level as their surrounding context.
2. Conditional statements do **not** support nesting. An `if` block cannot contain another `if`.
3. Use flat `if` / `endif` blocks for multiple independent conditions instead of nesting them.
4. Conditional statements can be used inside `branch` blocks.

---

## Conditions Inside Branches

A `branch` block can contain `if` / `endif` conditions for dynamic branch dialogue.

### Example

```text
branch after_choice
    "Kona" "Your choice has been recorded."

    if $choice_made == 1:
        "Kona" "You chose to give a gift. That was kind of you."
    endif

    if $choice_made == 2:
        "Kona" "You chose to chat. Communication matters."
    endif

    if $choice_made == 3:
        "Kona" "You chose to ignore it... Maybe try another option next time."
    endif
```

---

## Choices Linked With Variables

Combine `choice` and `branch` to modify variable values after the player makes a choice, so choices can affect later story content.

### Example

```text
set $choice_made = 0

choice "Give a gift (+10 favorability)" -> gift_choice
choice "Chat (+5 favorability)" -> chat_choice
choice "Ignore (-5 favorability)" -> ignore_choice

branch gift_choice
    add %love 10
    set $choice_made = 1
    "Kona" "Thank you! Favorability increased to %love!"
    jump_branch after_choice

branch chat_choice
    add %love 5
    set $choice_made = 2
    "Kona" "I enjoyed chatting with you. Favorability is now %love."
    jump_branch after_choice

branch ignore_choice
    sub %love 5
    set $choice_made = 3
    "Kona" "......Favorability dropped to %love."
    jump_branch after_choice

branch after_choice
    "Kona" "Your choice has been recorded."
```

---

## Boolean Variables

Variables support boolean values. Use `true` / `false` for assignment. In conditions, `true` is equivalent to `1`, and `false` is equivalent to `0`.

### Example

```text
set %unlocked true
set $visited false

if %unlocked == 1:
    "Kona" "The feature has been unlocked!"
endif

set $visited true
if $visited == 1:
    "Kona" "The visited flag has been set."
endif
```

---

## Variable Initialization

### Persistent Variables (`%`)

Persistent variables must be initialized before the script runs. There are two ways to do this:

**Method 1: Inspector preset (recommended)**

Create a `KND_VariableStore` resource in the editor, set initial variable values in the Inspector, and assign it to the `variable_store` property of `KND_DialogueManager`.

**Method 2: Code initialization**

```gdscript
func _ready() -> void:
    if dialogue_manager.variable_store == null:
        var store = KND_VariableStore.new()
        store.set_value("love", 0)
        store.set_value("player_name", "")
        store.set_value("unlocked", false)
        dialogue_manager.variable_store = store
```

### Temporary Variables (`$`)

Temporary variables do not need presets. They are automatically created the first time `set` is used in a script and reset when switching shots.

---

## Complete Example

This complete example covers all variable features:

```text
play bgm echo
background bg1 fade

actor show Kona Normal at 3 9 scale 0.3
"Kona" "Welcome to the variable system demo!"

set %love = 10
"Kona" "Favorability is set to 10. Current value: %love"

add %love 5
"Kona" "Favorability after adding 5: %love"

sub %love 3
"Kona" "Favorability after subtracting 3: %love"

mul %love 2
"Kona" "Favorability after multiplying by 2: %love"

div %love 4
"Kona" "Favorability after dividing by 4: %love"

set $round = 1
set $bonus = 100
"Kona" "Round=$round, bonus=$bonus"

add $round 1
add $bonus 50
"Kona" "Round $round, bonus $bonus"

set %player_name "Player"
"Kona" "Hello, %player_name! Favorability %love, round $round."

if %love == 6:
    "Kona" "Favorability is exactly 6!"
else:
    "Kona" "Favorability is not 6."
endif

if %love > 3:
    "Kona" "Favorability is greater than 3!"
endif

if %love < 10:
    "Kona" "Favorability is less than 10."
endif

set $score = 85

if $score >= 90:
    "Kona" "Excellent!"
endif

if $score >= 80:
    "Kona" "Good!"
endif

set %unlocked true
if %unlocked == 1:
    "Kona" "The feature has been unlocked!"
endif

choice "Give a gift (+10 favorability)" -> gift
choice "Ignore (-5 favorability)" -> ignore

branch gift
    add %love 10
    "Kona" "Thank you! Favorability %love!"
    jump_branch done

branch ignore
    sub %love 5
    "Kona" "......Favorability %love."
    jump_branch done

branch done
    actor exit Kona
    background bg_end fade
    end
```

---

## Notes

1. **Variable names** can only contain letters, numbers, and underscores, and are case-sensitive.
2. **Persistent variables** (`%`) are saved with save data and are suitable for favorability, story flags, and other cross-shot state.
3. **Temporary variables** (`$`) are cleared when switching shots and are suitable for temporary state in the current shot.
4. **Division** by zero triggers an error and skips the operation.
5. **Conditional statements** do not support nesting. Use flat `if` / `endif` blocks for multiple conditions.
6. When using conditions inside a `branch` block, the indentation of `if` / `endif` must match other content in the branch.
7. Uninitialized variables are treated as false in conditions.
