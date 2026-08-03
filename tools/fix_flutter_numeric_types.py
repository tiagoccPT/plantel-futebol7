from pathlib import Path

main_path = Path('flutter_app/lib/main.dart')
text = main_path.read_text(encoding='utf-8')

replacements = {
    "card.x = (card.x + dx).clamp(20.0, 780.0 - card.width);":
        "card.x = (card.x + dx).clamp(20.0, 780.0 - card.width).toDouble();",
    "card.y = (card.y + dy).clamp(20.0, 1080.0 - card.height);":
        "card.y = (card.y + dy).clamp(20.0, 1080.0 - card.height).toDouble();",
    "card.width = (card.width + dw).clamp(72.0, 400.0);":
        "card.width = (card.width + dw).clamp(72.0, 400.0).toDouble();",
    "card.height = (card.height + dh).clamp(38.0, 220.0);":
        "card.height = (card.height + dh).clamp(38.0, 220.0).toDouble();",
    "card.x = card.x.clamp(20.0, 780.0 - card.width);":
        "card.x = card.x.clamp(20.0, 780.0 - card.width).toDouble();",
    "card.y = card.y.clamp(20.0, 1080.0 - card.height);":
        "card.y = card.y.clamp(20.0, 1080.0 - card.height).toDouble();",
    "setState(() => card.fontSize = (card.fontSize + delta).clamp(8.0, 40.0));":
        "setState(() => card.fontSize = (card.fontSize + delta).clamp(8.0, 40.0).toDouble());",
}

for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)

text = text.replace("import 'dart:convert';\n", "")
text = text.replace("      if (newIndex > oldIndex) newIndex--;\n      final player = _data.players.removeAt(oldIndex);", "      final player = _data.players.removeAt(oldIndex);")
text = text.replace("                onReorder: _reorderPlayers,", "                onReorderItem: _reorderPlayers,")

required_main = [
    'clamp(72.0, 400.0).toDouble()',
    'clamp(8.0, 40.0).toDouble()',
    'onReorderItem: _reorderPlayers',
]
for marker in required_main:
    if marker not in text:
        raise RuntimeError(f'Missing main.dart marker: {marker}')

main_path.write_text(text, encoding='utf-8')

field_path = Path('flutter_app/lib/field_widget.dart')
field = field_path.read_text(encoding='utf-8')
field = field.replace(
    'top: -math.max(32.0, 36 * scale),',
    'top: -math.max(32.0, 36 * scale).toDouble(),',
)
if 'top: -math.max(32.0, 36 * scale).toDouble(),' not in field:
    raise RuntimeError('Missing field numeric fix')
field_path.write_text(field, encoding='utf-8')
