import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
    required this.onInteractionStart,
    required this.onInteractionEnd,
  });

  final List<Player> players;
  final String? selectedCardId;
  final void Function(String cardId) onSelect;
  final void Function(String playerId, String cardId, double dx, double dy) onMove;
  final void Function(String playerId, String cardId, double dw, double dh) onResize;
  final void Function(String playerId, String cardId, double delta) onFontChange;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;

  Color _cardColor(String position, PlayerStatus status) {
    if (status == PlayerStatus.suplente) return const Color(0xFFD4AF37);
    if (status == PlayerStatus.reserva) return const Color(0xFF6B7280);
    final pos = normalizePosition(position);
    if (pos == 'GR') return const Color(0xFFF3B21A);
    if (['DD', 'DE', 'DC'].contains(pos)) return const Color(0xFF1976D2);
    if (pos == 'MC') return const Color(0xFF2F9347);
    return const Color(0xFFE8792E);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 800.0);
        final height = width * 1100 / 800;
        final scale = width / 800;

        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16 * scale),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 18 * scale,
                  offset: Offset(0, 7 * scale),
                ),
              ],
            ),
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

  Widget _buildCard(
    BuildContext context,
    Player player,
    CardData card,
    double scale,
  ) {
    final selected = selectedCardId == card.id;
    final cardWidth = card.width * scale;
    final cardHeight = card.height * scale;
    final handleExtent = math.max(24.0, 28 * scale).toDouble();

    return Positioned(
      left: card.x * scale,
      top: card.y * scale,
      width: cardWidth,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                _ImmediateDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _ImmediateDragGestureRecognizer>(
                  () => _ImmediateDragGestureRecognizer(),
                  (recognizer) {
                    recognizer
                      ..onDown = (event) {
                        recognizer.resizeMode =
                            event.localPosition.dx >=
                                    cardWidth - handleExtent &&
                                event.localPosition.dy >=
                                    cardHeight - handleExtent;
                        onSelect(card.id);
                        onInteractionStart();
                      }
                      ..onUpdate = (event) {
                        if (recognizer.resizeMode) {
                          onResize(
                            player.id,
                            card.id,
                            event.delta.dx / scale,
                            event.delta.dy / scale,
                          );
                        } else {
                          onMove(
                            player.id,
                            card.id,
                            event.delta.dx / scale,
                            event.delta.dy / scale,
                          );
                        }
                      }
                      ..onEnd = (_) {
                        onInteractionEnd();
                      }
                      ..onCancel = () {
                        onInteractionEnd();
                      };
                  },
                ),
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _cardColor(card.label, player.status),
                        borderRadius: BorderRadius.circular(8 * scale),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFF4242)
                              : const Color(0xFF07101C),
                          width: selected
                              ? math.max(2.0, 4 * scale)
                              : math.max(1.0, 1.4 * scale),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 5 * scale,
                            offset: Offset(0, 2 * scale),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.fromLTRB(
                        8 * scale,
                        5 * scale,
                        22 * scale,
                        4 * scale,
                      ),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: math.max(8.0, card.fontSize * scale),
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
                            Text(
                              card.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: handleExtent,
                    height: handleExtent,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF07101C)
                              .withValues(alpha: 0.76),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(6 * scale),
                            bottomRight: Radius.circular(7 * scale),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.open_in_full,
                          color: Colors.white,
                          size: math.max(11.0, 14 * scale),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: 0,
              top: -math.max(32.0, 36 * scale).toDouble(),
              child: Row(
                children: [
                  _fontButton(
                    Icons.text_decrease,
                    () => onFontChange(player.id, card.id, -1),
                  ),
                  const SizedBox(width: 3),
                  _fontButton(
                    Icons.text_increase,
                    () => onFontChange(player.id, card.id, 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fontButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: const Color(0xFFF4F7FB),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, color: const Color(0xFF0B1220), size: 18),
        ),
      ),
    );
  }
}

class _ImmediateDragGestureRecognizer extends OneSequenceGestureRecognizer {
  void Function(PointerDownEvent)? onDown;
  void Function(PointerMoveEvent)? onUpdate;
  void Function(PointerUpEvent)? onEnd;
  VoidCallback? onCancel;
  bool resizeMode = false;
  int? _activePointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onDown?.call(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    if (event is PointerMoveEvent) {
      onUpdate?.call(event);
      return;
    }
    if (event is PointerUpEvent) {
      onEnd?.call(event);
      stopTrackingPointer(event.pointer);
      _activePointer = null;
      return;
    }
    if (event is PointerCancelEvent) {
      onCancel?.call();
      stopTrackingPointer(event.pointer);
      _activePointer = null;
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    if (pointer != _activePointer) return;
    onCancel?.call();
    stopTrackingPointer(pointer);
    _activePointer = null;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'immediate card drag';
}

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 800;
    final sy = size.height / 1100;
    final pitch = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(15 * sx),
    );

    canvas.save();
    canvas.clipRRect(pitch);
    canvas.drawRRect(pitch, Paint()..color = const Color(0xFF1E7D32));

    final stripePaint = Paint()..color = const Color(0xFF238A38);
    final stripeHeight = size.height / 10;
    for (var i = 0; i < 10; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight),
        stripePaint,
      );
    }

    final vignette = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x10000000), Color(0x00000000), Color(0x18000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
    canvas.restore();

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * sx;

    Rect r(double x, double y, double w, double h) =>
        Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy);
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    canvas.drawRRect(pitch, Paint()
      ..color = const Color(0xFF0B1220)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * sx);
    canvas.drawRect(r(20, 20, 760, 1060), linePaint);
    canvas.drawRect(r(340, 0, 120, 20), linePaint);
    canvas.drawRect(r(340, 1080, 120, 20), linePaint);
    canvas.drawLine(p(20, 550), p(780, 550), linePaint);
    canvas.drawCircle(p(400, 550), 80 * sx, linePaint);
    canvas.drawRect(r(200, 20, 400, 180), linePaint);
    canvas.drawRect(r(300, 20, 200, 70), linePaint);
    canvas.drawRect(r(200, 900, 400, 180), linePaint);
    canvas.drawRect(r(300, 1010, 200, 70), linePaint);

    final dot = Paint()..color = Colors.white.withValues(alpha: 0.94);
    canvas.drawCircle(p(400, 550), 4.5 * sx, dot);
    canvas.drawCircle(p(400, 140), 4.5 * sx, dot);
    canvas.drawCircle(p(400, 960), 4.5 * sx, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
