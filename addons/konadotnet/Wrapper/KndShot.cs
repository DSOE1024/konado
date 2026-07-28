using System.Linq;
using Godot;

namespace Konado.Wrapper;

public partial class KndShot : KndData
{
	private static GDScript? _sourceScript;
	private const string SourceScriptPath = "res://addons/konado/scripts/dialogue/knd_shot.gd";

	public KndShot(GodotObject source) : base(source)
	{
		var sourceScript = LoadSourceScript();
		if (!InheritsSourceScript(source, sourceScript))
		{
			throw new System.InvalidOperationException("Source object is not a KND_Shot resource!");
		}

		SourceObject = source;
	}

	public KndShot()
	{
		SourceObject = LoadSourceScript().New().AsGodotObject();
	}

	private static GDScript LoadSourceScript()
	{
		if (!ResourceLoader.Exists(SourceScriptPath))
		{
			throw new System.InvalidOperationException("KND_Shot source script not found!");
		}

		return _sourceScript ??= ResourceLoader.Load<GDScript>(SourceScriptPath);
	}

	public static class GDScriptPropertyName
	{
		public static readonly StringName KsPath = "ks_path";
		public static readonly StringName ShotId = "shot_id";
		public static readonly StringName StartNodeId = "start_node_id";
		public static readonly StringName Dialogues = "dialogues";
		public static readonly StringName DepCharacters = "dep_characters";
	}

	public string KsPath
	{
		get => SourceObject.Get(GDScriptPropertyName.KsPath).As<string>();
		set => SourceObject.Set(GDScriptPropertyName.KsPath, value);
	}

	public string ShotId
	{
		get => SourceObject.Get(GDScriptPropertyName.ShotId).As<string>();
		set => SourceObject.Set(GDScriptPropertyName.ShotId, value);
	}

	public string StartNodeId
	{
		get => SourceObject.Get(GDScriptPropertyName.StartNodeId).As<string>();
		set => SourceObject.Set(GDScriptPropertyName.StartNodeId, value);
	}

	public Godot.Collections.Array<Dialogue> Dialogues
	{
		get => new(SourceObject.Get(GDScriptPropertyName.Dialogues).As<Godot.Collections.Array<Resource>>().Select(r => new Dialogue(r)));
		set
		{
			if (value != null)
			{
				foreach (var dialogue in value)
				{
					if (dialogue?.SourceResource == null)
						throw new System.ArgumentException("Dialogues contains an invalid dialogue.", nameof(value));
				}
			}

			var sourceDialogues = SourceObject.Get(GDScriptPropertyName.Dialogues).AsGodotArray();
			sourceDialogues.Clear();
			if (value != null)
				foreach (var dialogue in value)
					sourceDialogues.Add(dialogue.SourceResource);
		}
	}

	public Godot.Collections.Array<string> DepCharacters
	{
		get => SourceObject.Get(GDScriptPropertyName.DepCharacters).AsGodotArray<string>();
		set => SourceObject.Set(GDScriptPropertyName.DepCharacters, value);
	}

	public Dialogue? FindNode(string nodeId)
	{
		var result = SourceObject.Call("find_node", nodeId).As<Resource>();
		return result == null ? null : new Dialogue(result);
	}

	public Dialogue? GetStartNode()
	{
		var result = SourceObject.Call("get_start_node").As<Resource>();
		return result == null ? null : new Dialogue(result);
	}
}
