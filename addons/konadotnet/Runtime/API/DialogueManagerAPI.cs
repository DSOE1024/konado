using Godot;
using Konado.Wrapper;

namespace Konado.Runtime.API;

/// <summary>
/// Konado DialogueManager C# API，用于与 Konado DialogueManager 节点进行交互
/// </summary>
public sealed partial class DialogueManagerAPI : Node
{
	private const string DialogueManagerScriptPath = "res://addons/konado/scripts/dialogue/knd_dialogue_manager.gd";

	private Node? _source;
	private bool _treeSignalsConnected;

	public bool IsReady => _source != null
		&& IsInstanceValid(_source)
		&& HasDialogueManagerContract(_source);
	public Node? Source => IsReady ? _source : null;

	public override void _Ready()
	{
		ConnectTreeSignals();
		TryBindDialogueManager(null, false);
	}

	public bool BindDialogueManager(Node? source = null)
	{
		return TryBindDialogueManager(source, true);
	}

	private bool TryBindDialogueManager(Node? source, bool reportFailure)
	{
		var target = source ?? FindDialogueManager(GetTree().Root);

		if (target == null || !IsDialogueManager(target))
		{
			ClearSource();
			if (reportFailure)
			{
				GD.PrintErr(source == null
					? "未找到 KND_DialogueManager 节点。请确保场景中已实例化 Konado 对话管理器。"
					: "指定节点不是有效的 KND_DialogueManager。");
			}
			return false;
		}

		if (_source != target)
		{
			DisconnectSignals(_source);
			_source = target;
		}

		ConnectSignals();
		if (reportFailure)
			GD.Print($"Konado.NET 已绑定对话管理器：{target.GetPath()}");
		return true;
	}

	private void ConnectTreeSignals()
	{
		if (_treeSignalsConnected)
			return;
		var tree = GetTree();
		tree.NodeAdded += OnTreeNodeAdded;
		tree.NodeRemoved += OnTreeNodeRemoved;
		_treeSignalsConnected = true;
	}

	private void DisconnectTreeSignals()
	{
		if (!_treeSignalsConnected || !IsInsideTree())
			return;
		var tree = GetTree();
		tree.NodeAdded -= OnTreeNodeAdded;
		tree.NodeRemoved -= OnTreeNodeRemoved;
		_treeSignalsConnected = false;
	}

	private void OnTreeNodeAdded(Node node)
	{
		if (!IsReady && IsDialogueManager(node))
			TryBindDialogueManager(node, false);
	}

	private void OnTreeNodeRemoved(Node node)
	{
		if (node == _source)
			ClearSource();
	}

	private static Node? FindDialogueManager(Node? currentNode)
	{
		if (currentNode == null)
			return null;

		if (IsDialogueManager(currentNode))
			return currentNode;

		foreach (Node child in currentNode.GetChildren())
		{
			var foundNode = FindDialogueManager(child);
			if (foundNode != null)
				return foundNode;
		}

		return null;
	}

	private static bool IsDialogueManager(Node? node)
	{
		if (node == null || !IsInstanceValid(node))
			return false;

		if (ResourceLoader.Exists(DialogueManagerScriptPath))
		{
			var sourceScript = ResourceLoader.Load<GDScript>(DialogueManagerScriptPath);
			if (node.GetScript().AsGodotObject() == sourceScript)
				return true;
		}

		return HasDialogueManagerContract(node);
	}

	private static bool HasDialogueManagerContract(Node? node)
	{
		return node != null
			&& IsInstanceValid(node)
			&& node.HasSignal(GDScriptSignalName.ShotStart)
			&& node.HasSignal(GDScriptSignalName.ShotEnd)
			&& node.HasSignal(GDScriptSignalName.DialogueLineStart)
			&& node.HasSignal(GDScriptSignalName.DialogueLineEnd)
			&& node.HasSignal(GDScriptSignalName.CustomSignal)
			&& node.HasMethod(GDScriptMethodName.InitDialogue)
			&& node.HasMethod(GDScriptMethodName.SetShot)
			&& node.HasMethod(GDScriptMethodName.StartDialogue)
			&& node.HasMethod(GDScriptMethodName.StopDialogue)
			&& node.HasMethod(GDScriptMethodName.StartAutoplay)
			&& node.HasMethod(GDScriptMethodName.SetCharaList)
			&& node.HasMethod(GDScriptMethodName.SetBackgroundList)
			&& node.HasMethod(GDScriptMethodName.SetBgmList)
			&& node.HasMethod(GDScriptMethodName.GetDialogueVariable)
			&& node.HasMethod(GDScriptMethodName.SaveGame)
			&& node.HasMethod(GDScriptMethodName.LoadGame)
			&& node.HasMethod(GDScriptMethodName.DeleteSave)
			&& node.HasMethod(GDScriptMethodName.GetSaveInfo)
			&& node.HasMethod(GDScriptMethodName.GetAllSaveInfo)
			&& node.HasMethod(GDScriptMethodName.SetSaveStrategy)
			&& node.HasMethod(GDScriptMethodName.GetSaveStrategy)
			&& node.HasMethod(GDScriptMethodName.ReloadLocalizedScript)
			&& node.HasMethod(GDScriptMethodName.EmitWaitSignal);
	}

	private Node? GetReadySource()
	{
		var source = Source;
		if (source != null)
			return source;

		ClearSource();
		return BindDialogueManager() ? Source : null;
	}

	private void ClearSource()
	{
		DisconnectSignals(_source);
		_source = null;
	}

	private static bool HasCallable(Callable callable)
		=> callable.Delegate != null || callable.Target != null;

	private static void ConnectSignal(Node? source, StringName signalName, Callable callable)
	{
		if (source == null
			|| !IsInstanceValid(source)
			|| !source.HasSignal(signalName)
			|| !HasCallable(callable)
			|| source.IsConnected(signalName, callable))
		{
			return;
		}

		source.Connect(signalName, callable);
	}

	private static void DisconnectSignal(Node? source, StringName signalName, Callable callable)
	{
		if (source == null
			|| !IsInstanceValid(source)
			|| !HasCallable(callable)
			|| !source.IsConnected(signalName, callable))
		{
			return;
		}

		source.Disconnect(signalName, callable);
	}

	private void ConnectSignals()
	{
		var source = Source;
		if (source == null)
			return;

		if (_shotStartSignal != null)
		{
			if (!HasCallable(_shotStartSignalCallable))
				_shotStartSignalCallable = Callable.From(() => _shotStartSignal?.Invoke());
			ConnectSignal(source, GDScriptSignalName.ShotStart, _shotStartSignalCallable);
		}

		if (_shotEndSignal != null)
		{
			if (!HasCallable(_shotEndSignalCallable))
				_shotEndSignalCallable = Callable.From(() => _shotEndSignal?.Invoke());
			ConnectSignal(source, GDScriptSignalName.ShotEnd, _shotEndSignalCallable);
		}

		if (_dialogueLineStartSignal != null)
		{
			if (!HasCallable(_dialogueLineStartSignalCallable))
				_dialogueLineStartSignalCallable = Callable.From(
					(string nodeId) => _dialogueLineStartSignal?.Invoke(nodeId));
			ConnectSignal(source, GDScriptSignalName.DialogueLineStart, _dialogueLineStartSignalCallable);
		}

		if (_dialogueLineEndSignal != null)
		{
			if (!HasCallable(_dialogueLineEndSignalCallable))
				_dialogueLineEndSignalCallable = Callable.From(
					(string nodeId) => _dialogueLineEndSignal?.Invoke(nodeId));
			ConnectSignal(source, GDScriptSignalName.DialogueLineEnd, _dialogueLineEndSignalCallable);
		}

		if (_customSignal != null)
		{
			if (!HasCallable(_customSignalCallable))
				_customSignalCallable = Callable.From(
					(string content) => _customSignal?.Invoke(content));
			ConnectSignal(source, GDScriptSignalName.CustomSignal, _customSignalCallable);
		}
	}

	private void DisconnectSignals(Node? source)
	{
		DisconnectSignal(source, GDScriptSignalName.ShotStart, _shotStartSignalCallable);
		DisconnectSignal(source, GDScriptSignalName.ShotEnd, _shotEndSignalCallable);
		DisconnectSignal(source, GDScriptSignalName.DialogueLineStart, _dialogueLineStartSignalCallable);
		DisconnectSignal(source, GDScriptSignalName.DialogueLineEnd, _dialogueLineEndSignalCallable);
		DisconnectSignal(source, GDScriptSignalName.CustomSignal, _customSignalCallable);
	}

	public override void _ExitTree()
	{
		DisconnectTreeSignals();
		ClearSource();
	}

	public static class GDScriptSignalName
	{
		public static readonly StringName ShotStart = "shot_start";
		public static readonly StringName ShotEnd = "shot_end";
		public static readonly StringName DialogueLineStart = "dialogue_line_start";
		public static readonly StringName DialogueLineEnd = "dialogue_line_end";
		public static readonly StringName CustomSignal = "custom_signal";
	}

	public delegate void ShotStartSignalHandler();
	private ShotStartSignalHandler? _shotStartSignal;
	private Callable _shotStartSignalCallable;
	public event ShotStartSignalHandler ShotStart
	{
		add
		{
			_shotStartSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_shotStartSignal -= value;
			if (_shotStartSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.ShotStart, _shotStartSignalCallable);
			_shotStartSignalCallable = default;
		}
	}

	public delegate void ShotEndSignalHandler();
	private ShotEndSignalHandler? _shotEndSignal;
	private Callable _shotEndSignalCallable;
	public event ShotEndSignalHandler ShotEnd
	{
		add
		{
			_shotEndSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_shotEndSignal -= value;
			if (_shotEndSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.ShotEnd, _shotEndSignalCallable);
			_shotEndSignalCallable = default;
		}

	}

	public delegate void DialogueLineStartSignalHandler(string nodeId);
	private DialogueLineStartSignalHandler? _dialogueLineStartSignal;
	private Callable _dialogueLineStartSignalCallable;
	public event DialogueLineStartSignalHandler DialogueLineStart
	{
		add
		{
			_dialogueLineStartSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_dialogueLineStartSignal -= value;
			if (_dialogueLineStartSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.DialogueLineStart, _dialogueLineStartSignalCallable);
			_dialogueLineStartSignalCallable = default;
		}
	}

	public delegate void DialogueLineEndSignalHandler(string nodeId);
	private DialogueLineEndSignalHandler? _dialogueLineEndSignal;
	private Callable _dialogueLineEndSignalCallable;
	public event DialogueLineEndSignalHandler DialogueLineEnd
	{
		add
		{
			_dialogueLineEndSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_dialogueLineEndSignal -= value;
			if (_dialogueLineEndSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.DialogueLineEnd, _dialogueLineEndSignalCallable);
			_dialogueLineEndSignalCallable = default;
		}
	}

	public delegate void CustomSignalHandler(string content);
	private CustomSignalHandler? _customSignal;
	private Callable _customSignalCallable;
	public event CustomSignalHandler CustomSignal
	{
		add
		{
			_customSignal += value;
			if (GetReadySource() != null)
				ConnectSignals();
		}
		remove
		{
			_customSignal -= value;
			if (_customSignal is not null) return;
			DisconnectSignal(_source, GDScriptSignalName.CustomSignal, _customSignalCallable);
			_customSignalCallable = default;
		}
	}

	public static class GDScriptMethodName
	{
		public static readonly StringName InitDialogue = "init_dialogue";
		public static readonly StringName SetShot = "set_shot";
		public static readonly StringName StartDialogue = "start_dialogue";
		public static readonly StringName StopDialogue = "stop_dialogue";
		public static readonly StringName StartAutoplay = "start_autoplay";
		public static readonly StringName SetCharaList = "set_chara_list";
		public static readonly StringName SetBackgroundList = "set_background_list";
		public static readonly StringName SetBgmList = "set_bgm_list";
		public static readonly StringName GetDialogueVariable = "get_dialogue_variable";
		public static readonly StringName SaveGame = "save_game";
		public static readonly StringName LoadGame = "load_game";
		public static readonly StringName DeleteSave = "delete_save";
		public static readonly StringName GetSaveInfo = "get_save_info";
		public static readonly StringName GetAllSaveInfo = "get_all_save_info";
		public static readonly StringName SetSaveStrategy = "set_save_strategy";
		public static readonly StringName GetSaveStrategy = "get_save_strategy";
		public static readonly StringName ReloadLocalizedScript = "reload_localized_script";
		public static readonly StringName EmitWaitSignal = "emit_wait_signal";
	}

	/// <summary>
	/// 初始化对话，调用 Konado DialogueManager 节点的 init_dialogue 方法
	/// </summary>
	public void InitDialogue()
	{
		GetReadySource()?.Call(GDScriptMethodName.InitDialogue);
	}

	public void InitDialogue(Callable callback)
	{
		GetReadySource()?.Call(GDScriptMethodName.InitDialogue, callback);
	}

	public void SetShot(Resource shot)
	{
		System.ArgumentNullException.ThrowIfNull(shot);
		GetReadySource()?.Call(GDScriptMethodName.SetShot, shot);
	}

	public void SetShot(KndShot shot)
	{
		System.ArgumentNullException.ThrowIfNull(shot);
		SetShot(shot.SourceResource);
	}

	/// <summary>
	/// 开始对话，调用 Konado DialogueManager 节点的 start_dialogue 方法
	/// </summary>
	public void StartDialogue()
	{
		GetReadySource()?.Call(GDScriptMethodName.StartDialogue);
	}

	/// <summary>
	/// 停止对话，调用 Konado DialogueManager 节点的 stop_dialogue 方法
	/// </summary>
	public void StopDialogue()
	{
		GetReadySource()?.Call(GDScriptMethodName.StopDialogue);
	}

	public void StartAutoplay(bool value)
	{
		GetReadySource()?.Call(GDScriptMethodName.StartAutoplay, value);
	}

	public void SetCharaList(Resource charaList)
	{
		GetReadySource()?.Call(GDScriptMethodName.SetCharaList, charaList);
	}

	public void SetBackgroundList(Resource backgroundList)
	{
		GetReadySource()?.Call(GDScriptMethodName.SetBackgroundList, backgroundList);
	}

	public void SetBgmList(Resource bgmList)
	{
		GetReadySource()?.Call(GDScriptMethodName.SetBgmList, bgmList);
	}

	public Godot.Collections.Dictionary GetDialogueVariable(string key)
	{
		var source = GetReadySource();
		return source == null
			? new Godot.Collections.Dictionary()
			: source.Call(GDScriptMethodName.GetDialogueVariable, key).AsGodotDictionary();
	}

	public bool SaveGame(int saveId)
	{
		var source = GetReadySource();
		return source != null && source.Call(GDScriptMethodName.SaveGame, saveId).As<bool>();
	}

	public bool LoadGame(int saveId)
	{
		var source = GetReadySource();
		return source != null && source.Call(GDScriptMethodName.LoadGame, saveId).As<bool>();
	}

	public bool DeleteSave(int saveId)
	{
		var source = GetReadySource();
		return source != null && source.Call(GDScriptMethodName.DeleteSave, saveId).As<bool>();
	}

	public Godot.Collections.Dictionary GetSaveInfo(int saveId)
	{
		var source = GetReadySource();
		return source == null
			? new Godot.Collections.Dictionary()
			: source.Call(GDScriptMethodName.GetSaveInfo, saveId).AsGodotDictionary();
	}

	public Godot.Collections.Array<Godot.Collections.Dictionary> GetAllSaveInfo()
	{
		var source = GetReadySource();
		return source == null
			? new Godot.Collections.Array<Godot.Collections.Dictionary>()
			: source.Call(GDScriptMethodName.GetAllSaveInfo)
				.AsGodotArray<Godot.Collections.Dictionary>();
	}

	public void SetSaveStrategy(Godot.Collections.Dictionary strategy)
	{
		GetReadySource()?.Call(GDScriptMethodName.SetSaveStrategy, strategy);
	}

	public Godot.Collections.Dictionary GetSaveStrategy()
	{
		var source = GetReadySource();
		return source == null
			? new Godot.Collections.Dictionary()
			: source.Call(GDScriptMethodName.GetSaveStrategy).AsGodotDictionary();
	}

	public bool ReloadLocalizedScript(string locale)
	{
		var source = GetReadySource();
		return source != null
			&& source.Call(GDScriptMethodName.ReloadLocalizedScript, locale).As<bool>();
	}

	public void EmitWaitSignal(string signalName)
	{
		GetReadySource()?.Call(GDScriptMethodName.EmitWaitSignal, signalName);
	}
}
