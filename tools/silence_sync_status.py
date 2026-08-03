from pathlib import Path

path = Path('plantel-online.html')
text = path.read_text(encoding='utf-8')

# Make pending/offline sync silent to the user while preserving local-first save and retries.
old = '''  function markPending(message = "Guardado neste dispositivo — a sincronizar automaticamente…") {
    syncPending = true;
    setSaveStatus(message, false);
  }
'''
new = '''  /* SILENT_SYNC_STATUS_V1 */
  function markPending(message = "Guardado") {
    syncPending = true;
    setSaveStatus("Guardado", false);
  }
'''
if old not in text:
    raise RuntimeError('markPending block not found')
text = text.replace(old, new, 1)

text = text.replace('markPending("Plantel disponível neste dispositivo — sincronização pendente.");', 'markPending();')
text = text.replace('markPending("Guardado neste dispositivo — sincronização pendente.");', 'markPending();')

# Avoid exposing transient online retry messages during automatic background attempts.
text = text.replace('      setSaveStatus("A guardar online…");\n', '      if (manual) setSaveStatus("A guardar online…");\n', 1)

required = [
    'SILENT_SYNC_STATUS_V1',
    'function scheduleRetry',
    'setSaveStatus("Guardado", false)',
    'LIST_DRAG_FIX_V2',
    '"AV": "PL"',
]
for marker in required:
    if marker not in text:
        raise RuntimeError(f'Required marker missing: {marker}')

path.write_text(text, encoding='utf-8')
