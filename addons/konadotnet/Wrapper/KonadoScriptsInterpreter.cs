using Godot;

namespace Konado.Wrapper;

public sealed partial class KonadoScriptsInterpreter : RefCounted
{
	private static GDScript? _sourceScript;
	private const string SourceScriptPath = "res://addons/konado/ks/ks_interpreter.gd";
	private GodotObject _source;

	/// <summary>
	/// Create a new instance of the <see cref="KonadoScriptsInterpreter"/> class.
	/// </summary>
	/// <exception cref="System.InvalidOperationException"></exception>
	public KonadoScriptsInterpreter()
	{
		_source = LoadSourceScript().New().AsGodotObject();
	}

	public KonadoScriptsInterpreter(GodotObject source)
	{
		if (source is null || !IsInstanceValid(source))
		{
			throw new System.InvalidOperationException("Source object is not valid!");
		}

		var sourceScript = LoadSourceScript();
		if (source.GetScript().AsGodotObject() != sourceScript)
		{
			throw new System.InvalidOperationException("Source Object is not a valid source!");
		}

		_source = source;
	}

	private static GDScript LoadSourceScript()
	{
		if (!ResourceLoader.Exists(SourceScriptPath))
		{
			throw new System.InvalidOperationException("Source script not found!");
		}

		return _sourceScript ??= ResourceLoader.Load<GDScript>(SourceScriptPath);
	}

	public static class GDScriptMethodName
	{
		public static readonly StringName ProcessScriptsToData = "process_scripts_to_data";
		public static readonly StringName ParseSingleLine = "parse_single_line";
	}

	public KndShot? ProcessScriptsToData(string path)
	{
		var source = _source.Call(GDScriptMethodName.ProcessScriptsToData, path).As<Resource>();
		return source == null ? null : new KndShot(source);
	}

	public Dialogue? ParseSingleLine(string line, long lineNumber, string path)
	{
		var source = _source.Call(GDScriptMethodName.ParseSingleLine, line, lineNumber, path).As<Resource>();
		return source == null ? null : new Dialogue(source);
	}
}
