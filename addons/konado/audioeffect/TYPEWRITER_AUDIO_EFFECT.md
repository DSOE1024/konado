# 打字机音频效果

Konado 打字机音效的音频文件统一存放于 `res://addons/konado/audioeffect/typewriter/` 目录，用于实现打字机音频效果。

对话管理器会通过编辑器扩展自动生成音效下拉列表，方便用户选择不同的打字机效果；该功能由两个核心文件分工实现：
- `audioeffect_dropdown_editor.gd`：负责下拉列表的生成
- `audioeffect_inspector_plugin.gd`：负责插件的核心功能实现

### 使用方法

只需将新的音频文件添加到上述目录，文件会自动加载至对话管理器的下拉列表中。若新增文件未即时显示，重新加载项目或场景即可生效。