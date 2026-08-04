from pathlib import Path

main_path = Path('flutter_app/lib/main.dart')
pubspec_path = Path('flutter_app/pubspec.yaml')

text = main_path.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise SystemExit(f'Bloco não encontrado: {label}')
    text = text.replace(old, new, 1)


replace_once(
    """  bool _loading = true;\n  bool _saving = false;\n  bool _saveAgain = false;\n  bool _plantelViewActive = false;\n  bool _dragInteractionActive = false;\n  Map<String, _Snapshot>? _plantelSnapshot;\n  Timer? _saveTimer;\n  Timer? _retryTimer;\n""",
    """  bool _loading = true;\n  bool _saving = false;\n  bool _syncing = false;\n  bool _saveAgain = false;\n  bool _plantelViewActive = false;\n  bool _dragInteractionActive = false;\n  Map<String, _Snapshot>? _plantelSnapshot;\n  Timer? _saveTimer;\n  Timer? _retryTimer;\n  Timer? _syncTimer;\n""",
    'estado de sincronização',
)

replace_once(
    """  void initState() {\n    super.initState();\n    WidgetsBinding.instance.addObserver(this);\n    _load();\n  }\n""",
    """  void initState() {\n    super.initState();\n    WidgetsBinding.instance.addObserver(this);\n    _load();\n    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {\n      if (!_loading) unawaited(_syncFromRemote());\n    });\n  }\n""",
    'initState',
)

replace_once(
    """    _saveTimer?.cancel();\n    _retryTimer?.cancel();\n""",
    """    _saveTimer?.cancel();\n    _retryTimer?.cancel();\n    _syncTimer?.cancel();\n""",
    'dispose timers',
)

replace_once(
    """  void didChangeAppLifecycleState(AppLifecycleState state) {\n    if (state == AppLifecycleState.resumed) _saveOnline();\n  }\n""",
    """  void didChangeAppLifecycleState(AppLifecycleState state) {\n    if (state == AppLifecycleState.resumed) {\n      unawaited(_syncFromRemote(showStatus: true));\n    }\n  }\n""",
    'lifecycle resume',
)

replace_once(
    """  void _scheduleRetry() {\n    _retryTimer?.cancel();\n    _retryTimer = Timer(const Duration(seconds: 15), () {\n      _retryTimer = null;\n      _saveOnline();\n    });\n  }\n\n  void _setDragInteraction(bool active) {\n""",
    """  void _scheduleRetry() {\n    _retryTimer?.cancel();\n    _retryTimer = Timer(const Duration(seconds: 15), () async {\n      _retryTimer = null;\n      final receivedNewer = await _syncFromRemote();\n      if (!receivedNewer && !(_saveTimer?.isActive ?? false)) {\n        unawaited(_saveOnline());\n      }\n    });\n  }\n\n  Future<bool> _syncFromRemote({bool showStatus = false}) async {\n    if (_loading ||\n        _syncing ||\n        _saving ||\n        _dragInteractionActive ||\n        _plantelViewActive ||\n        (_saveTimer?.isActive ?? false)) {\n      return false;\n    }\n\n    _syncing = true;\n    try {\n      final remote = await _storage.loadRemote();\n      if (remote.updatedAt <= _data.updatedAt) {\n        if (showStatus && mounted) {\n          setState(() => _saveStatus = 'Plantel online sincronizado');\n        }\n        return false;\n      }\n\n      _data = remote;\n      _ensureTactics();\n      _activeTactic.apply(_data.players);\n      _selectedCardId = null;\n      await _storage.saveLocal(_data);\n\n      if (mounted) {\n        final t = TimeOfDay.now().format(context);\n        setState(() => _saveStatus = 'Atualizado de outro dispositivo às $t');\n      }\n      return true;\n    } catch (_) {\n      if (showStatus && mounted) {\n        setState(() => _saveStatus = 'Guardado');\n      }\n      return false;\n    } finally {\n      _syncing = false;\n    }\n  }\n\n  void _setDragInteraction(bool active) {\n""",
    'retry e receção remota',
)

old_save = """  Future<bool> _saveOnline({bool manual = false}) async {\n    if (_saving) {\n      if (manual) {\n        while (_saving) {\n          await Future<void>.delayed(const Duration(milliseconds: 100));\n        }\n      } else {\n        _saveAgain = true;\n        return false;\n      }\n    }\n    _saving = true;\n    _retryTimer?.cancel();\n    try {\n      await _persistLocal();\n      if (manual && mounted) setState(() => _saveStatus = 'A guardar online…');\n      await _storage.saveRemote(_data);\n      if (mounted) {\n        final t = TimeOfDay.now().format(context);\n        setState(() => _saveStatus = 'Guardado online às $t');\n      }\n      return true;\n    } catch (_) {\n      if (mounted) setState(() => _saveStatus = 'Guardado');\n      _scheduleRetry();\n      return false;\n    } finally {\n      _saving = false;\n      if (_saveAgain) {\n        _saveAgain = false;\n        unawaited(_saveOnline());\n      }\n    }\n  }\n"""

new_save = """  Future<bool> _saveOnline({bool manual = false}) async {\n    if (_saving) {\n      if (manual) {\n        while (_saving) {\n          await Future<void>.delayed(const Duration(milliseconds: 100));\n        }\n      } else {\n        _saveAgain = true;\n        return false;\n      }\n    }\n    _saving = true;\n    _retryTimer?.cancel();\n    try {\n      await _persistLocal();\n      if (manual && mounted) {\n        setState(() => _saveStatus = 'A sincronizar online…');\n      }\n\n      // Antes de gravar, confirmar sempre se outro dispositivo já publicou\n      // uma versão mais recente. Isto evita que dados antigos a sobrescrevam.\n      final remote = await _storage.loadRemote();\n      if (remote.updatedAt > _data.updatedAt) {\n        _data = remote;\n        _ensureTactics();\n        _activeTactic.apply(_data.players);\n        _selectedCardId = null;\n        await _storage.saveLocal(_data);\n        if (mounted) {\n          final t = TimeOfDay.now().format(context);\n          setState(() => _saveStatus = 'Atualizado de outro dispositivo às $t');\n        }\n        return true;\n      }\n\n      if (remote.updatedAt < _data.updatedAt) {\n        await _storage.saveRemote(_data);\n      }\n\n      if (mounted) {\n        final t = TimeOfDay.now().format(context);\n        setState(() => _saveStatus = 'Guardado online às $t');\n      }\n      return true;\n    } catch (_) {\n      if (mounted) setState(() => _saveStatus = 'Guardado');\n      _scheduleRetry();\n      return false;\n    } finally {\n      _saving = false;\n      if (_saveAgain) {\n        _saveAgain = false;\n        unawaited(_saveOnline());\n      }\n    }\n  }\n"""
replace_once(old_save, new_save, 'saveOnline seguro')

main_path.write_text(text, encoding='utf-8')

pubspec = pubspec_path.read_text(encoding='utf-8')
if 'version: 1.0.5+6' not in pubspec:
    raise SystemExit('Versão esperada 1.0.5+6 não encontrada')
pubspec = pubspec.replace('version: 1.0.5+6', 'version: 1.0.6+7', 1)
pubspec_path.write_text(pubspec, encoding='utf-8')

print('Sincronização multi-dispositivo corrigida; versão 1.0.6+7.')
