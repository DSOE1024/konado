using System.Linq;
using Godot;
using Konado.Runtime.API;

namespace Konado.Wrapper;

public partial class Dialogue : Resource
{
	private static GDScript? _sourceScript;
	private const string SourceScriptPath = "res://addons/konado/scripts/dialogue/knd_dialogue.gd";
	private GodotObject _source;

	public Dialogue(GodotObject source)
	{
		if (source is null || !IsInstanceValid(source))
		{
			throw new System.InvalidOperationException("Source object is not valid!");
		}

		var sourceScript = LoadSourceScript();
		if (!KndData.InheritsSourceScript(source, sourceScript))
		{
			throw new System.InvalidOperationException("Source object is not a KND_Dialogue resource!");
		}

		_source = source;
	}

	public Dialogue()
	{
		_source = LoadSourceScript().New().AsGodotObject();
	}

	public Resource SourceResource => (Resource)_source;

	private static GDScript LoadSourceScript()
	{
		if (!ResourceLoader.Exists(SourceScriptPath))
		{
			throw new System.InvalidOperationException("KND_Dialogue source script not found!");
		}

		return _sourceScript ??= ResourceLoader.Load<GDScript>(SourceScriptPath);
	}

	public enum Type
	{
		OrdinaryDialog,
		DisplayActor,
		ActorChangeState,
		MoveActor,
		SwitchBackground,
		ExitActor,
		PlayBgm,
		StopBgm,
		PlaySoundEffect,
		ShowChoice,
		IfElseBranch,
		Branch,
		Jump,
		JumpBranch,
		Signal,
		AchievementUnlock,
		AchievementProgress,
		AchievementFlag,
		SetVariable,
		TheEnd,
		ActorMotion,
		MoveCam,
		ResetCam,
		CamShake,
		ScreenText,
		ShowTextbox,
		HideTextbox,
		WaitSignal,
		AsyncMoveCam,
		AsyncResetCam,
		AsyncCamShake,
		AsyncCamStop
	}

	public static class GDScriptPropertyName
	{
		public static readonly StringName SourceFileLine = "source_file_line";
		public static readonly StringName DialogType = "dialog_type";
		public static readonly StringName NodeId = "node_id";
		public static readonly StringName NextId = "next_id";
		public static readonly StringName IfNextId = "if_next_id";
		public static readonly StringName ElseNextId = "else_next_id";
		public static readonly StringName VarName = "varname";
		public static readonly StringName ConditionOperator = "condition_operator";
		public static readonly StringName TargetValue = "target_value";
		public static readonly StringName CharacterId = "character_id";
		public static readonly StringName DialogueContent = "dialog_content";
		public static readonly StringName CharacterName = "character_name";
		public static readonly StringName CharacterState = "character_state";
		public static readonly StringName ActorPosition = "actor_position";
		public static readonly StringName ExitActor = "exit_actor";
		public static readonly StringName ChangeStateActor = "change_state_actor";
		public static readonly StringName ChangeState = "change_state";
		public static readonly StringName TargetMoveChara = "target_move_chara";
		public static readonly StringName TargetMovePos = "target_move_pos";
		public static readonly StringName MotionActor = "motion_actor";
		public static readonly StringName MotionName = "motion_name";
		public static readonly StringName Choices = "choices";
		public static readonly StringName BgmName = "bgm_name";
		public static readonly StringName VoiceId = "voice_id";
		public static readonly StringName SoundeffectName = "soundeffect_name";
		public static readonly StringName BackgroundName = "background_name";
		public static readonly StringName BackgroundImageName = "background_image_name";
		public static readonly StringName BackgroundToggleEffects = "background_toggle_effects";
		public static readonly StringName CustomSignalName = "custom_signal_name";
		public static readonly StringName JumpShotPath = "jump_shot_path";
		public static readonly StringName JumpBranchTarget = "jump_branch_target";
		public static readonly StringName AchievementId = "achievement_id";
		public static readonly StringName AchievementValue = "achievement_value";
		public static readonly StringName AchievementFlagName = "achievement_flag_name";
		public static readonly StringName AchievementFlagValue = "achievement_flag_value";
		public static readonly StringName VariableName = "variable_name";
		public static readonly StringName VariableOperation = "variable_operation";
		public static readonly StringName VariableOperand = "variable_operand";
		public static readonly StringName IsPersistent = "is_persistent";
		public static readonly StringName TargetCam = "target_cam";
		public static readonly StringName CamTweenTime = "cam_tween_time";
		public static readonly StringName CamTweenType = "cam_tween_type";
		public static readonly StringName CamShakeTime = "cam_shake_time";
		public static readonly StringName TextContent = "text_content";
		public static readonly StringName TextboxDuration = "textbox_duration";
		public static readonly StringName WaitSignalName = "wait_signal_name";
	}

	public int SourceFileLine
	{
		get => _source.Get(GDScriptPropertyName.SourceFileLine).As<int>();
		set => _source.Set(GDScriptPropertyName.SourceFileLine, value);
	}

	public Type DialogueType
	{
		get => (Type)_source.Get(GDScriptPropertyName.DialogType).As<int>();
		set => _source.Set(GDScriptPropertyName.DialogType, (int)value);
	}

	public string NodeId
	{
		get => _source.Get(GDScriptPropertyName.NodeId).As<string>();
		set => _source.Set(GDScriptPropertyName.NodeId, value);
	}

	public string NextId
	{
		get => _source.Get(GDScriptPropertyName.NextId).As<string>();
		set => _source.Set(GDScriptPropertyName.NextId, value);
	}

	public string IfNextId
	{
		get => _source.Get(GDScriptPropertyName.IfNextId).As<string>();
		set => _source.Set(GDScriptPropertyName.IfNextId, value);
	}

	public string ElseNextId
	{
		get => _source.Get(GDScriptPropertyName.ElseNextId).As<string>();
		set => _source.Set(GDScriptPropertyName.ElseNextId, value);
	}

	public string VarName
	{
		get => _source.Get(GDScriptPropertyName.VarName).As<string>();
		set => _source.Set(GDScriptPropertyName.VarName, value);
	}

	public int ConditionOperator
	{
		get => _source.Get(GDScriptPropertyName.ConditionOperator).As<int>();
		set => _source.Set(GDScriptPropertyName.ConditionOperator, value);
	}

	public int TargetValue
	{
		get => _source.Get(GDScriptPropertyName.TargetValue).As<int>();
		set => _source.Set(GDScriptPropertyName.TargetValue, value);
	}

	public string CharacterId
	{
		get => _source.Get(GDScriptPropertyName.CharacterId).As<string>();
		set => _source.Set(GDScriptPropertyName.CharacterId, value);
	}

	public string DialogueContent
	{
		get => _source.Get(GDScriptPropertyName.DialogueContent).As<string>();
		set => _source.Set(GDScriptPropertyName.DialogueContent, value);
	}

	public string CharacterName
	{
		get => _source.Get(GDScriptPropertyName.CharacterName).As<string>();
		set => _source.Set(GDScriptPropertyName.CharacterName, value);
	}

	public string CharacterState
	{
		get => _source.Get(GDScriptPropertyName.CharacterState).As<string>();
		set => _source.Set(GDScriptPropertyName.CharacterState, value);
	}

	public Vector2 ActorPosition
	{
		get => _source.Get(GDScriptPropertyName.ActorPosition).As<Vector2>();
		set => _source.Set(GDScriptPropertyName.ActorPosition, value);
	}

	public string ExitActor
	{
		get => _source.Get(GDScriptPropertyName.ExitActor).As<string>();
		set => _source.Set(GDScriptPropertyName.ExitActor, value);
	}

	public string ChangeStateActor
	{
		get => _source.Get(GDScriptPropertyName.ChangeStateActor).As<string>();
		set => _source.Set(GDScriptPropertyName.ChangeStateActor, value);
	}

	public string ChangeState
	{
		get => _source.Get(GDScriptPropertyName.ChangeState).As<string>();
		set => _source.Set(GDScriptPropertyName.ChangeState, value);
	}

	public string TargetMoveChara
	{
		get => _source.Get(GDScriptPropertyName.TargetMoveChara).As<string>();
		set => _source.Set(GDScriptPropertyName.TargetMoveChara, value);
	}

	public Vector2 TargetMovePos
	{
		get => _source.Get(GDScriptPropertyName.TargetMovePos).As<Vector2>();
		set => _source.Set(GDScriptPropertyName.TargetMovePos, value);
	}

	public string MotionActor
	{
		get => _source.Get(GDScriptPropertyName.MotionActor).As<string>();
		set => _source.Set(GDScriptPropertyName.MotionActor, value);
	}

	public string MotionName
	{
		get => _source.Get(GDScriptPropertyName.MotionName).As<string>();
		set => _source.Set(GDScriptPropertyName.MotionName, value);
	}

	public Godot.Collections.Array<DialogueChoice> Choices
	{
		get => new(_source.Get(GDScriptPropertyName.Choices).As<Godot.Collections.Array<Resource>>().Select(r => new DialogueChoice(r)));
		set
		{
			if (value != null)
			{
				foreach (var choice in value)
				{
					if (choice?.SourceResource == null)
						throw new System.ArgumentException("Choices contains an invalid dialogue choice.", nameof(value));
				}
			}

			var sourceChoices = _source.Get(GDScriptPropertyName.Choices).AsGodotArray();
			sourceChoices.Clear();
			if (value != null)
				foreach (var choice in value)
					sourceChoices.Add(choice.SourceResource);
		}
	}

	public static class GDScriptMethodName
	{
		public static readonly StringName AddChoice = "add_choice";
		public static readonly StringName ClearChoices = "clear_choices";
	}

	public void AddChoice(string text, string targetId)
		=> _source.Call(GDScriptMethodName.AddChoice, text, targetId);

	public void ClearChoices()
		=> _source.Call(GDScriptMethodName.ClearChoices);

	public string BgmName
	{
		get => _source.Get(GDScriptPropertyName.BgmName).As<string>();
		set => _source.Set(GDScriptPropertyName.BgmName, value);
	}

	public string VoiceId
	{
		get => _source.Get(GDScriptPropertyName.VoiceId).As<string>();
		set => _source.Set(GDScriptPropertyName.VoiceId, value);
	}

	public string SoundeffectName
	{
		get => _source.Get(GDScriptPropertyName.SoundeffectName).As<string>();
		set => _source.Set(GDScriptPropertyName.SoundeffectName, value);
	}

	public string BackgroundName
	{
		get => _source.Get(GDScriptPropertyName.BackgroundName).As<string>();
		set => _source.Set(GDScriptPropertyName.BackgroundName, value);
	}

	public string BackgroundImageName
	{
		get => _source.Get(GDScriptPropertyName.BackgroundImageName).As<string>();
		set => _source.Set(GDScriptPropertyName.BackgroundImageName, value);
	}

	public ActingInterface.BackgroundTransitionEffectsType BackgroundToggleEffects
	{
		get => (ActingInterface.BackgroundTransitionEffectsType)_source.Get(GDScriptPropertyName.BackgroundToggleEffects).As<int>();
		set => _source.Set(GDScriptPropertyName.BackgroundToggleEffects, (int)value);
	}

	public string CustomSignalName
	{
		get => _source.Get(GDScriptPropertyName.CustomSignalName).As<string>();
		set => _source.Set(GDScriptPropertyName.CustomSignalName, value);
	}

	public string JumpShotPath
	{
		get => _source.Get(GDScriptPropertyName.JumpShotPath).As<string>();
		set => _source.Set(GDScriptPropertyName.JumpShotPath, value);
	}

	public string JumpBranchTarget
	{
		get => _source.Get(GDScriptPropertyName.JumpBranchTarget).As<string>();
		set => _source.Set(GDScriptPropertyName.JumpBranchTarget, value);
	}

	public string AchievementId
	{
		get => _source.Get(GDScriptPropertyName.AchievementId).As<string>();
		set => _source.Set(GDScriptPropertyName.AchievementId, value);
	}

	public int AchievementValue
	{
		get => _source.Get(GDScriptPropertyName.AchievementValue).As<int>();
		set => _source.Set(GDScriptPropertyName.AchievementValue, value);
	}

	public string AchievementFlagName
	{
		get => _source.Get(GDScriptPropertyName.AchievementFlagName).As<string>();
		set => _source.Set(GDScriptPropertyName.AchievementFlagName, value);
	}

	public bool AchievementFlagValue
	{
		get => _source.Get(GDScriptPropertyName.AchievementFlagValue).As<bool>();
		set => _source.Set(GDScriptPropertyName.AchievementFlagValue, value);
	}

	public string VariableName
	{
		get => _source.Get(GDScriptPropertyName.VariableName).As<string>();
		set => _source.Set(GDScriptPropertyName.VariableName, value);
	}

	public int VariableOperation
	{
		get => _source.Get(GDScriptPropertyName.VariableOperation).As<int>();
		set => _source.Set(GDScriptPropertyName.VariableOperation, value);
	}

	public string VariableOperand
	{
		get => _source.Get(GDScriptPropertyName.VariableOperand).As<string>();
		set => _source.Set(GDScriptPropertyName.VariableOperand, value);
	}

	public bool IsPersistent
	{
		get => _source.Get(GDScriptPropertyName.IsPersistent).As<bool>();
		set => _source.Set(GDScriptPropertyName.IsPersistent, value);
	}

	public string TargetCam
	{
		get => _source.Get(GDScriptPropertyName.TargetCam).As<string>();
		set => _source.Set(GDScriptPropertyName.TargetCam, value);
	}

	public float CamTweenTime
	{
		get => _source.Get(GDScriptPropertyName.CamTweenTime).As<float>();
		set => _source.Set(GDScriptPropertyName.CamTweenTime, value);
	}

	public string CamTweenType
	{
		get => _source.Get(GDScriptPropertyName.CamTweenType).As<string>();
		set => _source.Set(GDScriptPropertyName.CamTweenType, value);
	}

	public float CamShakeTime
	{
		get => _source.Get(GDScriptPropertyName.CamShakeTime).As<float>();
		set => _source.Set(GDScriptPropertyName.CamShakeTime, value);
	}

	public Godot.Collections.Array<string> TextContent
	{
		get => _source.Get(GDScriptPropertyName.TextContent).AsGodotArray<string>();
		set => _source.Set(GDScriptPropertyName.TextContent, value);
	}

	public float TextboxDuration
	{
		get => _source.Get(GDScriptPropertyName.TextboxDuration).As<float>();
		set => _source.Set(GDScriptPropertyName.TextboxDuration, value);
	}

	public string WaitSignalName
	{
		get => _source.Get(GDScriptPropertyName.WaitSignalName).As<string>();
		set => _source.Set(GDScriptPropertyName.WaitSignalName, value);
	}
}
