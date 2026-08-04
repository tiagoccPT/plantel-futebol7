import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'field_widget.dart';
import 'models.dart';
import 'storage_service.dart';

const _bg = Color(0xFF0B1220);
const _panel = Color(0xFF121C2E);
const _panel2 = Color(0xFF0E1828);
const _border = Color(0xFF273750);
const _primary = Color(0xFF1976D2);
const _gold = Color(0xFFD4AF37);
const _muted = Color(0xFFAEBED4);
const _reserve = Color(0xFF6B7280);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlantelApp());
}

class PlantelApp extends StatelessWidget {
  const PlantelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
      surface: _panel,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestor de Plantel — Futebol de 7',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: _bg,
        cardColor: _panel,
        dividerColor: _border,
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: _panel2,
          indicatorColor: Color(0xFF153A63),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _panel2,
          labelStyle: const TextStyle(color: _muted),
          hintStyle: const TextStyle(color: Color(0xFF7F91AA)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
      ),
      home: const PlantelHomePage(),
    );
  }
}

class _Snapshot {
  _Snapshot({required this.selected, required this.status, required this.cards});
  final bool selected;
  final PlayerStatus status;
  final List<CardData> cards;
}

class PlantelHomePage extends StatefulWidget {
  const PlantelHomePage({super.key});

  @override
  State<PlantelHomePage> createState() => _PlantelHomePageState();
}

class _PlantelHomePageState extends State<PlantelHomePage>
    with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  final _nome = TextEditingController();
  final _ano = TextEditingController();
  final _numero = TextEditingController();
  final _principal = TextEditingController();
  final _secundaria = TextEditingController();

  PlantelStateData _data = PlantelStateData.empty();
  String? _selectedCardId;
  String? _compareLeftId;
  String? _compareRightId;
  String _saveStatus = 'A carregar…';
  int _sectionIndex = 0;
  bool _loading = true;
  bool _saving = false;
  bool _saveAgain = false;
  bool _plantelViewActive = false;
  bool _dragInteractionActive = false;
  Map<String, _Snapshot>? _plantelSnapshot;
  Timer? _saveTimer;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _retryTimer?.cancel();
    _nome.dispose();
    _ano.dispose();
    _numero.dispose();
    _principal.dispose();
    _secundaria.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _saveOnline();
  }

  void _ensureTactics() {
    if (_data.tactics.isNotEmpty) return;
    final tactic = TacticData.fromPlayers(name: 'Tática 1', players: _data.players);
    _data.tactics.add(tactic);
    _data.activeTacticId = tactic.id;
  }

  TacticData get _activeTactic {
    _ensureTactics();
    return _data.activeTactic;
  }

  void _syncActiveTacticFromPlayers() {
    if (_plantelViewActive) return;
    _ensureTactics();
    _activeTactic.capture(_data.players);
  }

  Future<void> _load() async {
    await _storage.loadSavedDbId();
    final local = await _storage.loadLocal();
    if (!mounted) return;
    setState(() {
      _data = local;
      _ensureTactics();
      _activeTactic.apply(_data.players);
      _loading = false;
      _saveStatus = local.players.isEmpty ? 'A carregar online…' : 'Guardado';
    });

    try {
      final remote = await _storage.loadRemote();
      if (remote.updatedAt >= _data.updatedAt) {
        _data = remote;
        _ensureTactics();
        _activeTactic.apply(_data.players);
        await _storage.saveLocal(_data);
        if (mounted) setState(() {});
      } else if (_data.players.isNotEmpty) {
        _syncActiveTacticFromPlayers();
        await _storage.saveRemote(_data);
      }
      if (mounted) setState(() => _saveStatus = 'Plantel online sincronizado');
    } catch (_) {
      if (mounted) setState(() => _saveStatus = 'Guardado');
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 15), () {
      _retryTimer = null;
      _saveOnline();
    });
  }

  void _setDragInteraction(bool active) {
    if (!mounted || _dragInteractionActive == active) return;
    setState(() => _dragInteractionActive = active);
  }

  void _rememberPlantelLayout() {
    for (final player in _data.players) {
      player.plantelCards = player.cards.map((e) => e.clone()).toList();
    }
  }

  Future<void> _persistLocal() async {
    if (_plantelViewActive) {
      _rememberPlantelLayout();
    } else {
      _syncActiveTacticFromPlayers();
    }
    await _storage.saveLocal(_data);
  }

  void _changed({bool debounce = false}) {
    if (!_plantelViewActive) _syncActiveTacticFromPlayers();
    _data.updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (mounted) setState(() => _saveStatus = 'Guardado');
    _saveTimer?.cancel();
    if (debounce) {
      _saveTimer = Timer(const Duration(milliseconds: 350), () async {
        await _persistLocal();
        await _saveOnline();
      });
    } else {
      _persistLocal();
      _saveTimer = Timer(const Duration(milliseconds: 700), _saveOnline);
    }
  }

  Future<bool> _saveOnline({bool manual = false}) async {
    if (_saving) {
      if (manual) {
        while (_saving) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      } else {
        _saveAgain = true;
        return false;
      }
    }
    _saving = true;
    _retryTimer?.cancel();
    try {
      await _persistLocal();
      if (manual && mounted) setState(() => _saveStatus = 'A guardar online…');
      await _storage.saveRemote(_data);
      if (mounted) {
        final t = TimeOfDay.now().format(context);
        setState(() => _saveStatus = 'Guardado online às $t');
      }
      return true;
    } catch (_) {
      if (mounted) setState(() => _saveStatus = 'Guardado');
      _scheduleRetry();
      return false;
    } finally {
      _saving = false;
      if (_saveAgain) {
        _saveAgain = false;
        unawaited(_saveOnline());
      }
    }
  }

  void _addPlayer() {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica o nome do jogador.')),
      );
      return;
    }
    if (_plantelViewActive) _restorePlantelSnapshot(save: false);
    setState(() {
      _data.players.add(Player(
        id: uid(),
        nome: nome,
        ano: _ano.text.trim(),
        numero: _numero.text.trim(),
        principal: _principal.text.trim(),
        secundaria: _secundaria.text.trim(),
      ));
      _nome.clear();
      _ano.clear();
      _numero.clear();
      _principal.clear();
      _secundaria.clear();
    });
    _changed();
  }

  void _placePlayer(Player player, PlayerStatus requested) {
    if (_plantelViewActive) _restorePlantelSnapshot(save: false);
    final same = player.selected && player.status == requested;
    setState(() {
      if (same) {
        player.selected = false;
        player.cards = <CardData>[];
      } else {
        player.status = requested;
        player.selected = true;
        player.cards = requested == PlayerStatus.inicial
            ? buildPlayerCards(player)
            : <CardData>[];
      }
      if (_selectedCardId != null && !_cardExists(_selectedCardId!)) {
        _selectedCardId = null;
      }
    });
    _changed();
  }

  void _promoteSubstitute(Player player) {
    if (_plantelViewActive) _restorePlantelSnapshot(save: false);
    setState(() {
      player.status = PlayerStatus.inicial;
      player.selected = true;
      player.cards = buildPlayerCards(player);
    });
    _changed();
  }

  bool _cardExists(String id) {
    return _data.players.any((p) => p.cards.any((card) => card.id == id));
  }

  List<CardData> _rememberedPlantelCards(Player player) {
    final source = player.plantelCards.isNotEmpty ? player.plantelCards : player.cards;
    return rebuildCardsPreservingLayout(player, source);
  }

  void _togglePlantel() {
    if (!_plantelViewActive) {
      _syncActiveTacticFromPlayers();
      _plantelSnapshot = {
        for (final player in _data.players)
          player.id: _Snapshot(
            selected: player.selected,
            status: player.status,
            cards: player.cards.map((e) => e.clone()).toList(),
          ),
      };
      setState(() {
        for (final player in _data.players) {
          player.cards = _rememberedPlantelCards(player);
        }
        _plantelViewActive = true;
        _selectedCardId = null;
      });
      return;
    }
    _restorePlantelSnapshot(save: true);
  }

  void _restorePlantelSnapshot({required bool save}) {
    if (!_plantelViewActive) return;
    _rememberPlantelLayout();
    final snapshot = _plantelSnapshot ?? const <String, _Snapshot>{};
    setState(() {
      for (final player in _data.players) {
        final saved = snapshot[player.id];
        if (saved == null) continue;
        player.selected = saved.selected;
        player.status = saved.status;
        player.cards = saved.cards.map((e) => e.clone()).toList();
      }
      _plantelViewActive = false;
      _plantelSnapshot = null;
      _selectedCardId = null;
    });
    if (save) _changed();
  }

  void _clearField() {
    if (_plantelViewActive) _restorePlantelSnapshot(save: false);
    setState(() {
      _selectedCardId = null;
      for (final player in _data.players) {
        if (player.status == PlayerStatus.inicial) {
          player.selected = false;
          player.cards = <CardData>[];
        }
      }
    });
    _changed();
  }

  void _removePlayer(Player player) {
    if (_plantelViewActive) _restorePlantelSnapshot(save: false);
    setState(() {
      _data.players.removeWhere((p) => p.id == player.id);
      for (final tactic in _data.tactics) {
        tactic.playerStates.removeWhere((s) => s.playerId == player.id);
      }
      if (_selectedCardId != null && !_cardExists(_selectedCardId!)) {
        _selectedCardId = null;
      }
    });
    _changed();
  }

  Future<void> _editPlayer(Player player) async {
    if (_plantelViewActive) _restorePlantelSnapshot(save: false);
    final numero = TextEditingController(text: player.numero);
    final nome = TextEditingController(text: player.nome);
    final ano = TextEditingController(text: player.ano);
    final principal = TextEditingController(text: player.principal);
    final secundaria = TextEditingController(text: player.secundaria);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar jogador'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(numero, 'N.º camisola'),
                _dialogField(nome, 'Nome'),
                _dialogField(ano, 'Ano de nascimento'),
                _dialogField(principal, 'Posição principal'),
                _dialogField(secundaria, 'Posição secundária'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (saved != true || nome.text.trim().isEmpty) return;
    final oldCards = player.cards.map((e) => e.clone()).toList();
    final oldPlantel = player.plantelCards.map((e) => e.clone()).toList();
    setState(() {
      player.numero = numero.text.trim();
      player.nome = nome.text.trim();
      player.ano = ano.text.trim();
      player.principal = principal.text.trim();
      player.secundaria = secundaria.text.trim();
      if (player.selected && player.status == PlayerStatus.inicial) {
        player.cards = rebuildCardsPreservingLayout(player, oldCards);
      }
      if (oldPlantel.isNotEmpty) {
        player.plantelCards = rebuildCardsPreservingLayout(player, oldPlantel);
      }
    });
    _changed();
  }

  Widget _dialogField(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
      );

  void _reorderPlayers(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final player = _data.players.removeAt(oldIndex);
      _data.players.insert(newIndex, player);
    });
    _changed();
  }

  void _moveCard(String playerId, String cardId, double dx, double dy) {
    final card = _findCard(playerId, cardId);
    if (card == null) return;
    setState(() {
      card.x = (card.x + dx).clamp(20.0, 780.0 - card.width).toDouble();
      card.y = (card.y + dy).clamp(20.0, 1080.0 - card.height).toDouble();
    });
    _changed(debounce: true);
  }

  void _resizeCard(String playerId, String cardId, double dw, double dh) {
    final card = _findCard(playerId, cardId);
    if (card == null) return;
    setState(() {
      card.width = (card.width + dw).clamp(72.0, 400.0).toDouble();
      card.height = (card.height + dh).clamp(38.0, 220.0).toDouble();
      card.x = card.x.clamp(20.0, 780.0 - card.width).toDouble();
      card.y = card.y.clamp(20.0, 1080.0 - card.height).toDouble();
    });
    _changed(debounce: true);
  }

  void _fontChange(String playerId, String cardId, double delta) {
    final card = _findCard(playerId, cardId);
    if (card == null) return;
    setState(() => card.fontSize = (card.fontSize + delta).clamp(8.0, 40.0).toDouble());
    _changed();
  }

  CardData? _findCard(String playerId, String cardId) {
    final player = _data.players.where((p) => p.id == playerId).firstOrNull;
    return player?.cards.where((c) => c.id == cardId).firstOrNull;
  }

  Future<String?> _askTacticName(String initial, String title) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da tática'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Guardar')),
        ],
      ),
    );
    final name = result?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  Future<void> _createTactic() async {
    if (_plantelViewActive) _restorePlantelSnapshot(save: false);
    _syncActiveTacticFromPlayers();
    final name = await _askTacticName('Tática ${_data.tactics.length + 1}', 'Nova tática');
    if (name == null) return;
    final tactic = _activeTactic.duplicate(name);
    setState(() {
      _data.tactics.add(tactic);
      _data.activeTacticId = tactic.id;
      tactic.apply(_data.players);
      _compareRightId ??= tactic.id;
      _sectionIndex = 0;
    });
    _changed();
  }

  Future<void> _renameTactic(TacticData tactic) async {
    final name = await _askTacticName(tactic.name, 'Renomear tática');
    if (name == null) return;
    setState(() => tactic.name = name);
    _changed();
  }

  Future<void> _duplicateTactic(TacticData tactic) async {
    final name = await _askTacticName('${tactic.name} — cópia', 'Duplicar tática');
    if (name == null) return;
    setState(() => _data.tactics.add(tactic.duplicate(name)));
    _changed();
  }

  void _deleteTactic(TacticData tactic) {
    if (_data.tactics.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tem de existir pelo menos uma tática.')),
      );
      return;
    }
    setState(() {
      final wasActive = tactic.id == _data.activeTacticId;
      _data.tactics.removeWhere((t) => t.id == tactic.id);
      if (_compareLeftId == tactic.id) _compareLeftId = null;
      if (_compareRightId == tactic.id) _compareRightId = null;
      if (wasActive) {
        _data.activeTacticId = _data.tactics.first.id;
        _activeTactic.apply(_data.players);
      }
    });
    _changed();
  }

  void _switchTactic(String tacticId, {bool openPlantel = false}) {
    if (_plantelViewActive) _restorePlantelSnapshot(save: false);
    if (!_data.tactics.any((t) => t.id == tacticId)) return;
    _syncActiveTacticFromPlayers();
    setState(() {
      _data.activeTacticId = tacticId;
      _activeTactic.apply(_data.players);
      _selectedCardId = null;
      if (openPlantel) _sectionIndex = 0;
    });
    _changed();
  }

  TacticData? _tacticById(String? id) {
    if (id == null) return null;
    return _data.tactics.where((t) => t.id == id).firstOrNull;
  }

  String? _leftComparisonId() {
    _ensureTactics();
    if (_data.tactics.any((t) => t.id == _compareLeftId)) return _compareLeftId;
    return _data.tactics.firstOrNull?.id;
  }

  String? _rightComparisonId() {
    _ensureTactics();
    if (_data.tactics.any((t) => t.id == _compareRightId)) return _compareRightId;
    if (_data.tactics.length > 1) return _data.tactics[1].id;
    return _data.tactics.firstOrNull?.id;
  }

  List<Player> _playersForTactic(TacticData tactic) {
    final players = _data.players
        .map((p) => Player(
              id: p.id,
              nome: p.nome,
              ano: p.ano,
              numero: p.numero,
              principal: p.principal,
              secundaria: p.secundaria,
              status: p.status,
              selected: false,
              cards: <CardData>[],
              plantelCards: p.plantelCards.map((e) => e.clone()).toList(),
            ))
        .toList();
    tactic.apply(players);
    return players;
  }

  Future<void> _share() async {
    _data.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _persistLocal();
    final ok = await _saveOnline(manual: true);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível confirmar a versão mais recente online.')),
      );
      return;
    }
    final text = 'Plantel Futebol de 7\n${_storage.webShareUrl}\nID do plantel: ${_storage.dbId}';
    await Share.share(text, subject: 'Plantel Futebol de 7');
  }

  Future<void> _openStorageDialog() async {
    final controller = TextEditingController(text: _storage.dbId);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abrir outro plantel'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'ID ou link completo do plantel',
              hintText: '...#db=...',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Abrir')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    final id = _storage.extractDbId(result);
    if (id.isEmpty) return;
    await _storage.setDbId(id);
    if (!mounted) return;
    setState(() {
      _data = PlantelStateData.empty();
      _selectedCardId = null;
      _compareLeftId = null;
      _compareRightId = null;
      _plantelViewActive = false;
      _plantelSnapshot = null;
      _saveStatus = 'A carregar…';
      _loading = true;
    });
    await _load();
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar backup JSON'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cole aqui o backup copiado da versão web.'),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                minLines: 8,
                maxLines: 14,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(hintText: '{"players": [...]}'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final clip = await Clipboard.getData(Clipboard.kTextPlain);
              controller.text = clip?.text ?? '';
            },
            child: const Text('Colar'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Importar')),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final imported = await _storage.importBackup(raw);
      if (!mounted) return;
      setState(() {
        _data = imported;
        _ensureTactics();
        _activeTactic.apply(_data.players);
        _data.updatedAt = DateTime.now().millisecondsSinceEpoch;
        _selectedCardId = null;
      });
      _changed();
      await _saveOnline(manual: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O backup não é válido.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF17243A),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _gold, width: 1.4),
              ),
              child: const Text('7', style: TextStyle(color: _gold, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Gestor de Plantel — Futebol de 7',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Text(_saveStatus, style: const TextStyle(color: Color(0xFF76D68B), fontSize: 11)),
            ),
          ),
          IconButton(tooltip: 'Guardar online', onPressed: () => _saveOnline(manual: true), icon: const Icon(Icons.cloud_done_outlined)),
          IconButton(tooltip: 'Partilhar', onPressed: _share, icon: const Icon(Icons.share_outlined)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'import') _importBackup();
              if (value == 'storage') _openStorageDialog();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'import', child: Text('Importar backup')),
              PopupMenuItem(value: 'storage', child: Text('Abrir outro plantel')),
            ],
          ),
        ],
      ),
      body: _loading && _data.players.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 980;
                final content = _sectionIndex == 0
                    ? _plantelWorkspace(desktop)
                    : _tacticsWorkspace();
                if (!desktop) return content;
                return Row(
                  children: [
                    NavigationRail(
                      backgroundColor: _panel2,
                      selectedIndex: _sectionIndex,
                      onDestinationSelected: (value) => setState(() => _sectionIndex = value),
                      labelType: NavigationRailLabelType.all,
                      leading: const Padding(
                        padding: EdgeInsets.only(top: 10, bottom: 8),
                        child: Text('F7', style: TextStyle(color: _gold, fontWeight: FontWeight.w900)),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.groups_2_outlined),
                          selectedIcon: Icon(Icons.groups_2),
                          label: Text('Plantel'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_customize_outlined),
                          selectedIcon: Icon(Icons.dashboard_customize),
                          label: Text('Táticas'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                );
              },
            ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 980
          ? NavigationBar(
              selectedIndex: _sectionIndex,
              onDestinationSelected: (value) => setState(() => _sectionIndex = value),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.groups_2_outlined), selectedIcon: Icon(Icons.groups_2), label: 'Plantel'),
                NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), selectedIcon: Icon(Icons.dashboard_customize), label: 'Táticas'),
              ],
            )
          : null,
    );
  }

  Widget _plantelWorkspace(bool desktop) {
    if (desktop) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 43, child: _leftPanel()),
            const SizedBox(width: 12),
            Expanded(flex: 57, child: _fieldPanel()),
          ],
        ),
      );
    }
    return ListView(
      physics: _dragInteractionActive ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(9),
      children: [
        SizedBox(height: 620, child: _leftPanel()),
        const SizedBox(height: 10),
        _fieldPanel(),
      ],
    );
  }

  Widget _leftPanel() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plantel', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      Text('Jogadores e convocatória', style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF17243A), borderRadius: BorderRadius.circular(20)),
                  child: Text('${_data.players.length} jogadores', style: const TextStyle(color: _muted, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _form(),
            const SizedBox(height: 10),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _data.players.length,
                onReorder: _reorderPlayers,
                onReorderStart: (_) => _setDragInteraction(true),
                onReorderEnd: (_) => _setDragInteraction(false),
                itemBuilder: (context, index) => _playerRow(_data.players[index], index),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Posições: GR, DD, DE, DC, MC, ED, EE, PL/AV. Também pode escrever por extenso.',
              style: TextStyle(color: _muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    Widget field(TextEditingController c, String hint, {double width = 145}) => SizedBox(
          width: width,
          child: TextField(
            controller: c,
            decoration: InputDecoration(hintText: hint, isDense: true),
            onSubmitted: (_) => _addPlayer(),
          ),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        field(_nome, 'Nome do jogador', width: 180),
        field(_ano, 'Ano', width: 90),
        field(_numero, 'N.º', width: 74),
        field(_principal, 'Posição principal', width: 140),
        field(_secundaria, 'Posição secundária', width: 145),
        FilledButton.icon(onPressed: _addPlayer, icon: const Icon(Icons.person_add_alt_1, size: 17), label: const Text('Adicionar')),
      ],
    );
  }

  Widget _playerRow(Player player, int index) {
    final activeColor = !player.selected
        ? _reserve
        : switch (player.status) {
            PlayerStatus.inicial => _primary,
            PlayerStatus.suplente => _gold,
            PlayerStatus.reserva => _reserve,
          };
    return Card(
      key: ValueKey(player.id),
      color: _panel2,
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: activeColor.withValues(alpha: 0.35))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.drag_indicator, color: _muted, size: 20)),
            ),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(10)),
              child: Text(player.numero.isEmpty ? '—' : player.numero, style: TextStyle(color: player.status == PlayerStatus.suplente ? _bg : Colors.white, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.nome, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                  Text(
                    '${player.ano.isEmpty ? '—' : player.ano} • ${player.principal.isEmpty ? '—' : player.principal}${player.secundaria.isEmpty ? '' : ' / ${player.secundaria}'}',
                    style: const TextStyle(color: _muted, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 3,
                    runSpacing: 2,
                    children: [
                      _statusButton(player, PlayerStatus.inicial, 'Inicial', Icons.sports_soccer),
                      _statusButton(player, PlayerStatus.suplente, 'Suplente', Icons.event_seat_outlined),
                      _statusButton(player, PlayerStatus.reserva, 'Reserva', Icons.inventory_2_outlined),
                      IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 30, height: 30), visualDensity: VisualDensity.compact, tooltip: 'Editar', onPressed: () => _editPlayer(player), icon: const Icon(Icons.edit_outlined, size: 17)),
                      IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 30, height: 30), visualDensity: VisualDensity.compact, tooltip: 'Eliminar', onPressed: () => _removePlayer(player), icon: const Icon(Icons.delete_outline, size: 18)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(Player player, PlayerStatus status, String label, IconData icon) {
    final active = player.selected && player.status == status;
    final color = switch (status) {
      PlayerStatus.inicial => const Color(0xFF3F91DC),
      PlayerStatus.suplente => _gold,
      PlayerStatus.reserva => _reserve,
    };
    return FilledButton.tonalIcon(
      onPressed: () => _placePlayer(player, status),
      style: FilledButton.styleFrom(
        backgroundColor: active ? color.withValues(alpha: 0.95) : _panel,
        foregroundColor: active && status == PlayerStatus.suplente ? _bg : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 12),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _fieldPanel() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _border)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          physics: _dragInteractionActive ? const NeverScrollableScrollPhysics() : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Campo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(
                    width: 215,
                    child: DropdownButtonFormField<String>(
                      value: _data.activeTacticId,
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'Tática ativa'),
                      items: _data.tactics.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (value) {
                        if (value != null) _switchTactic(value);
                      },
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _togglePlantel,
                    style: FilledButton.styleFrom(
                      backgroundColor: _plantelViewActive ? _gold.withValues(alpha: 0.9) : null,
                      foregroundColor: _plantelViewActive ? _bg : null,
                    ),
                    icon: const Icon(Icons.groups_2_outlined),
                    label: Text(_plantelViewActive ? 'Voltar à tática' : 'Vista do plantel'),
                  ),
                  OutlinedButton.icon(onPressed: _clearField, icon: const Icon(Icons.layers_clear_outlined), label: const Text('Limpar campo')),
                ],
              ),
              const SizedBox(height: 7),
              const Text('Arraste os cartões para mover; use a pega no canto para redimensionar e A−/A+ para a letra.', style: TextStyle(color: _muted, fontSize: 11)),
              const SizedBox(height: 10),
              _compactField(),
              const SizedBox(height: 8),
              _benchBars(),
            ],
          ),
        ),
      ),
    );
  }

  List<Player> get _substitutes => _data.players.where((p) => p.selected && p.status == PlayerStatus.suplente).toList();
  List<Player> get _reserves => _data.players.where((p) => p.selected && p.status == PlayerStatus.reserva).toList();

  Widget _compactField() {
    final size = MediaQuery.sizeOf(context);
    final desktop = size.width >= 980;
    final fittedWidth = ((size.height - 250) * 800 / 1100).clamp(300.0, 520.0).toDouble();
    final maxWidth = desktop ? fittedWidth : 520.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FootballField(
          players: _data.players,
          selectedCardId: _selectedCardId,
          onSelect: (id) => setState(() => _selectedCardId = id),
          onMove: _moveCard,
          onResize: _resizeCard,
          onFontChange: _fontChange,
          onInteractionStart: () => _setDragInteraction(true),
          onInteractionEnd: () => _setDragInteraction(false),
        ),
      ),
    );
  }

  Widget _benchBars() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _benchSection(
            title: 'Suplentes',
            icon: Icons.event_seat,
            color: _gold,
            players: _substitutes,
            canPromote: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _benchSection(
            title: 'Reservas',
            icon: Icons.inventory_2_outlined,
            color: _reserve,
            players: _reserves,
            canPromote: false,
          ),
        ),
      ],
    );
  }

  Widget _benchSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Player> players,
    required bool canPromote,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: _panel2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
              Text('${players.length}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: players.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Sem jogadores', style: TextStyle(color: _muted, fontSize: 10)),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final player in players) ...[
                          _compactBenchCard(player, color, canPromote),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _compactBenchCard(Player player, Color color, bool canPromote) {
    return Container(
      width: canPromote ? 138 : 122,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF172238),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text(
              player.numero.isEmpty ? '—' : player.numero,
              style: TextStyle(
                color: color == _gold ? _bg : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                Text(player.principal.isEmpty ? '—' : player.principal, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 9)),
              ],
            ),
          ),
          if (canPromote)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 25, height: 25),
              tooltip: 'Colocar no campo',
              onPressed: () => _promoteSubstitute(player),
              icon: const Icon(Icons.arrow_upward, size: 15),
            ),
        ],
      ),
    );
  }

  Widget _tacticsWorkspace() {
    _syncActiveTacticFromPlayers();
    final leftId = _leftComparisonId();
    final rightId = _rightComparisonId();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Táticas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('Cria versões diferentes do onze, guarda-as e compara duas em simultâneo.', style: TextStyle(color: _muted)),
                ],
              ),
            ),
            FilledButton.icon(onPressed: _createTactic, icon: const Icon(Icons.add), label: const Text('Nova tática')),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [for (final tactic in _data.tactics) _tacticCard(tactic)]),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Text('Comparar táticas', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
            Text('${_data.tactics.length} guardadas', style: const TextStyle(color: _muted)),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = constraints.maxWidth < 520 ? 6.0 : 12.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _comparisonPanel(slot: 1, selectedId: leftId)),
                SizedBox(width: gap),
                Expanded(child: _comparisonPanel(slot: 2, selectedId: rightId)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _tacticCard(TacticData tactic) {
    final active = tactic.id == _data.activeTacticId;
    final players = _playersForTactic(tactic);
    final initial = players.where((p) => p.selected && p.status == PlayerStatus.inicial).length;
    final subs = players.where((p) => p.selected && p.status == PlayerStatus.suplente).length;
    return Container(
      width: 290,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF142B49) : _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? _primary : _border, width: active ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(active ? Icons.star : Icons.star_border, color: active ? _gold : _muted, size: 19),
              const SizedBox(width: 7),
              Expanded(child: Text(tactic.name, style: const TextStyle(fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
              PopupMenuButton<String>(
                tooltip: 'Opções da tática',
                onSelected: (value) {
                  if (value == 'rename') _renameTactic(tactic);
                  if (value == 'duplicate') _duplicateTactic(tactic);
                  if (value == 'delete') _deleteTactic(tactic);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renomear')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            _smallMetric(Icons.sports_soccer, '$initial iniciais'),
            const SizedBox(width: 7),
            _smallMetric(Icons.event_seat_outlined, '$subs suplentes'),
          ]),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => _switchTactic(tactic.id, openPlantel: true),
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: Text(active ? 'Editar no campo' : 'Abrir e editar'),
          ),
        ],
      ),
    );
  }

  Widget _smallMetric(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 14, color: _muted),
          const SizedBox(width: 4),
          Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 11), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  Widget _comparisonPanel({required int slot, required String? selectedId}) {
    final tactic = _tacticById(selectedId);
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: selectedId,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Tática $slot', isDense: true),
            items: _data.tactics.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) {
              setState(() {
                if (slot == 1) {
                  _compareLeftId = value;
                } else {
                  _compareRightId = value;
                }
              });
            },
          ),
          const SizedBox(height: 9),
          if (tactic == null)
            const AspectRatio(
              aspectRatio: 800 / 1100,
              child: Center(child: Text('Cria uma tática para comparar.', textAlign: TextAlign.center, style: TextStyle(color: _muted))),
            )
          else
            IgnorePointer(
              child: FootballField(
                players: _playersForTactic(tactic),
                selectedCardId: null,
                onSelect: (_) {},
                onMove: (_, __, ___, ____) {},
                onResize: (_, __, ___, ____) {},
                onFontChange: (_, __, ___) {},
                onInteractionStart: () {},
                onInteractionEnd: () {},
              ),
            ),
          if (tactic != null) ...[
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: () => _switchTactic(tactic.id, openPlantel: true), child: const Text('Editar esta tática')),
          ],
        ],
      ),
    );
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
