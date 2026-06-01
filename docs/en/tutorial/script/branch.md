# Branch

## Function Description

Creates a branch point for dialogue choices.

## Syntax Structure

```text
choice {
  [option_text] -> [target_label]
  [option_text] -> [target_label]
}
```

## Parameter Description

| Parameter | Required | Example | Description |
|------|------|------|------|
| option_text | Yes | `Go left` | Choice option text |
| target_label | Yes | `left_path` | Label to jump to when option is selected |

## Examples

```text
# Branch with choices
choice {
  "Go left" -> left_path
  "Go right" -> right_path
}

left_path:
"narrator" "You chose to go left."

right_path:
"narrator" "You chose to go right."
```
