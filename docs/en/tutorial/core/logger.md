# Logger KND_Logger

## Preface

KND_Logger is a logging module implemented based on Godot Logger, supporting log levels, log formats, log output, log files and other functions, used to record log information during Konado's runtime.

## Log Path

The default log file path is `C:\Users\{username}\AppData\Roaming\Godot\app_userdata\Konado Project\konado_log.log`. You can change the log file path by modifying the `LOG_FILE_PATH` property of `KND_Logger`.

## Screen Overlay Log

When an error occurs, the dialogue scene will overlay a log window on the screen to display error information and interrupt game operation. If you want to disable this feature, you can set the `enable_overlay_log` property of `KND_DialogueManager` to `false`.

## Log Callback

KND_Logger provides log callback functionality. You can connect log callbacks in the following way:

```gdscript
logger.error_caught.connect(_show_error, ConnectFlags.CONNECT_DEFERRED)

func _show_error(msg: String) -> void:
    print(msg)
```
