using Godot;
using System;

public partial class NodeItem : Control
{
    // 节点的锚点（输出锚点在右侧，输入锚点在左侧）
    public Vector2 OutputAnchor => new Vector2(Size.X, Size.Y / 2);
    public Vector2 InputAnchor => new Vector2(0, Size.Y / 2);

    // 拖拽相关变量
    private bool _isDragging;
    private Vector2 _dragStartPosition;
    private Vector2 _dragStartMousePosition;

    public override void _Ready()
    {
        // 设置节点基础样式
        CustomMinimumSize = new Vector2(120, 60);
        Modulate = new Color(0.2f, 0.4f, 0.8f); // 蓝色基调
    }

    public override void _Draw()
    {
        base._Draw();
        // 绘制节点背景（圆角矩形）
        //DrawRoundedRect(new Rect2(0, 0, Size.X, Size.Y), 8, Colors.DarkBlue, true);
        // 绘制锚点（可视化）
        DrawCircle(OutputAnchor, 4, Colors.LightBlue); // 输出锚点（右）
        DrawCircle(InputAnchor, 4, Colors.Yellow);   // 输入锚点（左）
        // 绘制节点文本（简单显示节点名称）
        DrawString(ThemeDB.FallbackFont, new Vector2(10, 10), Name, HorizontalAlignment.Center);
    }

    public override void _Input(InputEvent @event)
    {
        base._Input(@event);

        // 处理鼠标按下事件（开始拖拽）
        if (@event is InputEventMouseButton mouseButton && mouseButton.Pressed && mouseButton.ButtonIndex == MouseButton.Left)
        {
            _isDragging = true;
            _dragStartPosition = Position;
            _dragStartMousePosition = mouseButton.Position;
            GetParent<GraphView>().BringNodeToFront(this); // 拖拽时置顶节点
        }
        // 处理鼠标释放事件（结束拖拽）
        else if (@event is InputEventMouseButton mouseButtonRelease && !mouseButtonRelease.Pressed && mouseButtonRelease.ButtonIndex == MouseButton.Left)
        {
            _isDragging = false;
        }
        // 处理鼠标移动事件（拖拽节点）
        else if (@event is InputEventMouseMotion mouseMotion && _isDragging)
        {
            Vector2 delta = mouseMotion.Position - _dragStartMousePosition;
            Position = _dragStartPosition + delta;
            // 通知父节点更新所有关联的连线
            GetParent<GraphView>().UpdateConnectionsForNode(this);
        }
    }

    // 获取锚点的世界坐标（用于连线绘制）
    public Vector2 GetWorldAnchorPosition(bool isOutput)
    {
        return GlobalPosition + (isOutput ? OutputAnchor : InputAnchor);
    }
}