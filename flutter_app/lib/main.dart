import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'field_widget.dart';
import 'models.dart';
import 'storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlantelApp());
}

class PlantelApp extends StatelessWidget {
  const PlantelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestor de Plantel — Futebol de 7',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F91DC),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF08111F),
        cardColor: const Color(0xFF11213A),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: TextStyle(color: Colors.black54),
          hintStyle: TextStyle(color: Colors.black45),
          border: OutlineInputBorder(),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.blue,
          selectionColor: Color(0x663F91DC),
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
  String _saveStatus = 'A carregar…';
  bool _loading = true;
  bool _saving = false;
  bool _saveAgain = false;
  bool _plantelViewActive = false;
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
    if (state == AppLifecycleState.resumed) {
      _saveOnline();
    }
  }

  Future<void> _load() async {
    await _storage.loadSavedDbId();
    final local = await _storage.loadLocal();
    if (!mounted) return;
    setState(() {
      _data = local;
      _loading = false;
      _saveStatus = local.players.isEmpty ? 'A carregar online…' : 'Guardado';
    });

    try {
      final remote = await _storage.loadRemote();
      if (remote.updatedAt >= _data.updatedAt) {
        _data = remote;
        await _storage.saveLocal(_data);
        if (mounted) setState(() {});
      } else if (_data.players.isNotEmpty) {
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

  void _rememberPlantelLayout() {
    for (final player in _data.players) {
      player.plantelCards = player.cards.map((e) => e.clone()).toList();
    }
  }

  Future<void> _persistLocal() async {
    if (_plantelViewActive) _rememberPlantelLayout();
    await _storage.saveLocal(_data);
  }

  void _changed({bool debounce = false}) {
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
      if (_plantelViewActive) _rememberPlantelLayout();
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
      FocusScope.of(context).requestFocus(FocusNode());
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
    final sameSelection = player.selected && player.status == requested;
    setState(() {
      if (sameSelection) {
        player.selected = false;
        player.cards = [];
      } else {
        player.status = requested;
        player.selected = true;
        player.cards = buildPlayerCards(player);
      }
      if (_selectedCardId != null && !_cardExists(_selectedCardId!)) {
        _selectedCardId = null;
      }
    });
    _changed();
  }

  bool _cardExists(String id) {
    for (final player in _data.players) {
      if (player.cards.any((card) => card.id == id)) return true;
    }
    return false;
  }

  List<CardData> _rememberedPlantelCards(Player player) {
    final source = player.plantelCards.isNotEmpty ? player.plantelCards : player.cards;
    return rebuildCardsPreservingLayout(player, source);
  }

  void _togglePlantel() {
    if (!_plantelViewActive) {
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
    setState(() {
      _plantelViewActive = false;
      _plantelSnapshot = null;
      _selectedCardId = null;
      for (final player in _data.players) {
        player.selected = false;
        player.cards = [];
      }
    });
    _changed();
  }

  void _removePlayer(Player player) {
    if (_plantelViewActive) _restorePlantelSnapshot(save: false);
    setState(() {
      _data.players.removeWhere((p) => p.id == player.id);
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

      if (player.selected || oldCards.isNotEmpty || oldPlantel.isNotEmpty) {
        player.cards = rebuildCardsPreservingLayout(player, oldCards);
        if (oldPlantel.isNotEmpty) {
          player.plantelCards = rebuildCardsPreservingLayout(player, oldPlantel);
        }
        if (player.selected && player.cards.isEmpty) player.selected = false;
      }
      if (_selectedCardId != null && !_cardExists(_selectedCardId!)) {
        _selectedCardId = null;
      }
    });
    _changed();
  }

  Widget _dialogField(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(labelText: label),
        ),
      );

  void _reorderPlayers(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
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
    if (player == null) return null;
    return player.cards.where((c) => c.id == cardId).firstOrNull;
  }

  Future<void> _share() async {
    _data.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _persistLocal();
    final ok = await _saveOnline(manual: true);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível confirmar a versão mais recente online. A partilha foi cancelada.'),
        ),
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
            style: const TextStyle(color: Colors.black),
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
                style: const TextStyle(color: Colors.black, fontFamily: 'monospace'),
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
        title: const Text('Gestor de Plantel — Futebol de 7'),
        actions: [
          IconButton(
            tooltip: 'Importar backup',
            onPressed: _importBackup,
            icon: const Icon(Icons.restore),
          ),
          IconButton(
            tooltip: 'Abrir outro plantel',
            onPressed: _openStorageDialog,
            icon: const Icon(Icons.storage),
          ),
        ],
      ),
      body: _loading && _data.players.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 1000;
                if (desktop) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 44, child: _leftPanel()),
                        const SizedBox(width: 12),
                        Expanded(flex: 56, child: _fieldPanel()),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(9),
                  children: [
                    SizedBox(height: 720, child: _leftPanel()),
                    const SizedBox(height: 12),
                    _fieldPanel(),
                  ],
                );
              },
            ),
    );
  }

  Widget _leftPanel() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _form(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _saveStatus,
                    style: const TextStyle(color: Color(0xFFCFE7D4), fontSize: 12),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _togglePlantel,
                  style: FilledButton.styleFrom(
                    backgroundColor: _plantelViewActive ? const Color(0xFFD4AF37) : const Color(0xFFE2EBFF),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Plantel'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _data.players.length,
                onReorder: _reorderPlayers,
                itemBuilder: (context, index) => _playerRow(_data.players[index], index),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Abreviaturas: GR, DD, DE, DC, MC, ED, EE, PL e AV. Também pode escrever por extenso.',
              style: TextStyle(color: Color(0xFFC8D2E2), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    Widget field(TextEditingController c, String hint, {double width = 160}) => SizedBox(
          width: width,
          child: TextField(
            controller: c,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(hintText: hint, isDense: true),
            onSubmitted: (_) => _addPlayer(),
          ),
        );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        field(_nome, 'Nome do jogador', width: 190),
        field(_ano, 'Ano nascimento', width: 125),
        field(_numero, 'N.º camisola', width: 110),
        field(_principal, 'Posição principal', width: 145),
        field(_secundaria, 'Posição secundária', width: 150),
        FilledButton(onPressed: _addPlayer, child: const Text('Adicionar')),
        FilledButton.tonal(onPressed: () => _saveOnline(manual: true), child: const Text('Guardar')),
        FilledButton.tonal(onPressed: _share, child: const Text('Partilhar')),
        OutlinedButton(onPressed: _clearField, child: const Text('Limpar campo')),
      ],
    );
  }

  Widget _playerRow(Player player, int index) {
    return Card(
      key: ValueKey(player.id),
      color: const Color(0xFF0D192D),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_indicator, size: 26),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(player.numero.isEmpty ? '—' : '#${player.numero}', textAlign: TextAlign.center),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${player.ano.isEmpty ? '—' : player.ano}  •  ${player.principal.isEmpty ? '—' : player.principal}${player.secundaria.isEmpty ? '' : ' / ${player.secundaria}'}',
                    style: const TextStyle(color: Color(0xFFC8D2E2), fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _statusButton(player, PlayerStatus.inicial, 'Inicial'),
                      _statusButton(player, PlayerStatus.suplente, 'Suplente'),
                      _statusButton(player, PlayerStatus.reserva, 'Reserva'),
                      OutlinedButton.icon(
                        onPressed: () => _editPlayer(player),
                        icon: const Icon(Icons.edit, size: 15),
                        label: const Text('Editar'),
                      ),
                      IconButton(
                        tooltip: 'Eliminar jogador',
                        onPressed: () => _removePlayer(player),
                        icon: const Icon(Icons.delete_outline),
                      ),
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

  Widget _statusButton(Player player, PlayerStatus status, String label) {
    final active = player.selected && player.status == status;
    Color? background;
    Color? foreground;
    if (active && status == PlayerStatus.inicial) {
      background = const Color(0xFFE2EBFF);
      foreground = Colors.black;
    } else if (active && status == PlayerStatus.suplente) {
      background = const Color(0xFFD4AF37);
      foreground = Colors.black;
    } else if (active && status == PlayerStatus.reserva) {
      background = const Color(0xFF777F8C);
      foreground = Colors.white;
    }
    return FilledButton.tonal(
      onPressed: () => _placePlayer(player, status),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }

  Widget _fieldPanel() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Toque/clique num cartão para selecionar. Arraste para mover; use a pega no canto para redimensionar e os botões A−/A+ para a letra.',
                  style: TextStyle(color: Color(0xFFC8D2E2), fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              FootballField(
                players: _data.players,
                selectedCardId: _selectedCardId,
                onSelect: (id) => setState(() => _selectedCardId = id),
                onMove: _moveCard,
                onResize: _resizeCard,
                onFontChange: _fontChange,
              ),
            ],
          ),
        ),
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
