# Option to Jump

## Function Description

Creates an option that jumps to a specific label when selected.

## Syntax Structure

```text
choice {
  [option_text] -> [target_label]
}
```

## Parameter Description

| Parameter | Required | Example | Description |
|------|------|------|------|
| option_text | Yes | `Go to chapter 2` | Choice option text |
| target_label | Yes | `chapter2` | Label to jump to |

## Examples

```text
# Option to jump
choice {
  "Go to chapter 2" -> chapter2
}

chapter2:
"narrator" "Chapter 2 begins..."
```
