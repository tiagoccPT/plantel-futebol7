from pathlib import Path

main_path = Path('flutter_app/lib/main.dart')
pubspec_path = Path('flutter_app/pubspec.yaml')
text = main_path.read_text(encoding='utf-8')

old_info = """            Expanded(
              flex: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
"""
new_info = """            SizedBox(
              width: 150,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
"""
if old_info not in text:
    raise SystemExit('Bloco de informação do jogador não encontrado')
text = text.replace(old_info, new_info, 1)

old_actions = """            Expanded(
              flex: 9,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
"""
new_actions = """            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
"""
if old_actions not in text:
    raise SystemExit('Bloco de ações do jogador não encontrado')
text = text.replace(old_actions, new_actions, 1)

pubspec = pubspec_path.read_text(encoding='utf-8')
if 'version: 1.0.2+3' in pubspec:
    pubspec = pubspec.replace('version: 1.0.2+3', 'version: 1.0.3+4', 1)
elif 'version: 1.0.3+4' not in pubspec:
    raise SystemExit('Versão inesperada no pubspec.yaml')

main_path.write_text(text, encoding='utf-8')
pubspec_path.write_text(pubspec, encoding='utf-8')
print('PLAYER_ROW_GAP_FIXED')
