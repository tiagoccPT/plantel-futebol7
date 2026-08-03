from pathlib import Path

path = Path('plantel-online.html')
text = path.read_text(encoding='utf-8')

if 'RESILIENT_SYNC_V1' in text:
    raise SystemExit(0)

# Add retry state variables.
marker = '  let editingPlayerId = null;\n'
insert = '''  let editingPlayerId = null;\n  /* RESILIENT_SYNC_V1 */\n  let retryTimer = null;\n  let retryDelay = 2000;\n  let syncPending = false;\n'''
if marker not in text:
    raise RuntimeError('state marker not found')
text = text.replace(marker, insert, 1)

# Insert resilient sync helpers before save().
marker = '  function save() {\n'
helpers = r'''  function clearRetry() {
    if (retryTimer) clearTimeout(retryTimer);
    retryTimer = null;
  }

  function scheduleRetry(delay = retryDelay) {
    syncPending = true;
    clearRetry();
    retryTimer = setTimeout(() => {
      retryTimer = null;
      saveOnline(false);
    }, delay);
    retryDelay = Math.min(Math.max(2000, retryDelay * 1.8), 30000);
  }

  function markPending(message = "Guardado neste dispositivo — a sincronizar automaticamente…") {
    syncPending = true;
    setSaveStatus(message, false);
  }

'''
if marker not in text:
    raise RuntimeError('save marker not found')
text = text.replace(marker, helpers + marker, 1)

# Replace save status with local-first wording.
text = text.replace(
    '    setSaveStatus("Alterações por guardar…");\n',
    '    markPending();\n',
    1,
)

# Replace load catch block.
old = '''    } catch (error) {
      console.error(error);
      remoteReady = false;
      setSaveStatus("Sem ligação online. As alterações ficaram neste dispositivo.", true);
    }
  }

  async function saveOnline(manual = true) {'''
new = '''    } catch (error) {
      console.error(error);
      remoteReady = false;
      markPending("Plantel disponível neste dispositivo — sincronização pendente.");
      scheduleRetry();
    }
  }

  async function saveOnline(manual = true) {'''
if old not in text:
    raise RuntimeError('load catch block not found')
text = text.replace(old, new, 1)

# Replace success portion to clear retry state.
old = '''      remoteReady = true;

      const time = new Date().toLocaleTimeString("pt-PT", {'''
new = '''      remoteReady = true;
      syncPending = false;
      retryDelay = 2000;
      clearRetry();

      const time = new Date().toLocaleTimeString("pt-PT", {'''
if old not in text:
    raise RuntimeError('success marker not found')
text = text.replace(old, new, 1)

# Replace saveOnline catch block: no destructive error state, keep local data and retry.
old = '''    } catch (error) {
      console.error(error);
      remoteReady = false;
      setSaveStatus("Erro ao guardar online.", true);

      if (manual) {
        alert(
          "Não foi possível guardar online. As alterações continuam guardadas neste dispositivo."
        );
      }
    } finally {'''
new = '''    } catch (error) {
      console.error(error);
      remoteReady = false;
      markPending("Guardado neste dispositivo — sincronização pendente.");
      scheduleRetry();
    } finally {'''
if old not in text:
    raise RuntimeError('save catch block not found')
text = text.replace(old, new, 1)

# Ensure a queued save is retried and not lost.
old = '''      if (saveAgain) {
        saveAgain = false;
        saveTimer = setTimeout(() => saveOnline(false), 150);
      }
    }
  }

  async function shareApp() {'''
new = '''      if (saveAgain) {
        saveAgain = false;
        saveTimer = setTimeout(() => saveOnline(false), 150);
      } else if (syncPending && !retryTimer) {
        scheduleRetry();
      }
    }
  }

  async function shareApp() {'''
if old not in text:
    raise RuntimeError('finally block not found')
text = text.replace(old, new, 1)

# Retry immediately when connectivity/focus returns.
marker = '  els.adicionar.addEventListener("click", addPlayer);\n'
listeners = '''  window.addEventListener("online", () => {\n    if (syncPending) {\n      retryDelay = 2000;\n      clearRetry();\n      saveOnline(false);\n    }\n  });\n\n  window.addEventListener("focus", () => {\n    if (syncPending && !saving) saveOnline(false);\n  });\n\n  document.addEventListener("visibilitychange", () => {\n    if (!document.hidden && syncPending && !saving) saveOnline(false);\n  });\n\n'''
if marker not in text:
    raise RuntimeError('listener marker not found')
text = text.replace(marker, listeners + marker, 1)

required = [
    'RESILIENT_SYNC_V1',
    'function scheduleRetry',
    'Guardado neste dispositivo — sincronização pendente.',
    'window.addEventListener("online"',
    'syncPending = false',
    '"AV": "PL"',
    'LIST_DRAG_FIX_V2',
    'PLANTEL_LAYOUT_MEMORY_V1',
]
for item in required:
    if item not in text:
        raise RuntimeError(f'missing marker: {item}')

path.write_text(text, encoding='utf-8')

# workflow trigger
