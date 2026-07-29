using Godot;

namespace Konado.Wrapper;

public partial class KndData : Resource
{
	private static GDScript? _sourceScript;
	private const string SourceScriptPath = "res://addons/konado/scripts/knd_data/knd_data.gd";
	protected GodotObject SourceObject { get; }

	public KndData(GodotObject source) : this(source, LoadSourceScript(), "KND_Data")
	{
	}

	protected KndData(
		GodotObject source,
		GDScript expectedSourceScript,
		string expectedSourceName)
	{
		if (source is not Resource || !IsInstanceValid(source))
		{
			throw new System.InvalidOperationException("Source object is not a valid Resource!");
		}

		if (!InheritsSourceScript(source, expectedSourceScript))
		{
			throw new System.InvalidOperationException(
				$"Source object is not a {expectedSourceName} resource!");
		}

		SourceObject = source;
	}

	public KndData() : this(LoadSourceScript().New().AsGodotObject())
	{
	}

	public Resource SourceResource => (Resource)SourceObject;

	private static GDScript LoadSourceScript()
	{
		if (!ResourceLoader.Exists(SourceScriptPath))
		{
			throw new System.InvalidOperationException("KND_Data source script not found!");
		}

		return _sourceScript ??= ResourceLoader.Load<GDScript>(SourceScriptPath);
	}

	internal static bool InheritsSourceScript(GodotObject source, GDScript sourceScript)
	{
		var script = source.GetScript().AsGodotObject() as Script;
		while (script != null)
		{
			if (script == sourceScript)
				return true;

			script = script.GetBaseScript();
		}

		return false;
	}
}
