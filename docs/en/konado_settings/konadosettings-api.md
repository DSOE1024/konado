---
title: API Reference
order: 3
---

# Konado Settings API Documentation

## Settings Manager (KND_Settings)

The settings manager is an auto-loaded singleton used to manage all setting items.

### Signals

#### `setting_changed(category: String, key: String, value: Variant)`
- **Description**: Emitted when a setting value changes
- **Parameters**:
  - `category`: The setting category
  - `key`: The setting item key
  - `value`: The new setting value

### Methods

#### `get_setting(category: String, key: String) -> Variant`
- **Description**: Gets the current value of a setting
- **Parameters**:
  - `category`: The setting category
  - `key`: The setting item key
- **Returns**: The setting value, or the default value/null if it does not exist

#### `set_setting(category: String, key: String, value: Variant) -> void`
- **Description**: Modifies a setting, persists the change and emits a signal
- **Parameters**:
  - `category`: The setting category
  - `key`: The setting item key
  - `value`: The new setting value

#### `register_category(cat: SettingCategory) -> void`
- **Description**: Registers an additional setting category at runtime
- **Parameters**:
  - `cat`: The setting category to register

#### `reset_category(category_id: String) -> void`
- **Description**: Resets all settings in the specified category to their default values
- **Parameters**:
  - `category_id`: The category ID

#### `get_categories() -> Array`
- **Description**: Gets all registered categories (filtered by the current platform)
- **Returns**: An array of filtered categories

#### `get_category(id: String) -> SettingCategory`
- **Description**: Gets a single category by ID (filtered by the current platform)
- **Parameters**:
  - `id`: The category ID
- **Returns**: A filtered category object

## SettingCategory

Setting categories group related setting items together.

### Properties

- **id: String**: Unique identifier for the category
- **display_name: String**: Display name for the category
- **items: Array[SettingItem]**: Array of setting items in this category

### Example

```gdscript
var video_cat = SettingCategory.new()
video_cat.id = "video"
video_cat.display_name = "Video"

# Add setting items
video_cat.items.append(resolution_item)

# Register the category
KND_Settings.register_category(video_cat)
```

## SettingItem

A setting item is a single configurable unit.

### Enums

#### `Type`
- **SLIDER (0)**: Slider type, used for numeric adjustment
- **TOGGLE (1)**: Toggle type, used for boolean values
- **OPTION (2)**: Option type, used for dropdown selection

### Properties

- **key: String**: Unique identifier for the setting item
- **label: String**: Display label for the setting item
- **type: Type**: The type of setting item
- **min_value: float**: Minimum slider value (SLIDER only)
- **max_value: float**: Maximum slider value (SLIDER only)
- **step: float**: Slider step size (SLIDER only)
- **options: Array[String]**: List of options (OPTION only)
- **platforms: Array[String]**: Platform filter; empty array means visible on all platforms
- **default_value: Variant**: Default value — float for SLIDER, bool for TOGGLE, String for OPTION

### Examples

#### Creating a Slider Setting Item

```gdscript
var volume_item = SettingItem.new()
volume_item.key = "master_volume"
volume_item.label = "Master Volume"
volume_item.type = SettingItem.Type.SLIDER
volume_item.min_value = 0.0
volume_item.max_value = 1.0
volume_item.step = 0.01
volume_item.default_value = 1.0
volume_item.platforms = ["all"]
```

#### Creating a Toggle Setting Item

```gdscript
var fullscreen_item = SettingItem.new()
fullscreen_item.key = "fullscreen"
fullscreen_item.label = "Fullscreen"
fullscreen_item.type = SettingItem.Type.TOGGLE
fullscreen_item.default_value = false
```

#### Creating an Option Setting Item

```gdscript
var language_item = SettingItem.new()
language_item.key = "language"
language_item.label = "Language"
language_item.type = SettingItem.Type.OPTION
language_item.options = ["zh", "en", "ja"]
language_item.default_value = "zh"
```

## UIFactory

The UI factory creates control interfaces for setting items.

### Methods

#### `create_control(cat_id: String, item: SettingItem, callback: Callable) -> HBoxContainer`
- **Description**: Creates a row (HBoxContainer) for the given setting item and returns it
- **Parameters**:
  - `cat_id`: The category ID
  - `item`: The setting item
  - `callback`: A callback function in the format `callback(category_id: String, key: String, value: Variant)`
- **Returns**: The created HBoxContainer

### Example

```gdscript
var row = UIFactory.create_control("audio", volume_item, func(category, key, value):
    print("Setting changed: %s/%s = %s" % [category, key, value])
    KND_Settings.set_setting(category, key, value)
)

# Add to container
vbox_container.add_child(row)
```

## SettingsPanel

The settings panel is a visual interface for displaying and managing settings.

### Properties

- **_tab_container: TabContainer**: Tab container for displaying different category settings
- **btn_reset: Button**: Reset to defaults button
- **btn_close: Button**: Close button

### Methods

#### `rebuild() -> void`
- **Description**: Rebuilds the UI (useful after registering new categories)

### Signals

- **btn_reset.pressed**: Emitted when the reset button is clicked
- **btn_close.pressed**: Emitted when the close button is clicked

### Example

```gdscript
# Load the settings panel scene
var settings_panel = preload("res://addons/universal_settings/scenes/settings_panel.tscn").instantiate()
add_child(settings_panel)

# Show the settings panel
settings_panel.show()

# Rebuild the panel after registering a new category
KND_Settings.register_category(new_category)
settings_panel.rebuild()
```

## Platform Detection

The settings system automatically detects the current runtime platform and filters setting items based on their `platforms` property.

### Platform Identifiers

- `all` — All platforms
- `android` — Android
- `bsd` — BSD
- `linux` — Linux
- `macos` — macOS
- `ios` — iOS
- `visionos` — visionOS
- `windows` — Windows
- `linuxbsd` — Linux or BSD
- `debug` — Debug builds
- `release` — Release builds
- `editor` — Editor builds

### Platform Detection Logic

1. First checks whether running in the editor
2. Uses `OS.has_feature()` to detect the specific platform
3. Sets the current platform identifier based on the detection result
4. Filters setting items by platform when retrieving categories

## Persistent Storage

Setting values are automatically saved to the `user://knd_settings.cfg` file, using Godot's `ConfigFile` format.

### Save Timing

- When the `set_setting()` method is called
- Automatically writes the setting value to the configuration file

### Load Timing

- During plugin initialisation
- Automatically loads saved setting values from the configuration file

## Complete Usage Examples

### 1. Basic Usage

```gdscript
# Get a setting value
var master_volume = KND_Settings.get_setting("audio", "master_volume")

# Set a value
KND_Settings.set_setting("audio", "master_volume", 0.8)

# Listen for setting changes
KND_Settings.setting_changed.connect(func(category, key, value):
    if category == "audio" and key == "master_volume":
        # Handle volume change
        AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
)
```

### 2. Registering New Settings at Runtime

```gdscript
# Create a new setting category
var video_cat = SettingCategory.new()
video_cat.id = "video"
video_cat.display_name = "Video"

# Create a setting item
var resolution_item = SettingItem.new()
resolution_item.key = "resolution"
resolution_item.label = "Resolution"
resolution_item.type = SettingItem.Type.OPTION
resolution_item.options = ["1280x720", "1920x1080", "2560x1440"]
resolution_item.default_value = "1920x1080"

# Add to category
video_cat.items.append(resolution_item)

# Register the category
KND_Settings.register_category(video_cat)

# Rebuild the settings panel (if visible)
if settings_panel:
    settings_panel.rebuild()
```

### 3. Custom Settings Panel

```gdscript
# Create a custom settings panel
var panel = CanvasLayer.new()

# Create a tab container
var tab_container = TabContainer.new()
tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
panel.add_child(tab_container)

# Build the settings interface
var mgr = KND_Settings
for cat in mgr.get_categories():
    var scroll = ScrollContainer.new()
    scroll.name = cat.display_name
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var vbox = VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(vbox)

    for item in cat.items:
        var row = UIFactory.create_control(cat.id, item, func(cat_id, key, value):
            mgr.set_setting(cat_id, key, value)
        )
        vbox.add_child(row)

    tab_container.add_child(scroll)

# Add to scene
add_child(panel)
```

## Notes

- All API calls should be made after the game has started
- After registering a new category, call the `rebuild()` method to update the settings panel
- Platform filtering only affects the display of setting items, not the storage of setting values
- Setting item `key` values must be unique within their category
- For option types, the default value must be in the `options` list

## Error Handling

- If a setting item does not exist, `get_setting()` returns null and emits a warning
- If the configuration file has an incorrect format, a warning is emitted and default values are used
- If platform detection fails, it defaults to the `all` platform

## Performance Considerations

- The settings system uses lazy loading, only parsing the configuration file when needed
- Platform filtering is performed when retrieving categories and does not affect setting value access performance
- UI creation is on-demand, only creating controls when the settings panel is displayed

## Extension Suggestions

1. **Adding New Setting Types**:
   - Add a new enum value in `SettingItem.Type`
   - Add corresponding creation logic in `UIFactory`

2. **Custom Storage Method**:
   - Modify the `_load_saved()` and `set_setting()` methods in `settings_manager.gd`
   - Implement custom save and load logic

3. **Adding Setting Validation**:
   - Add validation logic in `set_setting()`
   - Ensure setting values are within valid ranges

4. **Internationalisation Support**:
   - Modify the handling logic for `display_name` and `label`
   - Support multilingual settings interfaces
