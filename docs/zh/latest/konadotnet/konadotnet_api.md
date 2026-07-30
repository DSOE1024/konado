---
title: 使用API
order: 2
---

# Konado .NET API

> Konado .NET 仍属于实验性功能。

## 简介

Konado.NET 是 Konado 对话系统的 C# API 扩展。它的目标不是替代 Konado 主插件，而是在 Godot C# 项目中提供一层更容易调用的接口，用于：

- 查找并控制场景中的 `KND_DialogueManager`
- 监听 Konado 对话流程信号
- 从 C# 解析 `.ks` 脚本
- 读取和创建 Konado 的 GDScript 数据资源包装对象
- 调用当前 Konado 的自动播放和存档接口

Konado.NET 会通过自动加载节点 `KonadoAPI` 提供入口。启用插件后，C# 代码通常从 `KonadoAPI.DialogueManagerApi` 开始使用。

## 使用前提

### 项目类型

Konado.NET 只能在支持 C# 的 Godot 项目中使用。请使用 Godot .NET 4.7.1 或更高版本的编辑器打开项目。

如果在非 .NET 项目中启用 Konadotnet，编辑器可能无法加载：

```text
res://addons/konadotnet/Konadotnet.cs
```

这不会影响 Konado 主插件，但无法使用 C# API。切换到 Godot .NET 编辑器并构建 C# 项目后即可继续。

### 插件启用顺序

请先启用 `Konado` 插件，再启用 `Konadotnet` 插件。Konadotnet 启用时会检查 `res://addons/konado/plugin.cfg` 是否存在，并检查主插件是否已经启用。

### 对话管理器节点

场景中需要存在 `KND_DialogueManager` 节点。Konado.NET 会优先按脚本类型查找：

```text
res://addons/konado/scripts/dialogue/knd_dialogue_manager.gd
```

除脚本类型外，也会校验节点是否完整实现当前 Konado 的信号和方法协议。如果项目中有多个对话管理器，请用 `BindDialogueManager(Node source)` 手动指定。

## 快速开始

```csharp
using Godot;
using Konado.Runtime.API;
using Konado.Wrapper;

public partial class DialogueExample : Node
{
    public override void _Ready()
    {
        var dialogueManager = KonadoAPI.DialogueManagerApi;
        if (dialogueManager == null)
            return;

        dialogueManager.DialogueLineStart += (string nodeId) =>
        {
            GD.Print($"当前节点开始: {nodeId}");
        };

        dialogueManager.CustomSignal += (string content) =>
        {
            GD.Print($"收到 Konado 自定义信号: {content}");
        };

        var interpreter = new KonadoScriptsInterpreter();
        var shot = interpreter.ProcessScriptsToData("res://sample/demo/demo_01.ks");
        if (shot == null)
            return;

        dialogueManager.SetShot(shot);
        dialogueManager.InitDialogue();
        dialogueManager.StartDialogue();
    }
}
```

## API 入口

### KonadoAPI

`KonadoAPI` 是 Konadotnet 插件创建的自动加载节点，用于持有全局 API 实例。

| 成员 | 类型 | 说明 |
| --- | --- | --- |
| `IsApiReady` | `bool` | 表示 `KonadoAPI` 自动加载节点是否初始化完成。初始化完成不代表已经找到 `KND_DialogueManager`，对话管理器状态请看 `DialogueManagerApi.IsReady`。 |
| `API` | `static KonadoAPI?` | 当前自动加载节点的静态引用；自动加载尚未初始化时为 `null`。 |
| `DialogueManagerApi` | `static DialogueManagerAPI?` | 对话管理器 API 实例；自动加载尚未初始化时为 `null`。 |
| `InternationalizationApi` | `static InternationalizationAPI?` | 国际化 API 实例；用于语言切换、翻译资源和本地化剧情加载。 |

使用示例：

```csharp
if (KonadoAPI.API?.IsApiReady == true
    && KonadoAPI.DialogueManagerApi is { IsReady: true } dialogueManager)
{
    dialogueManager.StartDialogue();
}
```

## InternationalizationAPI

`InternationalizationAPI` 与自动加载节点 `KND_I18n` 对接：

```csharp
var i18n = KonadoAPI.InternationalizationApi;
if (i18n == null || !i18n.IsReady)
    return;

i18n.LocaleChanged += locale => GD.Print($"当前语言：{locale}");
i18n.SetLocale("ja");
```

主要成员：

| 成员 | 说明 |
| --- | --- |
| `Locale` | 当前规范语言码。 |
| `AvailableLocales` | 内置语言和运行时注册语言。 |
| `SetLocale(locale, persist)` | 切换语言，并可选择是否持久化。 |
| `NormalizeLocale(locale)` | 将 `zh-CN`、`zh-TW` 等值转换为规范语言码。 |
| `RegisterTranslation(translation)` | 注册自定义 Godot `Translation`。 |
| `UnregisterTranslation(locale)` | 注销指定语言的翻译资源。 |
| `ResolveScriptPath(path, locale, warnOnFallback)` | 解析本地化 `.ks` 文件路径。 |
| `LoadLocalizedScript(path, locale, warnOnFallback)` | 加载本地化剧情并返回 `KndShot?`。 |

加载本地化剧情：

```csharp
var shot = i18n.LoadLocalizedScript(
    "res://dialogues/chapter.ks",
    "zh_Hant");

if (shot != null)
    KonadoAPI.DialogueManagerApi?.SetShot(shot);
```

## DialogueManagerAPI

`DialogueManagerAPI` 是 `KND_DialogueManager` 的 C# 控制层。它不复制对话管理器逻辑，而是把调用转发到 GDScript 节点。

### 属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `IsReady` | `bool` | 是否已经绑定到可用的 `KND_DialogueManager` 节点。自动查找失败时为 `false`。 |
| `Source` | `Node?` | 当前绑定的原始 Godot 节点。节点失效或释放后返回 `null`。需要直接访问 GDScript 暴露字段或自定义方法时可以使用。 |

### BindDialogueManager

```csharp
bool BindDialogueManager(Node source = null)
```

绑定对话管理器节点。

| 参数 | 说明 |
| --- | --- |
| `source` | 指定要绑定的 `KND_DialogueManager` 节点。传 `null` 时自动遍历当前场景树查找。 |

| 返回值 | 说明 |
| --- | --- |
| `true` | 绑定成功，`IsReady` 会变为 `true`。 |
| `false` | 未找到可用节点，`IsReady` 会保持或变为 `false`。 |

多对话管理器场景建议手动绑定：

```csharp
var manager = GetNode<Node>("UI/KonadoDialogueManager");
KonadoAPI.DialogueManagerApi?.BindDialogueManager(manager);
```

### InitDialogue

```csharp
void InitDialogue()
void InitDialogue(Callable callback)
```

调用 `KND_DialogueManager.init_dialogue()`，初始化当前对话资源、UI 状态和运行时状态。通常在 `SetShot()` 后、`StartDialogue()` 前调用。
带 `callback` 的重载会在初始化完成后由主插件调用该回调。

```csharp
dialogueManager.SetShot(shot);
dialogueManager.InitDialogue();
dialogueManager.StartDialogue();
```

### SetShot

```csharp
void SetShot(Resource shot)
void SetShot(KndShot shot)
```

调用 `KND_DialogueManager.set_shot()`，切换当前对话镜头。

| 参数 | 说明 |
| --- | --- |
| `shot` | `KND_Shot` 资源或 `KndShot` 包装对象。可以来自 Godot 资源，也可以来自 `KonadoScriptsInterpreter.ProcessScriptsToData()`。 |

`KndShot` 包装对象可以直接传入：

```csharp
KndShot? shot = interpreter.ProcessScriptsToData("res://dialogues/chapter_01.ks");
if (shot != null)
    dialogueManager.SetShot(shot);
```

### StartDialogue

```csharp
void StartDialogue()
```

调用 `KND_DialogueManager.start_dialogue()`，开始播放当前对话。调用前应确保：

- `DialogueManagerApi.IsReady == true`
- 对话管理器已经设置了 `start_dialogue_shot`，或已经通过 `SetShot()` 设置镜头
- 如需重新初始化，已经调用 `InitDialogue()`

### StopDialogue

```csharp
void StopDialogue()
```

调用 `KND_DialogueManager.stop_dialogue()`，停止当前对话流程，并触发 Konado 主插件的结束逻辑。

### StartAutoplay

```csharp
void StartAutoplay(bool value)
```

调用 `KND_DialogueManager.start_autoplay(value)`，切换自动播放状态。

| 参数 | 说明 |
| --- | --- |
| `value` | `true` 表示开启自动播放，`false` 表示关闭自动播放。 |

### 设置资源列表

```csharp
void SetCharaList(Resource charaList)
void SetBackgroundList(Resource backgroundList)
void SetBgmList(Resource bgmList)
```

分别调用 `set_chara_list()`、`set_background_list()` 和 `set_bgm_list()`，为对话管理器设置角色、背景和 BGM 资源列表。

### GetDialogueVariable

```csharp
Godot.Collections.Dictionary GetDialogueVariable(string key)
```

读取指定对话变量。变量存在时返回包含 `value` 键的字典；变量不存在或 API 未就绪时返回空字典。

### SaveGame

```csharp
bool SaveGame(int saveId)
```

调用 `KND_DialogueManager.save_game(saveId)` 保存当前进度。

| 参数 | 说明 |
| --- | --- |
| `saveId` | 存档槽 ID。具体编号策略由主插件存档系统决定。 |

| 返回值 | 说明 |
| --- | --- |
| `true` | 保存成功。 |
| `false` | API 未就绪或主插件保存失败。 |

### LoadGame

```csharp
bool LoadGame(int saveId)
```

调用 `KND_DialogueManager.load_game(saveId)` 读取指定存档。

| 参数 | 说明 |
| --- | --- |
| `saveId` | 要读取的存档槽 ID。 |

### DeleteSave

```csharp
bool DeleteSave(int saveId)
```

调用 `KND_DialogueManager.delete_save(saveId)` 删除指定存档。

### GetSaveInfo

```csharp
Godot.Collections.Dictionary GetSaveInfo(int saveId)
```

调用 `KND_DialogueManager.get_save_info(saveId)` 获取单个存档信息。

| 返回值 | 说明 |
| --- | --- |
| `Dictionary` | 存档信息。API 未就绪时返回空字典。字段内容由 Konado 主插件存档系统决定。 |

### GetAllSaveInfo

```csharp
Godot.Collections.Array<Godot.Collections.Dictionary> GetAllSaveInfo()
```

调用 `KND_DialogueManager.get_all_save_info()` 获取全部存档信息。API 未就绪时返回空数组。

### 存档策略

```csharp
void SetSaveStrategy(Godot.Collections.Dictionary strategy)
Godot.Collections.Dictionary GetSaveStrategy()
```

设置或读取主插件存档系统的存档策略。API 未就绪或没有存档系统时，`GetSaveStrategy()` 返回空字典。

### ReloadLocalizedScript

```csharp
bool ReloadLocalizedScript(string locale)
```

调用 `KND_DialogueManager.reload_localized_script(locale)`，按指定语言重新加载当前镜头的本地化脚本，并尽量保持当前节点。

| 参数 | 说明 |
| --- | --- |
| `locale` | 要切换到的语言代码，例如 `zh_Hans`、`en`。 |

| 返回值 | 说明 |
| --- | --- |
| `true` | 已加载本地化脚本。 |
| `false` | API 未就绪、国际化服务不可用，或当前镜头没有可加载的脚本。 |

### EmitWaitSignal

```csharp
void EmitWaitSignal(string signalName)
```

调用 `KND_DialogueManager.emit_wait_signal(signalName)`。当对话停在 `waitsignal` 节点且名称匹配时，继续播放后续节点。

```csharp
dialogueManager.EmitWaitSignal("minigame_done");
```

## DialogueManagerAPI 事件

### ShotStart

```csharp
event ShotStartSignalHandler ShotStart
```

绑定到 GDScript 信号 `shot_start`。对话镜头开始时触发，无参数。

```csharp
dialogueManager.ShotStart += () =>
{
    GD.Print("镜头开始");
};
```

### ShotEnd

```csharp
event ShotEndSignalHandler ShotEnd
```

绑定到 GDScript 信号 `shot_end`。对话镜头结束时触发，无参数。

### DialogueLineStart

```csharp
event DialogueLineStartSignalHandler DialogueLineStart
```

绑定到 GDScript 信号 `dialogue_line_start(node_id)`。当前对话节点开始处理时触发。

| 参数 | 说明 |
| --- | --- |
| `nodeId` | 当前 `KND_Dialogue.node_id`。当前 Konado 使用节点 ID 描述对话图，不再使用旧的行号参数。 |

### DialogueLineEnd

```csharp
event DialogueLineEndSignalHandler DialogueLineEnd
```

绑定到 GDScript 信号 `dialogue_line_end(node_id)`。当前对话节点结束时触发。

### CustomSignal

```csharp
event CustomSignalHandler CustomSignal
```

绑定到 GDScript 信号 `custom_signal(content)`。当 `.ks` 脚本中执行 `signal xxx` 语句时触发。

```csharp
dialogueManager.CustomSignal += (string content) =>
{
    if (content == "好感度上升")
    {
        GD.Print("处理好感度变化");
    }
};
```

## ActingInterface

`ActingInterface` 目前主要提供与主插件背景切换效果对齐的枚举。

### BackgroundTransitionEffectsType

| 枚举值 | 对应效果 |
| --- | --- |
| `NoneEffect` | 无切换效果 |
| `EraseEffect` | 擦除效果 |
| `BlindsEffect` | 百叶窗效果 |
| `WaveEffect` | 波浪效果 |
| `AlphaFadeEffect` | 透明度渐变效果 |
| `VortexSwapEffect` | 涡流切换效果 |
| `WindmillEffect` | 风车效果 |
| `CyberGlitchEffect` | 赛博故障效果 |
| `BlinkEffect` | 眨眼切换效果 |
| `Null` | 未指定效果，对应底层值 `-1`。 |

## Wrapper 类

Wrapper 类是对 Konado GDScript 资源的轻量封装。它们会保留底层 `Resource`，通过属性读写 GDScript 字段。

### 通用规则

- 包装已有资源时，构造函数会检查资源脚本是否匹配。
- 新建包装对象时，会通过对应的 GDScript 脚本创建底层资源。
- 只有 Godot API 明确要求底层 `Resource` 时才使用 `SourceResource`；`SetShot(KndShot)` 可以直接传入包装对象。
- Wrapper 不会复制资源内容，属性读写会直接作用到底层 GDScript 对象。

## Dialogue

`Dialogue` 包装 `KND_Dialogue`，对应文件：

```text
res://addons/konado/scripts/dialogue/knd_dialogue.gd
```

### 构造函数和底层资源

| 成员 | 说明 |
| --- | --- |
| `Dialogue()` | 创建新的 `KND_Dialogue` 资源。 |
| `Dialogue(GodotObject source)` | 包装已有 `KND_Dialogue` 资源。传入其他类型会抛出异常。 |
| `SourceResource` | 返回底层 `Resource`，用于传给 Godot 或 Konado 主插件 API。 |

### 基础图节点属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `SourceFileLine` | `int` | 对应原始 `.ks` 文件行号。用于调试、报错定位。默认值通常为 `-1`。 |
| `DialogueType` | `Dialogue.Type` | 当前节点的类型。决定主插件播放时如何处理该节点。 |
| `NodeId` | `string` | 对话图节点 ID。当前 Konado 使用它连接节点。 |
| `NextId` | `string` | 默认下一个节点 ID。普通对话、演出、音频等节点通常使用它继续流程。 |

### 条件分支属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `IfNextId` | `string` | 条件成立时跳转到的节点 ID。 |
| `ElseNextId` | `string` | 条件不成立时跳转到的节点 ID。 |
| `VarName` | `string` | 条件判断使用的变量名。 |
| `ConditionOperator` | `int` | 条件操作符。主插件当前约定：`0 ==`、`1 >`、`2 <`、`3 >=`、`4 <=`。 |
| `TargetValue` | `int` | 条件判断的目标值。 |

### 普通对话属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `CharacterId` | `string` | 说话角色 ID。 |
| `DialogueContent` | `string` | 对话文本内容。 |
| `VoiceId` | `string` | 该句对话绑定的语音 ID。 |

### 角色演出属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `CharacterName` | `string` | 要显示或创建的角色 ID。 |
| `CharacterState` | `string` | 角色状态/立绘状态 ID。 |
| `ActorPosition` | `Vector2` | 角色显示位置。当前 Konado 使用网格定位，通常 x 表示横向位置。 |
| `ExitActor` | `string` | 要退出/隐藏的角色 ID。 |
| `ChangeStateActor` | `string` | 要切换状态的角色 ID。 |
| `ChangeState` | `string` | 切换到的状态 ID。 |
| `TargetMoveChara` | `string` | 要移动的角色 ID。 |
| `TargetMovePos` | `Vector2` | 角色移动目标位置。 |
| `MotionActor` | `string` | 要播放舞台层动作的角色 ID。 |
| `MotionName` | `string` | 要播放的舞台层动作名称。 |

### 选项和跳转属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `Choices` | `Array<DialogueChoice>` | 当前选项节点包含的选项列表。每个选项通过 `NextId` 指向目标节点。 |
| `JumpShotPath` | `string` | 跳转到其他 `KND_Shot` 资源的路径。 |
| `JumpBranchTarget` | `string` | 跳转到当前镜头内的分支标签。 |

也可以直接调用与 GDScript 对应的辅助方法：

```csharp
dialogue.AddChoice("继续", "node_004");
dialogue.ClearChoices();
```

### 音频和背景属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `BgmName` | `string` | 要播放的 BGM 名称。 |
| `SoundeffectName` | `string` | 要播放的音效名称。 |
| `BackgroundName` | `string` | 要切换到的背景名称。 |
| `BackgroundToggleEffects` | `BackgroundTransitionEffectsType` | 背景切换效果。 |

### 相机属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `TargetCam` | `string` | `MoveCam` 或 `AsyncMoveCam` 节点要移动到的目标相机 ID。 |
| `CamTweenTime` | `float` | 相机移动或复位的过渡时长（秒）。 |
| `CamTweenType` | `string` | 相机过渡类型，由对应的 `.ks` 相机命令写入。 |
| `CamShakeTime` | `float` | 相机晃动时长（秒）。 |

### 屏幕文本、对话框和等待信号属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `TextContent` | `Array<string>` | `ScreenText` 节点要显示的 NVL 文本行。 |
| `TextboxDuration` | `float` | 显示或隐藏对话框的动画时长（秒），`0.0` 表示立即切换。 |
| `WaitSignalName` | `string` | `WaitSignal` 节点等待的外部信号名称。 |

### 自定义信号、成就和变量属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `CustomSignalName` | `string` | `signal` 节点触发时传给 `CustomSignal` 事件的内容。 |
| `AchievementId` | `string` | 成就 ID。用于解锁或更新成就。 |
| `AchievementValue` | `int` | 成就进度值。 |
| `AchievementFlagName` | `string` | 成就标签名。 |
| `AchievementFlagValue` | `bool` | 成就标签值。 |
| `VariableName` | `string` | 要操作的变量名。 |
| `VariableOperation` | `int` | 变量操作类型。主插件当前约定：`0 SET`、`1 ADD`、`2 SUB`、`3 MUL`、`4 DIV`。 |
| `VariableOperand` | `string` | 变量操作数，以字符串形式存储，运行时由主插件解析。 |
| `IsPersistent` | `bool` | 是否为持久变量。通常 `%` 前缀变量为持久变量，`$` 前缀变量为临时变量。 |

### Dialogue.Type

| 枚举值 | 说明 |
| --- | --- |
| `OrdinaryDialog` | 普通对话文本。 |
| `DisplayActor` | 显示或创建角色。 |
| `ActorChangeState` | 切换角色状态。 |
| `MoveActor` | 移动角色。 |
| `SwitchBackground` | 切换背景。 |
| `ExitActor` | 角色退出。 |
| `PlayBgm` | 播放 BGM。 |
| `StopBgm` | 停止 BGM。 |
| `PlaySoundEffect` | 播放音效。 |
| `ShowChoice` | 显示选项。 |
| `IfElseBranch` | 条件分支。 |
| `Branch` | 旧分支类型，主插件保留枚举值用于兼容。 |
| `Jump` | 跳转节点。 |
| `JumpBranch` | 跳转到分支标签。 |
| `Signal` | 自定义信号节点。 |
| `AchievementUnlock` | 解锁成就。 |
| `AchievementProgress` | 更新成就进度。 |
| `AchievementFlag` | 设置成就标签。 |
| `SetVariable` | 设置或修改变量。 |
| `TheEnd` | 结束节点。 |
| `ActorMotion` | 播放角色舞台层动作。 |
| `MoveCam` | 移动到目标相机并等待完成。 |
| `ResetCam` | 复位相机并等待完成。 |
| `CamShake` | 晃动相机并等待完成。 |
| `ScreenText` | 显示 NVL 屏幕文本。 |
| `ShowTextbox` | 显示对话框。 |
| `HideTextbox` | 隐藏对话框。 |
| `WaitSignal` | 等待外部信号。 |
| `AsyncMoveCam` | 异步移动到目标相机。 |
| `AsyncResetCam` | 异步复位相机。 |
| `AsyncCamShake` | 异步晃动相机。 |
| `AsyncCamStop` | 停止所有异步相机动画。 |

## DialogueChoice

`DialogueChoice` 包装 `KND_DialogueChoice`，对应文件：

```text
res://addons/konado/scripts/dialogue/knd_dialogue_choice.gd
```

| 成员 | 说明 |
| --- | --- |
| `DialogueChoice()` | 创建新的选项资源。 |
| `DialogueChoice(GodotObject source)` | 包装已有选项资源。 |
| `SourceResource` | 底层 `Resource`。 |

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `ChoiceText` | `string` | 显示给玩家的选项文本。 |
| `NextId` | `string` | 玩家选择该选项后跳转到的目标节点 ID。 |

示例：

```csharp
var choice = new DialogueChoice
{
    ChoiceText = "继续",
    NextId = "node_004"
};

Godot.Collections.Dictionary data = choice.SerializeToDictionary();
choice.DeserializeFromDictionary(data);
```

## KndData

`KndData` 是 Konado 数据资源的基础包装类，对应 `KND_Data`。

| 成员 | 说明 |
| --- | --- |
| `KndData()` | 创建新的 `KND_Data` 资源。 |
| `KndData(GodotObject source)` | 包装已有且继承 `KND_Data` 的资源。传入普通节点或其他资源会抛出异常。 |
| `SourceResource` | 返回底层 `Resource`。 |

大多数实际使用场景会直接使用 `KndShot`、`Dialogue`、`DialogueChoice` 等具体包装类。

## KndShot

`KndShot` 包装 `KND_Shot`，对应文件：

```text
res://addons/konado/scripts/dialogue/knd_shot.gd
```

### 属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `KsPath` | `string` | 来源 `.ks` 脚本路径。由解释器解析时写入。 |
| `ShotId` | `string` | 镜头 ID。 |
| `StartNodeId` | `string` | 起始节点 ID。为空时主插件通常使用 `Dialogues` 中第一个节点作为起点。 |
| `Dialogues` | `Array<Dialogue>` | 该镜头包含的所有对话节点。节点之间通过 `NodeId`、`NextId`、`IfNextId` 等字段组成图结构。 |
| `DepCharacters` | `Array<string>` | 当前镜头依赖的角色 ID 列表。 |

### FindNode

```csharp
Dialogue? FindNode(string nodeId)
```

按节点 ID 查找 `Dialogue`。

| 参数 | 说明 |
| --- | --- |
| `nodeId` | 要查找的 `KND_Dialogue.node_id`。 |

| 返回值 | 说明 |
| --- | --- |
| `Dialogue` | 找到的节点包装对象。未找到时返回 `null`。 |

### GetStartNode

```csharp
Dialogue? GetStartNode()
```

获取镜头起始节点。优先使用 `StartNodeId` 查找；如果为空，则返回 `Dialogues` 中第一个节点；没有节点时返回 `null`。

## KonadoScriptsInterpreter

`KonadoScriptsInterpreter` 包装主插件的脚本解释器：

```text
res://addons/konado/ks/ks_interpreter.gd
```

### 构造函数

| 成员 | 说明 |
| --- | --- |
| `KonadoScriptsInterpreter()` | 创建新的解释器实例。 |
| `KonadoScriptsInterpreter(GodotObject source)` | 包装已有解释器对象。 |

### ProcessScriptsToData

```csharp
KndShot? ProcessScriptsToData(string path)
```

将 `.ks` 脚本解析为 `KND_Shot`。

| 参数 | 说明 |
| --- | --- |
| `path` | `.ks` 文件资源路径，例如 `res://sample/demo/demo_01.ks`。 |

编译失败或文件不存在时返回 `null`。

解析结果可直接传给对话管理器：

```csharp
var interpreter = new KonadoScriptsInterpreter();
var shot = interpreter.ProcessScriptsToData("res://dialogues/chapter_01.ks");

if (shot != null && KonadoAPI.DialogueManagerApi is { } dialogueManager)
{
    dialogueManager.SetShot(shot);
    dialogueManager.InitDialogue();
    dialogueManager.StartDialogue();
}
```

### ParseSingleLine

```csharp
Dialogue? ParseSingleLine(string line, long lineNumber, string path)
```

解析单行 Konado 脚本，主要用于编辑器工具、调试器或自定义导入流程。

| 参数 | 说明 |
| --- | --- |
| `line` | 要解析的单行脚本文本。 |
| `lineNumber` | 原始文件行号，用于错误定位。 |
| `path` | 所属脚本路径。 |

空行或解析失败时返回 `null`。

## 完整示例

### 绑定管理器并监听事件

```csharp
using Godot;
using Konado.Runtime.API;

public partial class DialogueEvents : Node
{
    public override void _Ready()
    {
        var api = KonadoAPI.DialogueManagerApi;
        if (api == null)
            return;

        if (!api.IsReady)
        {
            api.BindDialogueManager();
        }

        api.ShotStart += () => GD.Print("镜头开始");
        api.ShotEnd += () => GD.Print("镜头结束");

        api.DialogueLineStart += (string nodeId) =>
        {
            GD.Print($"节点开始: {nodeId}");
        };

        api.DialogueLineEnd += (string nodeId) =>
        {
            GD.Print($"节点结束: {nodeId}");
        };

        api.CustomSignal += (string content) =>
        {
            GD.Print($"自定义信号: {content}");
        };
    }
}
```

### 解析脚本并播放

```csharp
using Godot;
using Konado.Runtime.API;
using Konado.Wrapper;

public partial class PlayKsFile : Node
{
    public override void _Ready()
    {
        var interpreter = new KonadoScriptsInterpreter();
        var shot = interpreter.ProcessScriptsToData("res://sample/demo/demo_01.ks");

        var api = KonadoAPI.DialogueManagerApi;
        if (shot == null || api == null)
            return;

        api.SetShot(shot);
        api.InitDialogue();
        api.StartDialogue();
    }
}
```

### 读取存档信息

```csharp
using Godot;
using Konado.Runtime.API;

public partial class SaveInfoExample : Node
{
    public override void _Ready()
    {
        var api = KonadoAPI.DialogueManagerApi;
        if (api == null)
            return;

        if (api.SaveGame(1))
        {
            var info = api.GetSaveInfo(1);
            GD.Print(info);
        }

        var allSaves = api.GetAllSaveInfo();
        GD.Print($"存档数量: {allSaves.Count}");
    }
}
```

## 常见问题

### `IsApiReady` 为 true，但 `DialogueManagerApi.IsReady` 为 false

`IsApiReady` 只表示 Konado.NET 自动加载节点已经初始化。`DialogueManagerApi.IsReady` 才表示是否找到了场景中的 `KND_DialogueManager`。请确认当前场景已经实例化对话管理器，或手动调用：

```csharp
KonadoAPI.DialogueManagerApi?.BindDialogueManager(GetNode<Node>("你的管理器路径"));
```

### 事件没有触发

请检查对话是否已经开始播放，以及 `KND_DialogueManager` 是否是当前绑定的节点。多管理器项目中，自动查找可能绑定到第一个符合条件的节点。

### `SetShot` 后没有播放

`SetShot()` 只切换镜头，不会自动初始化或开始播放。一般调用顺序是：

```csharp
api.SetShot(shot);
api.InitDialogue();
api.StartDialogue();
```
