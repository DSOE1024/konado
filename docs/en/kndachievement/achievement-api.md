# KND_AchievementManager API Reference

## Signals

The achievement system provides the following signals, which can be used to listen for achievement-related events and execute custom logic:

### achievement_unlocked

**Signal Signature:** `achievement_unlocked(achievement_id: String, data: Dictionary)`

**Triggered When:** Fires when any achievement is unlocked

**Parameters:**
- `achievement_id`: The ID of the unlocked achievement
- `data`: The full data dictionary of the achievement, including name, description, icon, etc.

**Use Cases:** For executing reward logic, playing celebration animations, displaying custom notifications, etc. when an achievement is unlocked

**Example Code:**
```gdscript
# Connect signal
KND_AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

# Signal handler
func _on_achievement_unlocked(achievement_id: String, data: Dictionary) -> void:
    print("Achievement unlocked: " + data.get("name"))
    # Play achievement unlock sound effect
    # Show custom celebration animation
    # Grant player rewards
```

### achievement_progress_updated

**Signal Signature:** `achievement_progress_updated(achievement_id: String, current: float, target: float)`

**Triggered When:** Fires when an achievement's progress value is updated

**Parameters:**
- `achievement_id`: The ID of the achievement with updated progress
- `current`: The current progress value
- `target`: The target progress value

**Use Cases:** For displaying achievement progress bars, providing progress feedback, updating UI display, etc.

**Example Code:**
```gdscript
# Connect signal
KND_AchievementManager.achievement_progress_updated.connect(_on_progress_updated)

# Signal handler
func _on_progress_updated(achievement_id: String, current: float, target: float) -> void:
    var progress_percentage = (current / target) * 100
    print("Achievement progress updated: " + achievement_id + " - " + str(progress_percentage) + "%")
    # Update UI progress bar
    # Display progress notification
```

### achievements_reset

**Signal Signature:** `achievements_reset()`

**Triggered When:** Fires when all achievements are reset

**Parameters:** None

**Use Cases:** For updating the UI after an achievement reset, displaying a reset notification, performing cleanup operations, etc.

**Example Code:**
```gdscript
# Connect signal
KND_AchievementManager.achievements_reset.connect(_on_achievements_reset)

# Signal handler
func _on_achievements_reset() -> void:
    print("All achievements have been reset")
    # Update achievement panel
    # Display reset notification
```

### achievements_loaded

**Signal Signature:** `achievements_loaded()`

**Triggered When:** Fires when the achievement system has finished loading

**Parameters:** None

**Use Cases:** For initialising the UI after achievements have loaded, executing logic that depends on achievement data, etc.

**Example Code:**
```gdscript
# Connect signal
KND_AchievementManager.achievements_loaded.connect(_on_achievements_loaded)

# Signal handler
func _on_achievements_loaded() -> void:
    print("Achievement data loaded successfully")
    # Initialise achievement panel
    # Execute logic that depends on achievement data
```

## Core Methods

### Unlocking Achievements

```gdscript
# Unlock an achievement directly by ID
KND_AchievementManager.unlock_achievement("achievement_id")
```

### Progress Management

```gdscript
# Increment a counter value
KND_AchievementManager.increment_progress("counter_key", 1.0)

# Set a flag value
KND_AchievementManager.set_flag("flag_key", true)
```

### Achievement Queries

```gdscript
# Check if an achievement is unlocked
KND_AchievementManager.is_unlocked("achievement_id")

# Get a single achievement's data
KND_AchievementManager.get_achievement("achievement_id")

# Get all achievements
KND_AchievementManager.get_all_achievements()

# Get unlocked achievements
KND_AchievementManager.get_unlocked_achievements()

# Get locked achievements
KND_AchievementManager.get_locked_achievements()

# Get unlock percentage
KND_AchievementManager.get_unlock_percentage()
```

### Panel Management

```gdscript
# Show the achievement panel
KND_AchievementManager.show_panel()

# Hide the achievement panel
KND_AchievementManager.hide_panel()

# Toggle the achievement panel display state
KND_AchievementManager.toggle_panel()

# Check if the panel is visible
KND_AchievementManager.is_panel_visible()
```

#### Reset Functions
```gdscript
# Reset all achievements
KND_AchievementManager.reset_all()

# Reset a single achievement
KND_AchievementManager.reset_achievement("achievement_id")
```
