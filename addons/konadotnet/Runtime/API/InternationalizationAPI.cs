using Godot;
using Konado.Wrapper;

namespace Konado.Runtime.API;

public sealed partial class InternationalizationAPI : Node
{
	private const string AutoloadName = "KND_I18n";

	private Node? _source;
	private LocaleChangedHandler? _localeChanged;
	private Callable _localeChangedCallable;

	public delegate void LocaleChangedHandler(string locale);

	public bool IsReady => _source != null
		&& IsInstanceValid(_source)
		&& HasInternationalizationContract(_source);

	public Node? Source => IsReady ? _source : null;

	public string Locale
	{
		get
		{
			var source = GetReadySource();
			return source == null
				? string.Empty
				: source.Call(GDScriptMethodName.GetLocale).As<string>();
		}
	}

	public string[] AvailableLocales
	{
		get
		{
			var source = GetReadySource();
			return source == null
				? []
				: source.Call(GDScriptMethodName.GetAvailableLocales).AsStringArray();
		}
	}

	public event LocaleChangedHandler LocaleChanged
	{
		add
		{
			_localeChanged += value;
			ConnectSignals();
		}
		remove
		{
			_localeChanged -= value;
			if (_localeChanged is not null)
				return;
			DisconnectSignal(_source);
			_localeChangedCallable = default;
		}
	}

	public override void _Ready()
	{
		Bind();
	}

	public override void _ExitTree()
	{
		DisconnectSignal(_source);
		_source = null;
	}

	public bool Bind(Node? source = null)
	{
		var target = source ?? GetTree().Root.GetNodeOrNull<Node>(AutoloadName);
		if (target == null || !HasInternationalizationContract(target))
		{
			DisconnectSignal(_source);
			_source = null;
			return false;
		}

		if (_source != target)
		{
			DisconnectSignal(_source);
			_source = target;
		}
		ConnectSignals();
		return true;
	}

	public bool SetLocale(string locale, bool persist = true)
	{
		var source = GetReadySource();
		return source != null
			&& source.Call(GDScriptMethodName.SetLocale, locale, persist).As<bool>();
	}

	public string NormalizeLocale(string locale)
	{
		var source = GetReadySource();
		return source == null
			? string.Empty
			: source.Call(GDScriptMethodName.NormalizeLocale, locale).As<string>();
	}

	public bool RegisterTranslation(Translation translation)
	{
		var source = GetReadySource();
		return source != null
			&& source.Call(GDScriptMethodName.RegisterTranslation, translation).As<bool>();
	}

	public bool UnregisterTranslation(string locale)
	{
		var source = GetReadySource();
		return source != null
			&& source.Call(GDScriptMethodName.UnregisterTranslation, locale).As<bool>();
	}

	public string ResolveScriptPath(
		string scriptPath,
		string locale = "",
		bool warnOnFallback = true)
	{
		var source = GetReadySource();
		return source == null
			? string.Empty
			: source.Call(
				GDScriptMethodName.ResolveScriptPath,
				scriptPath,
				locale,
				warnOnFallback).As<string>();
	}

	public KndShot? LoadLocalizedScript(
		string scriptPath,
		string locale = "",
		bool warnOnFallback = true)
	{
		var source = GetReadySource();
		if (source == null)
			return null;
		var shot = source.Call(
			GDScriptMethodName.LoadLocalizedScript,
			scriptPath,
			locale,
			warnOnFallback).As<Resource>();
		return shot == null ? null : new KndShot(shot);
	}

	private Node? GetReadySource()
	{
		return Source ?? (Bind() ? Source : null);
	}

	private void ConnectSignals()
	{
		var source = GetReadySource();
		if (source == null || _localeChanged == null)
			return;
		if (_localeChangedCallable.Delegate == null && _localeChangedCallable.Target == null)
		{
			_localeChangedCallable = Callable.From(
				(string locale) => _localeChanged?.Invoke(locale));
		}
		if (!source.IsConnected(GDScriptSignalName.LocaleChanged, _localeChangedCallable))
			source.Connect(GDScriptSignalName.LocaleChanged, _localeChangedCallable);
	}

	private void DisconnectSignal(Node? source)
	{
		if (source == null
			|| !IsInstanceValid(source)
			|| _localeChangedCallable.Delegate == null && _localeChangedCallable.Target == null
			|| !source.IsConnected(GDScriptSignalName.LocaleChanged, _localeChangedCallable))
		{
			return;
		}
		source.Disconnect(GDScriptSignalName.LocaleChanged, _localeChangedCallable);
	}

	private static bool HasInternationalizationContract(Node source)
	{
		return IsInstanceValid(source)
			&& source.HasSignal(GDScriptSignalName.LocaleChanged)
			&& source.HasMethod(GDScriptMethodName.GetLocale)
			&& source.HasMethod(GDScriptMethodName.GetAvailableLocales)
			&& source.HasMethod(GDScriptMethodName.SetLocale)
			&& source.HasMethod(GDScriptMethodName.NormalizeLocale)
			&& source.HasMethod(GDScriptMethodName.RegisterTranslation)
			&& source.HasMethod(GDScriptMethodName.UnregisterTranslation)
			&& source.HasMethod(GDScriptMethodName.ResolveScriptPath)
			&& source.HasMethod(GDScriptMethodName.LoadLocalizedScript);
	}

	public static class GDScriptSignalName
	{
		public static readonly StringName LocaleChanged = "locale_changed";
	}

	public static class GDScriptMethodName
	{
		public static readonly StringName GetLocale = "get_locale";
		public static readonly StringName GetAvailableLocales = "get_available_locales";
		public static readonly StringName SetLocale = "set_locale";
		public static readonly StringName NormalizeLocale = "normalize_locale";
		public static readonly StringName RegisterTranslation = "register_translation";
		public static readonly StringName UnregisterTranslation = "unregister_translation";
		public static readonly StringName ResolveScriptPath = "resolve_script_path";
		public static readonly StringName LoadLocalizedScript = "load_localized_script";
	}
}
