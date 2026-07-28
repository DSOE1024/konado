using Godot;

namespace Konado.Wrapper;

public partial class DialogueChoice : Resource
{
	private static GDScript? _sourceScript;
	private const string SourceScriptPath = "res://addons/konado/scripts/dialogue/knd_dialogue_choice.gd";
	private GodotObject _source;

	public DialogueChoice(GodotObject source)
	{
		if (source is null || !IsInstanceValid(source))
		{
			throw new System.InvalidOperationException("Source object is not valid!");
		}

		var sourceScript = LoadSourceScript();
		if (!KndData.InheritsSourceScript(source, sourceScript))
		{
			throw new System.InvalidOperationException("Source object is not a KND_DialogueChoice resource!");
		}

		_source = source;
	}

	public DialogueChoice()
	{
		_source = LoadSourceScript().New().AsGodotObject();
	}

	public Resource SourceResource => (Resource)_source;

	private static GDScript LoadSourceScript()
	{
		if (!ResourceLoader.Exists(SourceScriptPath))
		{
			throw new System.InvalidOperationException("KND_DialogueChoice source script not found!");
		}

		return _sourceScript ??= ResourceLoader.Load<GDScript>(SourceScriptPath);
	}

	public static class GDScriptPropertyName
	{
		public static readonly StringName ChoiceText = "choice_text";
		public static readonly StringName NextId = "next_id";
	}

	public static class GDScriptMethodName
	{
		public static readonly StringName SerializeToDictionary = "serialize_to_dict";
		public static readonly StringName DeserializeFromDictionary = "deserialize_from_dict";
	}

	public string ChoiceText
	{
		get => _source.Get(GDScriptPropertyName.ChoiceText).As<string>();
		set => _source.Set(GDScriptPropertyName.ChoiceText, value);
	}

	public string NextId
	{
		get => _source.Get(GDScriptPropertyName.NextId).As<string>();
		set => _source.Set(GDScriptPropertyName.NextId, value);
	}

	public Godot.Collections.Dictionary SerializeToDictionary()
		=> _source.Call(GDScriptMethodName.SerializeToDictionary).AsGodotDictionary();

	public bool DeserializeFromDictionary(Godot.Collections.Dictionary dictionary)
		=> _source.Call(GDScriptMethodName.DeserializeFromDictionary, dictionary).As<bool>();
}
