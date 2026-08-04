from pathlib import Path

path = Path('flutter_app/lib/main.dart')
text = path.read_text(encoding='utf-8')
old = """      } else if (_data.players.isNotEmpty) {\n        _syncActiveTacticFromPlayers();\n        await _storage.saveRemote(_data);\n      }"""
new = """      } else {\n        _syncActiveTacticFromPlayers();\n        await _storage.saveRemote(_data);\n      }"""
if old not in text:
    raise SystemExit('Bloco de carregamento local mais recente não encontrado')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Carregamento Supabase corrigido')
