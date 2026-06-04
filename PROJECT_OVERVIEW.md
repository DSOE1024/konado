# Konado 项目速查

本文档记录对当前 Godot 项目的初步熟悉结果，作为后续开发、排查和沟通参考。

## 项目定位

Konado 是一个面向 Godot 的视觉小说/故事驱动游戏对话框架。仓库主体不是单一游戏，而是一组插件、模板、示例和文档：

- 主插件：`addons/konado`
- 扩展插件：`addons/konado_settings`、`addons/konado_achievement`、`addons/konado_webtool`
- C# 封装：`addons/konadotnet`
- 示例工程：`sample/demo`
- 多语言文档站：`docs`

## Godot 配置

关键配置位于 `project.godot`：

- 项目名：`Konado Project`
- 项目版本：`2.4.5`
- Godot 配置版本：`config_version=5`
- 特性标记：`4.6`、`Forward Plus`
- 主场景：`res://sample/demo/demo.tscn`
- 视口尺寸：`1920x1080`
- 启用插件：
  - `res://addons/konado/plugin.cfg`
  - `res://addons/konado_achievement/plugin.cfg`
  - `res://addons/konado_settings/plugin.cfg`
  - `res://addons/konado_webtool/plugin.cfg`
- Autoload：
  - `KND_AchievementManager`
  - `KND_WebTool`
  - `KND_Settings`

注意：`addons/konado/plugin.cfg` 中版本是 `2.4.5`，但 `addons/konado/konado_plugin.gd` 内部打印常量仍是 `2.4.0`，后续做版本整理时可以检查。

## 核心入口

### 主插件入口

文件：`addons/konado/konado_plugin.gd`

职责：

- 注册 `.ks` 导入器
- 注册 `.kdic` 导入器
- 注册 `.ks` 文件悬浮提示插件
- 创建底部 `KonadoEdit` 编辑器 dock
- 加载 `addons/konado/editor/ks_editor/ks_editor.tscn`
- 注册音效相关 inspector 插件

### 对话运行时入口

文件：`addons/konado/scripts/dialogue/knd_dialogue_manager.gd`

`KND_DialogueManager` 是运行时核心，负责统一调度：

- 对话初始化和播放状态
- 普通文本和打字机效果
- 角色显示、退场、移动、状态切换
- 背景切换和过渡效果
- BGM、语音、音效
- 选项和分支
- jump 与 jump_branch
- 自定义 signal
- 成就指令
- 持久变量和临时变量
- 存档/读档
- 设置桥接

对话状态枚举：

- `OFF`
- `PLAYING`
- `PAUSED`

普通文本通常等待打字完成或用户点击；动作类节点通常监听对应接口的完成信号后自动推进；分支类节点会直接改变 `cur_node_id`。

## KS 脚本编译链路

`.ks` 是 Konado 的剧本脚本格式。导入器位于：

- `addons/konado/importer/konado_importer.gd`

导入流程：

1. Godot 发现 `.ks` 文件。
2. `konado_importer.gd` 创建 `KonadoScriptsInterpreter`。
3. `KonadoScriptsInterpreter.process_scripts_to_data()` 编译脚本。
4. 输出 `KND_Shot` 资源。
5. Godot 保存为 `.res`。

编译管线位于 `addons/konado/ks`：

- `ks_lexer.gd`：词法分析
- `ks_parser.gd`：语法分析
- `ks_analyzer.gd`：语义分析
- `ks_emitter.gd`：生成 `KND_Shot / KND_Dialogue`
- `ks_compiler.gd`：串联完整管线
- `ks_interpreter.gd`：对外包装入口

数据结构：

- `KND_Shot`：对话镜头，包含起始节点、对话节点列表和依赖角色列表
- `KND_Dialogue`：单个对话/指令节点，通过 `dialog_type` 区分类型
- `KND_DialogueChoice`：选项文本和目标节点

`KND_Dialogue.Type` 支持普通对话、角色操作、背景、音频、选项、if/else、jump、signal、achievement、变量和 end。

## KS 常用语法

示例文件：

- `sample/demo/demo_01.ks`
- `sample/demo/demo_02.ks`
- `sample/demo/demo_03_variable.ks`
- `sample/demo/demo_04_choice_branch.ks`

常见语法：

```ks
play bgm echo
background bg1 none
actor show Kona 正常 at 3
"Kona" "你好！欢迎来到我们的咖啡馆。" voice_01
actor move Kona 1
actor change Kona 介绍说话
actor exit Kona
jump res://sample/demo/demo_02.ks
end
```

变量：

```ks
set %love = 1
add %love 1
set $score = 10
```

- `%`：持久变量，走 `KND_VariableStore`，可参与存档
- `$`：临时变量，仅当前镜头运行期有效

分支与选项：

```ks
choice "继续" -> continue_branch
choice "离开" -> leave_branch

branch continue_branch
    "Kona" "那我们继续吧。"

branch leave_branch
    "Kona" "下次见。"
```

条件：

```ks
if %love > 0:
    "Kona" "我们已经更熟了。"
else:
    "Kona" "还需要再聊聊。"
endif
```

## 运行时资源接口

### 角色和背景

文件：`addons/konado/scripts/act/knd_acting_interface.gd`

职责：

- 背景切换
- 背景过渡 shader 管理
- 角色创建、删除、移动、状态切换
- 维护演员字典和节点缓存

背景效果包括：

- `none`
- `erase`
- `blinds`
- `wave`
- `fade`
- `vortex`
- `windmill`
- `cyberglitch`

### 音频

文件：`addons/konado/scripts/audio/knd_audio_interface.gd`

职责：

- 播放/停止 BGM
- 播放/停止语音
- 播放音效
- 从设置系统同步 master/music/sfx/voice 音量

### 对话框

相关文件：

- `addons/konado/scripts/dialoguebox/knd_dialogue_box.gd`
- `addons/konado/typewriter/typewriter_text.gd`
- `addons/konado/template/knd_dialogue_box.tscn`

对话框负责文本展示、打字机效果和点击推进信号。

## 存档、设置和成就

### 存档

文件：`addons/konado/scripts/save_system/knd_save_system.gd`

存档路径：

- `user://konado_saves/*.kns`

存档内容按策略控制，可包含：

- 当前对话状态
- 变量
- 音频状态
- 演员状态
- 背景状态

### 设置

文件：

- `addons/konado_settings/scripts/settings_manager.gd`
- `addons/konado/scripts/knd_settings_bridge.gd`

设置管理器作为 autoload `KND_Settings` 存在。Konado 主模块通过 `KND_SettingsBridge` 解耦访问设置。

### 成就

文件：`addons/konado_achievement/achievement_manager.gd`

成就管理器作为 autoload `KND_AchievementManager` 存在，支持：

- 直接解锁
- counter 进度
- flag 条件
- 弹窗和成就面板
- 自定义保存/加载回调

## C# 封装

目录：`addons/konadotnet`

主要文件：

- `addons/konadotnet/Runtime/API/DialogueManagerAPI.cs`
- `addons/konadotnet/Runtime/API/KonadoAPI.cs`
- `addons/konadotnet/Wrapper/*.cs`

C# 层主要是对 GDScript 节点和资源的封装，核心逻辑仍在 GDScript 中。`DialogueManagerAPI` 会在场景树中查找 `KND_DialogueManager` 并包装其信号和方法。

## 示例场景

主示例：

- `sample/demo/demo.tscn`
- `sample/demo/demo.gd`

`demo.tscn` 挂载两个对话模板：

- `KonadoDialogueLeft`
- `KonadoDialogueMiddle`

示例资源：

- `character_list.tres`
- `bg_list.tres`
- `bgm_list.tres`
- `voice_list.tres`
- `demo_01.ks`

`demo.gd` 演示了如何监听 `custom_signal`，并在收到 `好感度上升` 时修改变量。

## 文档站

目录：`docs`

`docs/package.json` 表明文档站使用 VitePress：

- `npm run docs:dev`
- `npm run docs:build`
- `npm run docs:preview`

文档按语言分区：

- `docs/zh`
- `docs/en`
- `docs/ja`
- `docs/ko`
- `docs/tc`

## 当前静态观察

- 仓库规模约为：
  - GDScript：69 个
  - 场景：16 个
  - `.tres` 资源：14 个
  - `.ks` 示例：4 个
  - C# 文件：11 个
  - Markdown 文档：300+ 个
- 本地 PATH 中暂未发现 `godot` 或 `godot4` 命令，因此当前记录基于静态阅读，没有执行 Godot 导入或运行验证。

## 后续排查建议

如果排查 `.ks` 解析问题，优先看：

1. `addons/konado/ks/ks_lexer.gd`
2. `addons/konado/ks/ks_parser.gd`
3. `addons/konado/ks/ks_analyzer.gd`
4. `addons/konado/ks/ks_emitter.gd`
5. `addons/konado/importer/konado_importer.gd`

如果排查对话播放卡住，优先看：

1. `KND_DialogueManager.cur_node_id`
2. 当前 `KND_Dialogue.dialog_type`
3. `dialogueState`
4. 当前节点的 `next_id / if_next_id / else_next_id`
5. 对应接口是否发出了完成信号

如果排查 UI 或模板问题，优先看：

1. `addons/konado/template`
2. `addons/konado/scripts/dialoguebox`
3. `addons/konado/scripts/act`
4. `sample/demo/demo.tscn`
