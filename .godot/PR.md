# PR: 完善连续 actor show 的复用语义

## Summary

- 将重复 `actor show` 定义为合法的角色显示/复用语义，不再在 KS analyzer 中产生 warning。
- 新增 `KND_ActingInterface.show_character()` 和 `character_shown` 信号，保留 `create_new_character()` 与 `character_created` 兼容旧调用。
- 复用已有演员时等待位置更新完成后再推进对话流程，避免 show 的移动动画和下一条指令抢时序。
- 新增 `KND_Actor.set_stage_position()`，批量更新舞台分区和位置，避免一次 show 触发多次 tween。
- 修复自动推进信号解绑 bound callable 的问题，并让空移动立即完成，避免脚本卡住。

## Validation

- `git diff --check`
- `python3 plugin_path_checker.py "res://addons/konado/" "./addons/konado/"`
- `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://sample/demo/demo.tscn --quit-after 180`

## Notes

- 保留 PR #299 已产生的 sample 资源 UID/unique_id 变化不动。
- Godot headless 强制退出 demo 时仍会输出既有的资源清理 warning，不影响本次连续 show 验证。
