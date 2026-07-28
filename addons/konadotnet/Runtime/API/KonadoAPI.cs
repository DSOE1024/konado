using Godot;

namespace Konado.Runtime.API;

public sealed partial class KonadoAPI : Node
{
	public bool IsApiReady { get; private set; }
	public static KonadoAPI? API { get; private set; }
	public static DialogueManagerAPI? DialogueManagerApi { get; private set; }
	public static InternationalizationAPI? InternationalizationApi { get; private set; }

	public override void _Ready()
	{
		API = this;

		DialogueManagerApi = GetNodeOrNull<DialogueManagerAPI>("DialogueManagerAPI");
		if (DialogueManagerApi == null)
		{
			DialogueManagerApi = new DialogueManagerAPI
			{
				Name = "DialogueManagerAPI",
			};
			AddChild(DialogueManagerApi);
		}

		InternationalizationApi = GetNodeOrNull<InternationalizationAPI>(
			"InternationalizationAPI");
		if (InternationalizationApi == null)
		{
			InternationalizationApi = new InternationalizationAPI
			{
				Name = "InternationalizationAPI",
			};
			AddChild(InternationalizationApi);
		}

		IsApiReady = true;
	}

	public override void _ExitTree()
	{
		IsApiReady = false;
		if (API != this)
			return;
		API = null;
		DialogueManagerApi = null;
		InternationalizationApi = null;
	}
}
