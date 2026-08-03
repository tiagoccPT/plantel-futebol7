import 'dart:math';

String uid() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 32).toRadixString(36)}';

enum PlayerStatus { inicial, suplente, reserva }

PlayerStatus statusFromString(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'suplente':
      return PlayerStatus.suplente;
    case 'reserva':
      return PlayerStatus.reserva;
    default:
      return PlayerStatus.inicial;
  }
}

String statusToString(PlayerStatus value) => value.name;

String removeAccents(String value) {
  const from = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const to = 'AAAAAEEEEIIIIOOOOOUUUUC';
  var result = value;
  for (var i = 0; i < from.length; i++) {
    result = result.replaceAll(from[i], to[i]);
  }
  return result;
}

String normalizePosition(String value) {
  final pos = removeAccents(value)
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[-_/]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  const aliases = <String, String>{
    'GR': 'GR',
    'GUARDA REDES': 'GR',
    'GUARDA REDES DE FUTEBOL': 'GR',
    'DD': 'DD',
    'DEFESA DIREITO': 'DD',
    'DEFESA DIREITA': 'DD',
    'LATERAL DIREITO': 'DD',
    'LATERAL DIREITA': 'DD',
    'DE': 'DE',
    'DEFESA ESQUERDO': 'DE',
    'DEFESA ESQUERDA': 'DE',
    'LATERAL ESQUERDO': 'DE',
    'LATERAL ESQUERDA': 'DE',
    'DC': 'DC',
    'DEFESA CENTRAL': 'DC',
    'CENTRAL': 'DC',
    'MC': 'MC',
    'MEDIO': 'MC',
    'MEDIO CENTRO': 'MC',
    'MEDIO CENTRAL': 'MC',
    'CENTRO CAMPISTA': 'MC',
    'CENTROCAMPISTA': 'MC',
    'ED': 'ED',
    'EXTREMO DIREITO': 'ED',
    'EXTREMO DIREITA': 'ED',
    'ALA DIREITO': 'ED',
    'ALA DIREITA': 'ED',
    'EE': 'EE',
    'EXTREMO ESQUERDO': 'EE',
    'EXTREMO ESQUERDA': 'EE',
    'ALA ESQUERDO': 'EE',
    'ALA ESQUERDA': 'EE',
    'PL': 'PL',
    'AV': 'PL',
    'PONTA DE LANCA': 'PL',
    'PONTA LANCA': 'PL',
    'AVANCADO': 'PL',
  };

  return aliases[pos] ?? pos;
}

const positionCoordinates = <String, List<double>>{
  'GR': [334, 835],
  'DD': [590, 710],
  'DC': [334, 710],
  'DE': [78, 710],
  'MC': [334, 525],
  'ED': [590, 260],
  'EE': [78, 260],
  'PL': [334, 160],
};

class CardData {
  CardData({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    this.width = 132,
    this.height = 52,
    this.fontSize = 12,
  });

  String id;
  String label;
  double x;
  double y;
  double width;
  double height;
  double fontSize;

  CardData clone() => CardData(
        id: id,
        label: label,
        x: x,
        y: y,
        width: width,
        height: height,
        fontSize: fontSize,
      );

  factory CardData.fromJson(Map<String, dynamic> json) => CardData(
        id: (json['id'] ?? uid()).toString(),
        label: (json['label'] ?? '').toString(),
        x: (json['x'] as num?)?.toDouble() ?? 334,
        y: (json['y'] as num?)?.toDouble() ?? 525,
        width: (json['width'] as num?)?.toDouble() ?? 132,
        height: (json['height'] as num?)?.toDouble() ?? 52,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 12,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'fontSize': fontSize,
      };
}

class Player {
  Player({
    required this.id,
    required this.nome,
    required this.ano,
    required this.numero,
    required this.principal,
    required this.secundaria,
    this.status = PlayerStatus.inicial,
    this.selected = false,
    List<CardData>? cards,
    List<CardData>? plantelCards,
  })  : cards = cards ?? <CardData>[],
        plantelCards = plantelCards ?? <CardData>[];

  String id;
  String nome;
  String ano;
  String numero;
  String principal;
  String secundaria;
  PlayerStatus status;
  bool selected;
  List<CardData> cards;
  List<CardData> plantelCards;

  factory Player.fromJson(Map<String, dynamic> json) {
    final cards = ((json['cards'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => CardData.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final plantelCards = ((json['plantelCards'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => CardData.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return Player(
      id: (json['id'] ?? uid()).toString(),
      nome: (json['nome'] ?? '').toString(),
      ano: (json['ano'] ?? '').toString(),
      numero: (json['numero'] ?? '').toString(),
      principal: (json['principal'] ?? '').toString(),
      secundaria: (json['secundaria'] ?? '').toString(),
      status: statusFromString(json['status']?.toString()),
      selected: json['selected'] is bool ? json['selected'] as bool : cards.isNotEmpty,
      cards: cards,
      plantelCards: plantelCards,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'ano': ano,
        'numero': numero,
        'principal': principal,
        'secundaria': secundaria,
        'status': statusToString(status),
        'selected': selected,
        'cards': cards.map((e) => e.toJson()).toList(),
        'plantelCards': plantelCards.map((e) => e.toJson()).toList(),
      };
}

class PlantelStateData {
  PlantelStateData({required this.players, required this.updatedAt});

  List<Player> players;
  int updatedAt;

  factory PlantelStateData.empty() => PlantelStateData(players: [], updatedAt: 0);

  factory PlantelStateData.fromJson(Map<String, dynamic> json) => PlantelStateData(
        players: ((json['players'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Player.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'players': players.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt,
      };
}

List<CardData> buildPlayerCards(Player player) {
  final cards = <CardData>[];
  final labels = [player.principal, player.secundaria];

  for (var index = 0; index < labels.length; index++) {
    final label = labels[index].trim();
    if (label.isEmpty) continue;

    final canonical = normalizePosition(label);
    final base = positionCoordinates[canonical] ?? const [334.0, 525.0];
    var x = base[0];
    var y = base[1];

    final sameAsFirst = index == 1 &&
        player.principal.trim().isNotEmpty &&
        normalizePosition(player.principal) == canonical;
    if (sameAsFirst) {
      x += 20;
      y += 20;
    }

    cards.add(CardData(id: uid(), label: label, x: x, y: y));
  }

  return cards;
}

List<CardData> rebuildCardsPreservingLayout(Player player, List<CardData> previous) {
  final rebuilt = buildPlayerCards(player);
  return List.generate(rebuilt.length, (index) {
    final card = rebuilt[index];
    if (index >= previous.length) return card;
    final old = previous[index];
    return CardData(
      id: old.id,
      label: card.label,
      x: old.x,
      y: old.y,
      width: old.width,
      height: old.height,
      fontSize: old.fontSize,
    );
  });
}
