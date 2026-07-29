---
title: KonadoScript 编辑器
order: 5
---

# Godot 内置 KonadoScript 编辑器

启用 Konado 插件后，在文件系统面板中双击 `.ks` 文件即可在底部的 `KonadoEdit` 面板中打开。编辑器直接修改原始 KonadoScript 文件，保存后会自动触发 Godot 重新导入。

## 编辑能力

- 使用标签页同时编辑多个 `.ks` 文件，并分别保留光标与未保存状态
- 自动保存恢复草稿；编辑器或插件意外退出后，再次打开文件时可以恢复
- 检测外部程序对文件的修改；无本地修改时自动重载，存在冲突时由用户选择
- 支持查找、替换、跳转行和分支符号导航
- 左侧语句目录可以插入所有当前支持的 KonadoScript 指令

## 高亮与补全

`KND_KsHighlighter` 基于 Godot 的 `SyntaxHighlighter` 实现。高亮、代码补全和语句目录共同读取 `KS_LanguageCatalog`，而合法关键字以解析器中的 `KS_Token.KEYWORDS` 为准。自动化测试会检查二者是否一致，因此新增或移除指令时不会只更新解析器而遗漏编辑器。

高亮规则只在首次使用时编译，并且每行只记录颜色变化的位置，避免在输入或滚动时重复编译正则表达式和生成逐字符字典。

默认高亮资源位于：

```text
res://addons/konado/editor/ks_editor/highlighter.tres
```

自定义编辑器也可以直接使用高亮器：

```gdscript
set_syntax_highlighter(KND_KsHighlighter.new())
```

## 实时诊断

停止输入片刻后，编辑器会执行词法、语法和语义分析，但不会生成运行时 `KND_Shot` 资源。错误和警告会同时显示在：

- 代码行的诊断标记与背景色
- 编辑器底部的问题列表

点击问题或对应行号槽标记即可跳转到相关位置。保存文件时仍会执行正常的 Godot 导入，因此编辑器诊断不能替代正式导入结果。

## 快捷键

| 功能 | Windows / Linux | macOS |
| --- | --- | --- |
| 保存 | `Ctrl+S` | `Command+S` |
| 关闭当前标签 | `Ctrl+W` | `Command+W` |
| 查找 | `Ctrl+F` | `Command+F` |
| 查找与替换 | `Ctrl+H` | `Command+Option+F` |
| 跳转到行 | `Ctrl+L` | `Command+L` |
