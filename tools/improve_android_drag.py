from pathlib import Path

main_path = Path('flutter_app/lib/main.dart')
main = main_path.read_text(encoding='utf-8')

if 'ANDROID_DRAG_PRIORITY_V1' not in main:
    main = main.replace(
        "  bool _plantelViewActive = false;\n",
        "  bool _plantelViewActive = false;\n  /* ANDROID_DRAG_PRIORITY_V1 */\n  bool _dragInteractionActive = false;\n",
        1,
    )

    marker = '''  void _scheduleRetry() {\n    _retryTimer?.cancel();\n    _retryTimer = Timer(const Duration(seconds: 15), () {\n      _retryTimer = null;\n      _saveOnline();\n    });\n  }\n'''
    replacement = marker + '''\n  void _setDragInteraction(bool active) {\n    if (!mounted || _dragInteractionActive == active) return;\n    setState(() => _dragInteractionActive = active);\n  }\n'''
    if marker not in main:
        raise RuntimeError('scheduleRetry marker not found')
    main = main.replace(marker, replacement, 1)

    main = main.replace(
        "                return ListView(\n                  padding: const EdgeInsets.all(9),",
        "                return ListView(\n                  physics: _dragInteractionActive\n                      ? const NeverScrollableScrollPhysics()\n                      : null,\n                  padding: const EdgeInsets.all(9),",
        1,
    )

    main = main.replace(
        "                onReorderItem: _reorderPlayers,\n",
        "                onReorderItem: _reorderPlayers,\n                onReorderStart: (_) => _setDragInteraction(true),\n                onReorderEnd: (_) => _setDragInteraction(false),\n",
        1,
    )

    main = main.replace(
        "        child: SingleChildScrollView(\n          child: Column(",
        "        child: SingleChildScrollView(\n          physics: _dragInteractionActive\n              ? const NeverScrollableScrollPhysics()\n              : null,\n          child: Column(",
        1,
    )

    main = main.replace(
        "                onFontChange: _fontChange,\n",
        "                onFontChange: _fontChange,\n                onInteractionStart: () => _setDragInteraction(true),\n                onInteractionEnd: () => _setDragInteraction(false),\n",
        1,
    )

required_main = [
    'ANDROID_DRAG_PRIORITY_V1',
    'bool _dragInteractionActive = false;',
    'void _setDragInteraction(bool active)',
    'onReorderStart: (_) => _setDragInteraction(true)',
    'onReorderEnd: (_) => _setDragInteraction(false)',
    'onInteractionStart: () => _setDragInteraction(true)',
]
for marker in required_main:
    if marker not in main:
        raise RuntimeError(f'Missing main marker: {marker}')
main_path.write_text(main, encoding='utf-8')

field_path = Path('flutter_app/lib/field_widget.dart')
field = field_path.read_text(encoding='utf-8')

if "package:flutter/gestures.dart" not in field:
    field = field.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\n",
        1,
    )

if 'required this.onInteractionStart,' not in field:
    field = field.replace(
        "    required this.onFontChange,\n",
        "    required this.onFontChange,\n    required this.onInteractionStart,\n    required this.onInteractionEnd,\n",
        1,
    )
    field = field.replace(
        "  final void Function(String playerId, String cardId, double delta) onFontChange;\n",
        "  final void Function(String playerId, String cardId, double delta) onFontChange;\n  final VoidCallback onInteractionStart;\n  final VoidCallback onInteractionEnd;\n",
        1,
    )

start = field.find('  Widget _buildCard(BuildContext context, Player player, CardData card, double scale) {')
end = field.find('  Widget _fontButton(', start)
if start < 0 or end < 0:
    raise RuntimeError('buildCard block not found')

new_build = r'''  Widget _buildCard(BuildContext context, Player player, CardData card, double scale) {
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
                    GestureRecognizerFactoryWithHandlers<_ImmediateDragGestureRecognizer>(
                  () => _ImmediateDragGestureRecognizer(),
                  (recognizer) {
                    recognizer
                      ..onDown = (event) {
                        recognizer.resizeMode =
                            event.localPosition.dx >= cardWidth - handleExtent &&
                            event.localPosition.dy >= cardHeight - handleExtent;
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
                      ..onEnd = (_) => onInteractionEnd()
                      ..onCancel = onInteractionEnd;
                  },
                ),
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _cardColor(card.label, player.status),
                        borderRadius: BorderRadius.circular(5 * scale),
                        border: Border.all(
                          color: selected ? const Color(0xFFFF4242) : Colors.black,
                          width: selected
                              ? math.max(2.0, 4 * scale)
                              : math.max(1.0, 1.5 * scale),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        7 * scale,
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
                        color: Colors.black.withValues(alpha: 0.72),
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

'''
field = field[:start] + new_build + field[end:]

recognizer_marker = 'class _FieldPainter extends CustomPainter {'
if 'class _ImmediateDragGestureRecognizer' not in field:
    recognizer = r'''class _ImmediateDragGestureRecognizer extends OneSequenceGestureRecognizer {
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

'''
    if recognizer_marker not in field:
        raise RuntimeError('FieldPainter marker not found')
    field = field.replace(recognizer_marker, recognizer + recognizer_marker, 1)

required_field = [
    "package:flutter/gestures.dart",
    'required this.onInteractionStart',
    'final VoidCallback onInteractionStart;',
    'class _ImmediateDragGestureRecognizer extends OneSequenceGestureRecognizer',
    'resolve(GestureDisposition.accepted);',
    'RawGestureDetector(',
]
for marker in required_field:
    if marker not in field:
        raise RuntimeError(f'Missing field marker: {marker}')

field_path.write_text(field, encoding='utf-8')
