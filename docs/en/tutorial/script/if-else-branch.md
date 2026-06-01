---
title: Conditional Branch
order: 5
---

# If Else Branch

## Description

Evaluates a numeric condition to determine which dialogue content to play. If the condition is not met, the dialogue in the `else` block is played instead. If there is no `else` block, no dialogue is played.

`%variable` is a custom variable with an integer value. It can be set in the dialogue manager and referenced via `%variable_name`. `==` is the comparison operator, meaning "equals".

## Syntax

```
if %variable == value:
    <dialogue>
    <dialogue>
else:
    <dialogue>
endif
```

## Example

```
if %love == 0:
    "Kona" "What would you like to drink today?"
else:
    "Kona" "Fancy meeting you again!"
    "Kona" "What would you like to drink today?"
endif
```
