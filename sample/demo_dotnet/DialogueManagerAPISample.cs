using Godot;
using Konado.Runtime.API;
using Konado.Wrapper;

namespace Konado.Sample;

/// <summary>
/// 这个是DialogueManagerAPI的使用示例
/// </summary>
public partial class DialogueManagerAPISample : Node
{
	public override void _Ready()
	{
		var interpreter = new KonadoScriptsInterpreter();
		var shot = interpreter.ProcessScriptsToData("res://sample/demo/demo_01.ks");
		if (shot == null)
		{
			GD.PushError("解析示例脚本失败。");
			return;
		}

		GD.Print(shot.Dialogues.Count);

		var dialogueManagerApi = KonadoAPI.DialogueManagerApi;
		if (dialogueManagerApi == null)
			return;
		if (!dialogueManagerApi.IsReady && !dialogueManagerApi.BindDialogueManager())
			return;

		GD.Print("Ready");
		StartDialogue(dialogueManagerApi);
	}

	private static void StartDialogue(DialogueManagerAPI dialogueManagerApi)
	{
		dialogueManagerApi.ShotStart += () =>
		{
			GD.Print("Shot Start");
		};

		dialogueManagerApi.ShotEnd += () =>
		{
			GD.Print("Shot End");
		};
		dialogueManagerApi.DialogueLineStart += (string nodeId) =>
		{
			GD.Print(nodeId);
		};
		dialogueManagerApi.DialogueLineEnd += (string nodeId) =>
		{
			GD.Print(nodeId);
		};

		if (KonadoAPI.API?.IsApiReady != true)
			return;

		GD.Print("API Ready");
		dialogueManagerApi.InitDialogue();
		dialogueManagerApi.StartDialogue();
	}
}
