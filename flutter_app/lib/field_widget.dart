import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

class FootballField extends StatelessWidget {
  const FootballField({
    super.key,
    required this.players,
    required this.selectedCardId,
    required this.onSelect,
    required this.onMove,
    required this.onResize,
    required this.onFontChange,
  });

  final List<Player> players;
  final String? selectedCardId;
  final void Function(String cardId) onSelect;
  final void Function(String playerId, String cardId, double dx, double dy) onMove;
  final void Function(String playerId, String cardId, double dw, double dh) onResize;
  final void Function(String playerId, String cardId, double delta) onFontChange;

  Color _cardColor(String position, PlayerStatus status) {
    if (status == PlayerStatus.suplente) return const Color(0xFFD4AF37);
    if (status == PlayerStatus.reserva) return const Color(0xFF777F8C);
    final pos = normalizePosition(position);
    if (pos == 'GR') return const Color(0xFFF0C83F);
    if (['DD', 'DE', 'DC'].contains(pos)) return const Color(0xFF3F91DC);
    if (pos == 'MC') return const Color(0xFF54A85C);
    return const Color(0xFFED8434);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 800.0);
        final height = width * 1100 / 800;
        final scale = width / 800;

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _FieldPainter()),
                ),
                for (final player in players)
                  for (final card in player.cards)
                    _buildCard(context, player, card, scale),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, Player player, CardData card, double scale) {
    final selected = selectedCardId == card.id;
    final cardWidth = card.width * scale;
    final cardHeight = card.height * scale;

    return Positioned(
      left: card.x * scale,
      top: card.y * scale,
      width: cardWidth,
      height: cardHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(card.id),
        onPanStart: (_) => onSelect(card.id),
        onPanUpdate: (details) => onMove(
          player.id,
          card.id,
          details.delta.dx / scale,
          details.delta.dy / scale,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: _cardColor(card.label, player.status),
                  borderRadius: BorderRadius.circular(5 * scale),
                  border: Border.all(
                    color: selected ? const Color(0xFFFF4242) : Colors.black,
                    width: selected ? math.max(2.0, 4 * scale) : math.max(1.0, 1.5 * scale),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(7 * scale, 5 * scale, 22 * scale, 4 * scale),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: math.max(8, card.fontSize * scale),
                    height: 1.05,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${player.numero.isNotEmpty ? '#${player.numero} ' : ''}${player.nome}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(card.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              width: math.max(18, 22 * scale),
              height: math.max(18, 22 * scale),
              child: GestureDetector(
                onPanStart: (_) => onSelect(card.id),
                onPanUpdate: (details) => onResize(
                  player.id,
                  card.id,
                  details.delta.dx / scale,
                  details.delta.dy / scale,
                ),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.72),
                  alignment: Alignment.center,
                  child: Icon(Icons.open_in_full, color: Colors.white, size: math.max(11, 14 * scale)),
                ),
              ),
            ),
            if (selected)
              Positioned(
                right: 0,
                top: -math.max(32, 36 * scale),
                child: Row(
                  children: [
                    _fontButton(Icons.text_decrease, () => onFontChange(player.id, card.id, -1)),
                    const SizedBox(width: 3),
                    _fontButton(Icons.text_increase, () => onFontChange(player.id, card.id, 1)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fontButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, color: Colors.black87, size: 18),
        ),
      ),
    );
  }
}

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 800;
    final sy = size.height / 1100;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * sx;
    final fill = Paint()..color = const Color(0xFF2F7D35);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(12 * sx)),
      fill,
    );

    Rect r(double x, double y, double w, double h) => Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy);
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    canvas.drawRect(r(20, 20, 760, 1060), paint);
    canvas.drawRect(r(340, 0, 120, 20), paint);
    canvas.drawRect(r(340, 1080, 120, 20), paint);
    canvas.drawLine(p(20, 550), p(780, 550), paint);
    canvas.drawCircle(p(400, 550), 80 * sx, paint);
    canvas.drawRect(r(200, 20, 400, 180), paint);
    canvas.drawRect(r(300, 20, 200, 70), paint);
    canvas.drawRect(r(200, 900, 400, 180), paint);
    canvas.drawRect(r(300, 1010, 200, 70), paint);

    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(p(400, 550), 4.5 * sx, dot);
    canvas.drawCircle(p(400, 140), 4.5 * sx, dot);
    canvas.drawCircle(p(400, 960), 4.5 * sx, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
