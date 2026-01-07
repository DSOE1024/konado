using Godot;
using System;
using System.Collections.Generic;

public partial class GraphView : Control
{
    // 画布交互相关
    private bool _isMiddlePanning;
    private Vector2 _panStartGlobalPos;
    private Vector2 _panStartMouseGlobalPos;
    private float _zoomLevel = 0.5f;
    private readonly float _zoomStep = 0.1f;
    private readonly float _minZoom = 0.5f;
    private readonly float _maxZoom = 2.0f;

    // 右键菜单相关
    private PopupMenu _contextMenu;
    private Vector2 _rightClickStartScreenPos;
    private const float DRAG_THRESHOLD = 5.0f;

    // 节点和连线管理
    private List<NodeItem> _nodes = new List<NodeItem>();
    private List<Connection> _connections = new List<Connection>();

    public override void _Ready()
    {
        Input.UseAccumulatedInput = false;
        MouseFilter = MouseFilterEnum.Stop;
        InitContextMenu();
    }

    private void InitContextMenu()
    {
        _contextMenu = new PopupMenu();
        _contextMenu.Name = "GraphContextMenu";
        AddChild(_contextMenu);

        _contextMenu.AddItem("新建节点");
        _contextMenu.Connect(PopupMenu.SignalName.IdPressed, new Callable(this, nameof(OnContextMenuOptionClicked)));

        // 菜单样式
        _contextMenu.AddThemeConstantOverride("margin_left", 8);
        _contextMenu.AddThemeConstantOverride("margin_right", 8);
        _contextMenu.AddThemeConstantOverride("margin_top", 8);
        _contextMenu.AddThemeConstantOverride("margin_bottom", 8);
        _contextMenu.AddThemeColorOverride("font_color", Colors.White);
        _contextMenu.AddThemeColorOverride("background_color", new Color(0.2f, 0.2f, 0.2f));
        _contextMenu.AddThemeColorOverride("hovered_item_color", new Color(0.3f, 0.4f, 0.6f));
    }

    // 自定义全局坐标转本地坐标方法（替代ToLocal）
    private Vector2 GlobalToLocal(Vector2 globalPos)
    {
        return (globalPos - this.GlobalPosition) / this.Scale;
    }

    private void OnContextMenuOptionClicked(long id)
    {
        if (id == 0)
        {
            Vector2 mouseGlobalPos = GetGlobalMousePosition();
            Vector2 mouseLocalPos = GlobalToLocal(mouseGlobalPos);
            NodeItem newNode = new NodeItem();
            AddNode(newNode, mouseLocalPos);
        }
    }

    public override void _Draw()
    {
        base._Draw();
        DrawCanvasBackground();
        DrawGraphViewGrid();
    }
    
    private void DrawCanvasBackground()
    {
        Rect2 viewportRect = GetViewportRect();
        // 背景绘制范围：完全覆盖可视区域+额外扩展，确保边界无空白
        float extendRatio = 5.0f; // 额外扩展5倍可视区域
        Vector2 drawStart = new Vector2(-viewportRect.Size.X * extendRatio, -viewportRect.Size.Y * extendRatio);
        Vector2 drawSize = new Vector2(viewportRect.Size.X * extendRatio * 2, viewportRect.Size.Y * extendRatio * 2);
        Color darkBackground = new Color(0.09f, 0.09f, 0.11f);
        
        DrawRect(new Rect2(drawStart, drawSize), darkBackground);
    }

    public override void _Input(InputEvent @event)
    {
        base._Input(@event);

        if (@event is InputEventMouseButton mouseButton)
        {
            // 中键平移
            if (mouseButton.Pressed && mouseButton.ButtonIndex == MouseButton.Middle)
            {
                _isMiddlePanning = true;
                _panStartGlobalPos = this.GlobalPosition;
                _panStartMouseGlobalPos = mouseButton.GlobalPosition;
            }
            else if (!mouseButton.Pressed && mouseButton.ButtonIndex == MouseButton.Middle)
            {
                _isMiddlePanning = false;
            }

            // 右键菜单（4.5兼容）
            if (mouseButton.Pressed && mouseButton.ButtonIndex == MouseButton.Right)
            {
                _rightClickStartScreenPos = mouseButton.GlobalPosition;
            }
            else if (!mouseButton.Pressed && mouseButton.ButtonIndex == MouseButton.Right)
            {
                if (mouseButton.GlobalPosition.DistanceTo(_rightClickStartScreenPos) < DRAG_THRESHOLD)
                {
                    _contextMenu.Popup();
                }
            }

            // 滚轮缩放（核心修复+精准边界）
            if (mouseButton.ButtonIndex == MouseButton.WheelUp || mouseButton.ButtonIndex == MouseButton.WheelDown)
            {
                Vector2 mouseGlobalPos = mouseButton.GlobalPosition;
                Vector2 mouseLocalBefore = GlobalToLocal(mouseGlobalPos);
                
                float zoomDelta = mouseButton.ButtonIndex == MouseButton.WheelUp ? _zoomStep : -_zoomStep;
                float oldZoomLevel = _zoomLevel;
                _zoomLevel = Mathf.Clamp(oldZoomLevel + zoomDelta, _minZoom, _maxZoom);
                this.Scale = new Vector2(_zoomLevel, _zoomLevel);
                
                // 缩放位置修正（适配缩放比例）
                Vector2 mouseLocalAfter = GlobalToLocal(mouseGlobalPos);
                Vector2 offsetCorrection = (mouseLocalBefore - mouseLocalAfter) * (oldZoomLevel / _zoomLevel);
                this.GlobalPosition += offsetCorrection;

                // 关键：缩放后立即校验边界，避免修正后超出范围
                ClampCanvasPosition(true);
            }
        }

        // 中键拖拽平移（实时边界校验）
        if (@event is InputEventMouseMotion mouseMotion && _isMiddlePanning)
        {
            Vector2 mouseDelta = mouseMotion.GlobalPosition - _panStartMouseGlobalPos;
            this.GlobalPosition = _panStartGlobalPos + mouseDelta;
            _panStartMouseGlobalPos = mouseMotion.GlobalPosition;
            _panStartGlobalPos = this.GlobalPosition;
            
            // 实时校验边界，移动中就限制偏移
            ClampCanvasPosition(false);
        }
    }

    // 重构：精准边界保护（核心修复）
    // isZoom: 是否是缩放后的边界校验（需要更宽松的范围）
    private void ClampCanvasPosition(bool isZoom = false)
    {
        Rect2 viewportRect = GetViewportRect();
        // 计算画布的“有效覆盖范围”：可视区域 × 缩放反比 × 扩展系数
        float extendFactor = isZoom ? 10.0f : 5.0f; // 缩放时允许更大的偏移范围
        float canvasCoverWidth = viewportRect.Size.X * (1.0f / _zoomLevel) * extendFactor;
        float canvasCoverHeight = viewportRect.Size.Y * (1.0f / _zoomLevel) * extendFactor;

        // 计算最小/最大允许偏移：确保可视区域始终在画布覆盖范围内
        float minX = -canvasCoverWidth + viewportRect.Size.X / 2;
        float maxX = canvasCoverWidth - viewportRect.Size.X / 2;
        float minY = -canvasCoverHeight + viewportRect.Size.Y / 2;
        float maxY = canvasCoverHeight - viewportRect.Size.Y / 2;

        // 精准限制GlobalPosition，确保可视区域内必有画布内容
        this.GlobalPosition = new Vector2(
            Mathf.Clamp(this.GlobalPosition.X, minX, maxX),
            Mathf.Clamp(this.GlobalPosition.Y, minY, maxY)
        );

        // 强制刷新绘制，避免边界处画面延迟
        QueueRedraw();
    }

    // 网格绘制（精准覆盖可视区域）
    private void DrawGraphViewGrid()
    {
        int gridSize = 12;
        Vector2 globalPos = this.GlobalPosition;
        float scaledGridSize = gridSize * _zoomLevel;
        
        Rect2 viewportRect = GetViewportRect();
        // 网格绘制范围：完全覆盖可视区域+边界外扩展，确保边界处有网格
        float drawExtend = 1000.0f; // 固定扩展1000像素，覆盖所有边界情况
        float drawMinX = -drawExtend;
        float drawMaxX = viewportRect.Size.X + drawExtend;
        float drawMinY = -drawExtend;
        float drawMaxY = viewportRect.Size.Y + drawExtend;

        Color gridLinePrimary = new Color(0.25f, 0.25f, 0.3f, 0.3f);
        Color gridLineSecondary = new Color(0.35f, 0.35f, 0.4f, 0.2f);

        // 网格起始点：从可视区域外开始，确保边界处有网格
        Vector2 localOffset = GlobalToLocal(Vector2.Zero);
        float startX = (float)Math.Floor((localOffset.X - drawExtend) / scaledGridSize) * scaledGridSize;
        float startY = (float)Math.Floor((localOffset.Y - drawExtend) / scaledGridSize) * scaledGridSize;

        // 绘制主网格线（覆盖扩展范围）
        for (float x = startX; x < drawMaxX; x += scaledGridSize)
        {
            DrawLine(new Vector2(x, drawMinY), new Vector2(x, drawMaxY), gridLinePrimary, 1);
        }
        for (float y = startY; y < drawMaxY; y += scaledGridSize)
        {
            DrawLine(new Vector2(drawMinX, y), new Vector2(drawMaxX, y), gridLinePrimary, 1);
        }

        // 绘制次网格线
        float scaledMajorGridSize = scaledGridSize * 5;
        float majorStartX = (float)Math.Floor((localOffset.X - drawExtend) / scaledMajorGridSize) * scaledMajorGridSize;
        float majorStartY = (float)Math.Floor((localOffset.Y - drawExtend) / scaledMajorGridSize) * scaledMajorGridSize;
        
        for (float x = majorStartX; x < drawMaxX; x += scaledMajorGridSize)
        {
            DrawLine(new Vector2(x, drawMinY), new Vector2(x, drawMaxY), gridLineSecondary, 2);
        }
        for (float y = majorStartY; y < drawMaxY; y += scaledMajorGridSize)
        {
            DrawLine(new Vector2(drawMinX, y), new Vector2(drawMaxX, y), gridLineSecondary, 2);
        }
    }

    // 以下方法无修改，保证完整性
    public void AddNode(NodeItem node, Vector2 position)
    {
        node.Name = $"Node_{_nodes.Count + 1}";
        node.Position = position;
        AddChild(node);
        _nodes.Add(node);
        QueueRedraw();
    }

    public void CreateConnection(NodeItem startNode, NodeItem endNode)
    {
        Connection connection = new Connection();
        connection.StartNode = startNode;
        connection.EndNode = endNode;
        connection.UpdatePositions(startNode.GetWorldAnchorPosition(true), endNode.GetWorldAnchorPosition(false));
        AddChild(connection);
        _connections.Add(connection);
        MoveChildToBack(connection);
    }

    public void UpdateConnectionsForNode(NodeItem node)
    {
        foreach (var conn in _connections)
        {
            if (conn.StartNode == node)
            {
                conn.UpdatePositions(node.GetWorldAnchorPosition(true), conn.EndNode.GetWorldAnchorPosition(false));
            }
            else if (conn.EndNode == node)
            {
                conn.UpdatePositions(conn.StartNode.GetWorldAnchorPosition(true), node.GetWorldAnchorPosition(false));
            }
        }
    }

    public void BringNodeToFront(NodeItem node)
    {
        MoveChild(node, GetChildCount() - 1);
        foreach (var conn in _connections)
        {
            MoveChildToBack(conn);
        }
    }

    private void MoveChildToBack(Node node)
    {
        MoveChild(node, 0);
    }
}