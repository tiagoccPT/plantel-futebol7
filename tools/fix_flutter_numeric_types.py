from pathlib import Path

path = Path('flutter_app/lib/main.dart')
text = path.read_text(encoding='utf-8')

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
    elif new not in text:
        raise RuntimeError(f'Missing expected Flutter code: {old}')

path.write_text(text, encoding='utf-8')
