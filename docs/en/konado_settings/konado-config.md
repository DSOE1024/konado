---
title: Configuration File
order: 2
---

# Settings Configuration Guide

## Configuration File Structure

The default settings configuration file is located at `res://addons/konado_settings/resources/default_settings.json` and uses JSON format to define setting items.

### Basic Structure

```json
{
    "categories": [
        {
            "id": "audio",
            "display_name": "Audio",
            "items": [
                {
                    "key": "master_volume",
                    "label": "Master Volume",
                    "type": 0,
                    "min_value": 0.0,
                    "max_value": 1.0,
                    "step": 0.01,
                    "default_value": 1.0,
                    "platforms": ["all"]
                }
            ]
        }
    ]
}
```

## Configuration Reference

### Top-Level Structure

- **categories**: Array of setting categories, containing all setting categories

### Category Properties

- **id**: Unique category identifier, used for programmatic access
- **display_name**: Category display name, shown in the settings panel
- **items**: Array of setting items under this category

### Setting Item Properties

- **key**: Unique setting item identifier, must be unique within its category
- **label**: Setting item display label, shown in the settings panel
- **type**: Setting type
  - `0`: Slider
  - `1`: Toggle
  - `2`: Option

#### Slider-Specific Properties

- **min_value**: Minimum value
- **max_value**: Maximum value
- **step**: Step size
- **default_value**: Default value (float)

#### Toggle-Specific Properties

- **default_value**: Default value (bool)

#### Option-Specific Properties

- **options**: List of options (Array[String])
- **default_value**: Default value (String, must be in the options list)

#### Common Properties

- **platforms**: Platform list; an empty array or `["all"]` means all platforms

## Supported Platform Identifiers

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

## Platform Filtering Rules

1. **Empty array**: Visible on all platforms
2. **Contains "all"**: Visible on all platforms
3. **Specific platforms**: Only visible on the specified platforms
4. **Platform aliases**: `linuxbsd` matches Linux or BSD platforms
5. **Build type**: `debug` and `release` filter by build type

## Example Configuration

### Complete Configuration Example

```json
{
    "categories": [
        {
            "id": "audio",
            "display_name": "Audio",
            "items": [
                {
                    "key": "master_volume",
                    "label": "Master Volume",
                    "type": 0,
                    "min_value": 0.0,
                    "max_value": 1.0,
                    "step": 0.01,
                    "default_value": 1.0,
                    "platforms": ["all"]
                },
                {
                    "key": "music_volume",
                    "label": "Music Volume",
                    "type": 0,
                    "min_value": 0.0,
                    "max_value": 1.0,
                    "step": 0.01,
                    "default_value": 0.8
                }
            ]
        },
        {
            "id": "display",
            "display_name": "Display",
            "items": [
                {
                    "key": "fullscreen",
                    "label": "Fullscreen",
                    "type": 1,
                    "default_value": false
                },
                {
                    "key": "language",
                    "label": "Language",
                    "type": 2,
                    "options": ["zh", "en", "ja"],
                    "default_value": "zh"
                },
                {
                    "key": "debug_mode",
                    "label": "Debug Mode",
                    "type": 1,
                    "default_value": false,
                    "platforms": ["debug"]
                },
                {
                    "key": "windows_only",
                    "label": "Windows Only",
                    "type": 1,
                    "default_value": false,
                    "platforms": ["windows"]
                }
            ]
        }
    ]
}
```

### Different Setting Type Examples

#### Slider Type

```json
{
    "key": "text_speed",
    "label": "Text Speed",
    "type": 0,
    "min_value": 0.01,
    "max_value": 0.2,
    "step": 0.005,
    "default_value": 0.05
}
```

#### Toggle Type

```json
{
    "key": "auto_mode",
    "label": "Auto Mode",
    "type": 1,
    "default_value": false
}
```

#### Option Type

```json
{
    "key": "quality",
    "label": "Quality",
    "type": 2,
    "options": ["Low", "Medium", "High", "Ultra"],
    "default_value": "Medium"
}
```

## Configuration Best Practices

1. **Naming Conventions**
   - Use lowercase letters and underscores for `id` and `key`
   - Use user-friendly names for `display_name`

2. **Platform Configuration**
   - For general settings, use `"platforms": ["all"]`
   - For platform-specific settings, specify the platform explicitly

3. **Default Values**
   - Provide reasonable default values for all settings
   - Ensure the default value type matches the setting type

4. **Organisation**
   - Group related settings into categories by function
   - Keep the number of categories reasonable

5. **Validation**
   - Use a JSON validation tool to check the configuration file format
   - Ensure all required properties are set

## Notes

- Ensure that each setting item's `key` is unique within its category
- For slider types, ensure `min_value` < `max_value`
- For option types, ensure the `options` array is not empty
- After changing the configuration file, restart the game or call the `rebuild()` method to update the settings panel
