from pathlib import Path

path = Path('flutter_app/lib/main.dart')
text = path.read_text(encoding='utf-8')

old_load = """    } catch (_) {\n      if (mounted) setState(() => _saveStatus = 'Guardado');\n      _scheduleRetry();\n    }\n  }\n\n  void _scheduleRetry() {"""
new_load = """    } catch (_) {\n      if (mounted) {\n        setState(() => _saveStatus = 'Guardado localmente • sem ligação online');\n      }\n      _scheduleRetry();\n    }\n  }\n\n  void _scheduleRetry() {"""
if old_load not in text:
    raise SystemExit('Bloco _load não encontrado')
text = text.replace(old_load, new_load, 1)

old_sync = """    } catch (_) {\n      if (showStatus && mounted) {\n        setState(() => _saveStatus = 'Guardado');\n      }\n      return false;\n    } finally {\n      _syncing = false;\n    }\n  }"""
new_sync = """    } catch (_) {\n      if (showStatus && mounted) {\n        setState(() => _saveStatus = 'Guardado localmente • sem ligação online');\n      }\n      return false;\n    } finally {\n      _syncing = false;\n    }\n  }"""
if old_sync not in text:
    raise SystemExit('Bloco _syncFromRemote não encontrado')
text = text.replace(old_sync, new_sync, 1)

old_save = """    } catch (_) {\n      if (mounted) setState(() => _saveStatus = 'Guardado');\n      _scheduleRetry();\n      return false;\n    } finally {\n      _saving = false;"""
new_save = """    } catch (_) {\n      if (mounted) {\n        setState(() => _saveStatus = 'Guardado localmente • sem ligação online');\n      }\n      _scheduleRetry();\n      return false;\n    } finally {\n      _saving = false;"""
if old_save not in text:
    raise SystemExit('Bloco _saveOnline não encontrado')
text = text.replace(old_save, new_save, 1)

old_share = """    final text = 'Plantel Futebol de 7\\n${_storage.webShareUrl}\\nID do plantel: ${_storage.dbId}';"""
new_share = """    final text = 'Plantel Futebol de 7\\nID do plantel: ${_storage.dbId}';"""
if old_share not in text:
    raise SystemExit('Texto de partilha não encontrado')
text = text.replace(old_share, new_share, 1)

path.write_text(text, encoding='utf-8')
print('Patch Supabase aplicado a main.dart')
