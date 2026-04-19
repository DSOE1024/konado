# Konado Change Log

## 2.4.0 LTS

### Core Features

#### 1. 节点图编辑器 (Graph Editor)
- 重构对话系统数据结构，使用节点图替代线性列表
- 新增 `knd_graph_edit.gd` - 可视化节点图编辑器
- 新增 `knd_graph_node_factory.gd` - 节点工厂，支持创建各种对话节点
- 新增 `knd_graph_converter.gd` - KS脚本与节点图之间的转换器
- 支持可视化编辑对话流程、条件分支、选项跳转

#### 2. 完整存档系统（Save System）
- 新增 `knd_save_system.gd` - 完整的存档管理系统
- 新增 `knd_save_data.gd` - 存档数据结构
- 新增存档UI组件
- 支持保存和读取游戏进度
- 支持存档预览
- 优化演员管理与存档集成

#### 3. 淡入打字机效果（Typewriter Effect）
- 新增 `KND_TypewriterText` 组件
- 支持BBCode富文本
- 支持GPU加速的逐字符淡入效果
- 在对话框中新增打字机模式选项
- 可切换传统打字机和淡入效果

#### 4. 变量系统与条件判断
- 支持 `%变量名` 格式的变量引用
- 支持 `if %var == value:` 条件分支
- 支持 `if %var > value:` 大于判断
- 支持 `if %var < value:` 小于判断
- 支持 `if %var >= value:` 大于等于判断
- 支持 `if %var <= value:` 小于等于判断
- 新增 `condition_operator` 字段支持多种比较操作符

#### 5. 自定义信号支持
- 添加自定义对话信号支持






