# Konado WebTool

## Introduction

Konado WebTool is a plugin that provides web platform development tool support for the Konado project. Since Godot 4.x captures and disables all keyboard shortcuts by default on the web platform, browser DevTools shortcuts (such as F12, F5, etc.) cannot be used normally. This plugin solves this problem by allowing common browser DevTools shortcuts on the web platform, making it easier for developers to debug and develop in a web environment.

## How It Works

Konado WebTool injects JavaScript code on the web platform to release keyboard shortcuts. It will:

1. Detect whether the current platform is the web platform
2. If it is the web platform and DevTools support is enabled, inject the shortcut handling code
3. Dynamically build the list of allowed shortcuts based on configuration
4. Listen for keyboard events, prevent default behaviour for allowed shortcuts, thereby passing them through to the browser

### Comparison with Other Solutions

| Solution | Advantages | Disadvantages |
|----------|------------|---------------|
| Konado WebTool | Simple to use, highly configurable, easy to maintain | No significant disadvantages |
| Manual export template modification | Full control | High technical demands, requires frequent updates |
| Development environment switching | Can debug on desktop platform | Cannot capture web platform-specific issues |

## Supported Browser Shortcuts

These shortcuts are based on the standard DevTools shortcuts for mainstream browsers (such as Chrome, Firefox, Edge, etc.), referencing official documentation from each browser:

- [Firefox DevTools](https://developer.mozilla.org/en-US/docs/Tools/Keyboard_shortcuts)
- [Edge DevTools](https://learn.microsoft.com/en-us/microsoft-edge/devtools-guide-chromium/shortcuts/)
- [Chrome DevTools](https://developer.chrome.com/docs/devtools/shortcuts/)
- [Safari DevTools (WebKit)](https://webkit.org/web-inspector/keyboard-shortcuts/)

| Shortcut | Function | Enable Option |
|----------|----------|---------------|
| F12 | Open DevTools | `enable_f12` |
| F5 | Refresh page | `enable_f5` |
| F11 | Toggle fullscreen | `enable_f11` |
| Ctrl+Shift+I (Win/Linux) / Cmd+Opt+I (Mac) | Open elements panel | `enable_ctrl_shift_i` |
| Ctrl+Shift+J (Win/Linux) / Cmd+Opt+J (Mac) | Open console | `enable_ctrl_shift_j` |
| Ctrl+Shift+C (Win/Linux) / Cmd+Shift+C (Mac) | Inspect element mode | `enable_ctrl_shift_c` |
| Ctrl+U (Win/Linux) / Cmd+U (Mac) | View page source | `enable_ctrl_u` |
| Ctrl+R (Win/Linux) / Cmd+R (Mac) | Refresh page | `enable_ctrl_r` |

## Configuration Options

In the auto-loaded `KND_WebTool` node, you can configure the following properties:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_web_devtool` | bool | true | Enable web DevTools shortcut passthrough |
| `enable_f12` | bool | true | Enable F12 shortcut |
| `enable_f5` | bool | true | Enable F5 shortcut |
| `enable_f11` | bool | true | Enable F11 shortcut |
| `enable_ctrl_shift_i` | bool | true | Enable Ctrl+Shift+I shortcut |
| `enable_ctrl_shift_j` | bool | true | Enable Ctrl+Shift+J shortcut |
| `enable_ctrl_shift_c` | bool | true | Enable Ctrl+Shift+C shortcut |
| `enable_ctrl_u` | bool | true | Enable Ctrl+U shortcut |
| `enable_ctrl_r` | bool | true | Enable Ctrl+R shortcut |
