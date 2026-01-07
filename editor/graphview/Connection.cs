using Godot;
using System;

public partial class Connection : Node2D
{
	// 连线的起点和终点节点（以及锚点位置）
	public NodeItem StartNode { get; set; }
	public NodeItem EndNode { get; set; }
	public Vector2 StartPosition { get; set; }
	public Vector2 EndPosition { get; set; }

	public override void _Draw()
	{
		base._Draw();
		// 绘制基础的连线（贝塞尔曲线简化为直线，降低复杂度）
		DrawLine(StartPosition, EndPosition, Colors.White, 2);
		// 绘制起点和终点的小圆点
		DrawCircle(StartPosition, 4, Colors.LightBlue);
		DrawCircle(EndPosition, 4, Colors.Yellow);
	}

	// 更新连线位置并重新绘制
	public void UpdatePositions(Vector2 start, Vector2 end)
	{
		StartPosition = start;
		EndPosition = end;
		QueueRedraw();
	}
}