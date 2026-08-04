from pathlib import Path

path = Path('flutter_app/lib/main.dart')
text = path.read_text(encoding='utf-8')
old = 'defaultTargetPlatform == TargetPlatform.android'
new = 'Theme.of(context).platform == TargetPlatform.android'
count = text.count(old)
if count != 2:
    raise SystemExit(f'expected 2 platform checks, found {count}')
text = text.replace(old, new)
path.write_text(text, encoding='utf-8')
print('PLATFORM_FIX_OK')
