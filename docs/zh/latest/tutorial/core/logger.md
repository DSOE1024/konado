---
title: Logger
order: 4
---

# 日志器 KND_Logger

## 前言

KND_Logger 是基于Godot Logger实现的日志模块，支持日志级别、日志格式、日志输出、日志文件等功能，用于记录Konado运行时的日志信息。

## 日志路径

日志文件逻辑路径为 `user://konado_log.log`，其实际目录由 Godot 针对当前操作系统和项目名称决定，可通过 `OS.get_user_data_dir()` 查看。`LOG_FILE_PATH` 是内置常量；如需改用其他路径，应在维护自定义插件版本时修改该常量。

## 屏幕覆盖日志

在报错时，对话场景会在屏幕上覆盖一个日志窗口，用于显示错误信息并中断游戏运行，如果您希望关闭该功能，可以将`KND_DialogueManager`的`enable_overlay_log`属性中设置为`false`。

## 日志回调

`KND_Logger` 实例会发出 `error_caught(msg)` 和 `message_caught(message, error)` 信号。`KND_DialogueManager` 会在进入场景树时创建并向 Godot 注册内部日志器，再使用 `error_caught` 驱动覆盖日志；它不是全局自动加载对象。自定义日志集成如果另行创建 `KND_Logger`，必须使用 `OS.add_logger()` 注册，并在释放前使用 `OS.remove_logger()` 注销，避免重复记录或残留无效实例。
