---
title: Logger
order: 4
---

# Logger KND_Logger

## Preface

KND_Logger is a logging module based on the Godot Logger implementation. It supports log levels, log formats, log output, log files, and other features, and is used to record Konado runtime log information.

## Log Path

The logical log path is `user://konado_log.log`. Godot resolves its physical directory for the current operating system and project name; use `OS.get_user_data_dir()` to inspect it. `LOG_FILE_PATH` is a built-in constant, so changing the location requires maintaining that change in a customized plugin build.

## On-Screen Overlay Log

When an error occurs, the dialogue scene overlays a log window on the screen to show error information and interrupt game execution. If you want to disable this feature, set the `enable_overlay_log` property of `KND_DialogueManager` to `false`.

## Log Callback

A `KND_Logger` instance emits `error_caught(msg)` and `message_caught(message, error)`. When `KND_DialogueManager` enters the scene tree, it creates and registers an internal logger with Godot and uses `error_caught` to drive its overlay; the logger is not a global autoload. A custom integration that creates another `KND_Logger` must register it with `OS.add_logger()` and call `OS.remove_logger()` before freeing it to avoid duplicate logging or stale instances.
