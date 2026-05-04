# Achievement System — KonadoAchievement

## Introduction

KonadoAchievement is a lightweight, data-driven achievement system plugin designed for Konado, providing full-featured functionality including unlocking, progress tracking, pop-up notifications, and an achievement panel. It can be used in conjunction with Konado or run independently.

### Configuration File

The achievement system uses a JSON configuration file to define achievements. The default path is `res://addons/konado_achievement/data/achievements.json`, which can be customised in `KND_AchievementManager`.

Example configuration file structure:

```json
{
  "achievements": [
    {
      "id": "first_blood",
      "name": "First Encounter",
      "description": "Unlock the first main storyline branch.",
      "icon": "",
      "hidden": false,
      "category": "story",
      "points": 10,
      "conditions": {
        "type": "counter",
        "target_key": "story_branch_unlocked",
        "target_value": 1
      }
    }
  ]
}
```

### Configuration Options (Optional)

In `KND_AchievementManager`, you can configure the following properties:

- `config_path`: Path to the achievement configuration file
- `save_path`: Path for saving achievement progress
- `popup_duration`: Duration that the achievement unlock pop-up notification is displayed
- `popup_position`: Position of the pop-up notification (top_left, top_right, bottom_left, bottom_right)

::tip
This section may be refactored in the future to provide more flexible configuration options.
::

## Core Features

### Achievement Unlocking

The system supports two unlocking methods:

1. **Direct Unlock**: Unlock achievements directly via the API
2. **Conditional Unlock**: Automatically unlock achievements when specific conditions are met

### Progress Tracking

The system supports two types of progress tracking:

1. **Counter**: Unlocks when a cumulative value reaches a target value
2. **Flag**: Unlocks when a flag is set to a specific value

### Notification System

When an achievement is unlocked, the system displays a pop-up notification containing the achievement name, description, and icon.

### Achievement Panel

Provides a panel that displays all achievements, including unlocked and locked ones, along with unlock progress.

## Achievement Configuration Details

### Achievement Properties

Each achievement can include the following properties:

- `id`: Unique achievement identifier
- `name`: Achievement name
- `description`: Achievement description
- `icon`: Achievement icon path (optional)
- `hidden`: Whether hidden (name and description are not shown when locked)
- `category`: Achievement category (optional)
- `points`: Achievement points (optional)
- `conditions`: Unlock conditions

### Condition Types

#### Counter Type

```json
{
  "type": "counter",
  "target_key": "counter_key",
  "target_value": 10
}
```

Unlocks when the value of `counter_key` reaches or exceeds `target_value`.

#### Flag Type

```json
{
  "type": "flag",
  "target_key": "flag_key",
  "target_value": true
}
```

Unlocks when the value of `flag_key` equals `target_value`.

## Usage Examples

### Basic Usage

```gdscript
# Increment a counter value
KND_AchievementManager.increment_progress("story_branch_unlocked", 1)

# Set a flag
KND_AchievementManager.set_flag("secret_ending_unlocked", true)

# Directly unlock an achievement
KND_AchievementManager.unlock_achievement("special_achievement")

# Show the achievement panel
KND_AchievementManager.show_panel()
```

### Signal Listening

```gdscript
# Listen for achievement unlock events
KND_AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(achievement_id: String, data: Dictionary) -> void:
    print("Achievement unlocked: " + data.get("name"))
    # You can add additional reward logic here
```

### Custom Save/Load

```gdscript
# Set custom save handler
KND_AchievementManager.custom_save_handler = Callable(self, "_custom_save")
KND_AchievementManager.custom_load_handler = Callable(self, "_custom_load")

func _custom_save(data: Dictionary) -> void:
    # Custom save logic
    pass

func _custom_load() -> Dictionary:
    # Custom load logic
    return {"unlocked": {}, "progress": {}}
```

### External Integration

```gdscript
# Set external unlock callback
KND_AchievementManager.on_external_unlock = Callable(self, "_on_external_unlock")

func _on_external_unlock(achievement_id: String, data: Dictionary) -> void:
    # Sync to external backend
    pass
```
