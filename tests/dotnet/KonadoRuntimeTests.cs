using Godot;
using Konado.Runtime.API;
using Konado.Wrapper;
using System;

namespace Konado.Tests;

public sealed partial class KonadoRuntimeTests : Node
{
	private int _failures;

	public override async void _Ready()
	{
		try
		{
			await RunTests();
		}
		catch (Exception exception)
		{
			GD.PrintErr(exception);
			_failures++;
		}

		GD.Print($"Konado.NET runtime tests: {_failures} failure(s)");
		GetTree().Quit(_failures == 0 ? 0 : 1);
	}

	private async System.Threading.Tasks.Task RunTests()
	{
		var api = new DialogueManagerAPI();
		AddChild(api);
		Check(!api.IsReady, "API must remain unbound before a manager enters the tree.");

		var managerScript = GD.Load<GDScript>(
			"res://tests/dotnet/fake_dialogue_manager.gd");
		var manager = managerScript.New().As<Node>();
		manager.Name = "AnyNodeName";
		AddChild(manager);
		await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
		Check(api.IsReady, "API must bind a manager added after its own _Ready().");

		manager.QueueFree();
		await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
		Check(!api.IsReady, "API must clear a freed manager.");

		var incompleteManager = new Node();
		AddChild(incompleteManager);
		Check(
			!api.BindDialogueManager(incompleteManager),
			"An incomplete forwarding contract must be rejected.");
		incompleteManager.QueueFree();

		var customDialogueScript = GD.Load<GDScript>(
			"res://tests/dotnet/custom_dialogue.gd");
		var customDialogue = customDialogueScript.New().AsGodotObject();
		var wrapper = new Dialogue(customDialogue);
		Check(
			wrapper.SourceResource == customDialogue,
			"Wrappers must accept GDScript subclasses of their source resource.");

		var protectedDialogue = new Dialogue
		{
			DialogueContent = "Konado.NET must transparently restore protected dialogue.",
		};
		var protectedShot = new KndShot
		{
			KsPath = "res://tests/dotnet/protected.ks",
			Dialogues = new Godot.Collections.Array<Dialogue> { protectedDialogue },
		};
		var buildKey = new byte[32];
		for (var index = 0; index < buildKey.Length; index++)
			buildKey[index] = (byte)index;
		Check(
			protectedShot.SourceResource.Call("protect_script_for_export", buildKey).AsBool(),
			"Konado.NET test shot must accept export-time protection.");
		Check(
			protectedShot.SourceResource.Call("is_script_protected").AsBool(),
			"Konado.NET test shot must enter the protected state.");
		Check(
			protectedShot.Dialogues.Count == 1
				&& protectedShot.Dialogues[0].DialogueContent
					== protectedDialogue.DialogueContent,
			"Konado.NET wrappers must transparently restore protected dialogue.");
		Check(
			!protectedShot.SourceResource.Call("is_script_protected").AsBool(),
			"Konado.NET wrappers must release protected buffers after restoration.");

		var i18n = new InternationalizationAPI();
		AddChild(i18n);
		Check(i18n.IsReady, "Internationalization API must bind the KND_I18n autoload.");
		Check(
			i18n.NormalizeLocale("zh-TW") == "zh_Hant",
			"Internationalization API must normalize legacy locale codes.");
	}

	private void Check(bool condition, string message)
	{
		if (condition)
			return;
		GD.PrintErr($"ASSERTION FAILED: {message}");
		_failures++;
	}
}
