from pathlib import Path

path = Path('plantel-online.html')
text = path.read_text(encoding='utf-8')

if 'JSONSTORAGE_FALLBACK_V1' in text:
    raise SystemExit(0)

text = text.replace(
    '  const JSON_BLOB_API = "https://jsonblob.com/api/jsonBlob";\n  const LOCAL_PREFIX = "f7_jsonblob_";',
    '  const JSON_BLOB_API = "https://jsonblob.com/api/jsonBlob";\n  const JSON_STORAGE_API = "https://api.jsonstorage.net/v1/json";\n  const LOCAL_PREFIX = "f7_jsonblob_";\n  /* JSONSTORAGE_FALLBACK_V1 */',
    1,
)

text = text.replace(
    '  let editingPlayerId = null;\n  /* RESILIENT_SYNC_V1 */',
    '  let editingPlayerId = null;\n  let storeId = "";\n  /* RESILIENT_SYNC_V1 */',
    1,
)

old = '''  function readDbId() {\n    const params = new URLSearchParams(location.hash.slice(1));\n    dbId = params.get("db") || "";\n  }\n\n  function blobUrl() {\n    return dbId ? JSON_BLOB_API + "/" + encodeURIComponent(dbId) : "";\n  }\n'''
new = '''  function readDbId() {\n    const params = new URLSearchParams(location.hash.slice(1));\n    dbId = params.get("db") || "";\n    storeId = params.get("store") || "";\n\n    if (!storeId && dbId) {\n      try {\n        storeId = localStorage.getItem("f7_store_for_" + dbId) || "";\n      } catch {}\n    }\n\n    if (storeId && !params.get("store")) {\n      params.set("store", storeId);\n      history.replaceState(null, "", location.pathname + location.search + "#" + params.toString());\n    }\n  }\n\n  function blobUrl() {\n    return dbId ? JSON_BLOB_API + "/" + encodeURIComponent(dbId) : "";\n  }\n\n  function storeUrl() {\n    return storeId ? JSON_STORAGE_API + "/" + storeId : "";\n  }\n\n  function setStoreId(id) {\n    storeId = String(id || "").replace(/^\\/+|\\/+$/g, "");\n    if (!storeId) return;\n\n    try {\n      if (dbId) localStorage.setItem("f7_store_for_" + dbId, storeId);\n    } catch {}\n\n    const params = new URLSearchParams(location.hash.slice(1));\n    if (dbId) params.set("db", dbId);\n    params.set("store", storeId);\n    history.replaceState(null, "", location.pathname + location.search + "#" + params.toString());\n  }\n\n  function parseStoreId(uri) {\n    const marker = "/v1/json/";\n    const index = String(uri || "").indexOf(marker);\n    if (index < 0) return "";\n    return String(uri).slice(index + marker.length).replace(/^\\/+|\\/+$/g, "");\n  }\n\n  async function createFallbackStorage() {\n    if (!state.players.length) {\n      throw new Error("Não há dados locais para transferir.");\n    }\n\n    setSaveStatus("A recuperar a sincronização online…");\n\n    const response = await fetch(JSON_STORAGE_API, {\n      method: "POST",\n      headers: {\n        "Content-Type": "application/json",\n        "Accept": "application/json"\n      },\n      body: JSON.stringify({\n        players: state.players,\n        updatedAt: state.updatedAt || Date.now()\n      })\n    });\n\n    if (!response.ok) {\n      throw new Error("Não foi possível criar o armazenamento alternativo.");\n    }\n\n    const data = await response.json();\n    const id = parseStoreId(data && data.uri);\n    if (!id) throw new Error("O armazenamento alternativo não devolveu um identificador.");\n\n    setStoreId(id);\n    remoteReady = true;\n    syncPending = false;\n    retryDelay = 2000;\n    clearRetry();\n  }\n\n  async function putFallbackStorage() {\n    if (!storeId) throw new Error("Armazenamento alternativo não configurado.");\n\n    const response = await fetch(storeUrl(), {\n      method: "PUT",\n      headers: {\n        "Content-Type": "application/json",\n        "Accept": "application/json"\n      },\n      body: JSON.stringify({\n        players: state.players,\n        updatedAt: state.updatedAt\n      })\n    });\n\n    if (!response.ok) throw new Error("Não foi possível guardar no armazenamento alternativo.");\n  }\n'''
if old not in text:
    raise RuntimeError('readDbId/blobUrl block not found')
text = text.replace(old, new, 1)

text = text.replace('  async function ensureRemote() {\n    if (dbId) return;', '  async function ensureRemote() {\n    if (storeId || dbId) return;', 1)

start = text.find('  async function load() {')
end = text.find('  async function saveOnline(manual = true) {', start)
if start < 0 or end < 0:
    raise RuntimeError('load block not found')
new_load = r'''  async function load() {
    readDbId();

    const local = readLocal();
    state.players = local.players.map(ensurePlayerShape);
    state.updatedAt = local.updatedAt;
    render();

    if (storeId) {
      try {
        setSaveStatus("A carregar o plantel online…");
        const response = await fetch(storeUrl(), {
          method: "GET",
          headers: { "Accept": "application/json" },
          cache: "no-store"
        });
        if (!response.ok) throw new Error("Não foi possível carregar o armazenamento alternativo.");

        const data = await response.json();
        const remote = {
          players: Array.isArray(data.players) ? data.players.map(ensurePlayerShape) : [],
          updatedAt: Number(data.updatedAt) || 0
        };

        if (remote.updatedAt >= state.updatedAt) {
          state.players = remote.players;
          state.updatedAt = remote.updatedAt;
          writeLocal();
          render();
        } else {
          await saveOnline(false);
        }

        remoteReady = true;
        syncPending = false;
        clearRetry();
        setSaveStatus("Plantel online sincronizado.");
        return;
      } catch (error) {
        console.error(error);
      }
    }

    try {
      if (!dbId) {
        await ensureRemote();
        remoteReady = true;
        await saveOnline(false);
        return;
      }

      setSaveStatus("A carregar o plantel online…");

      const response = await fetch(blobUrl(), {
        method: "GET",
        headers: { "Accept": "application/json" },
        cache: "no-store"
      });

      if (!response.ok) {
        throw new Error("Não foi possível carregar o plantel online.");
      }

      const data = await response.json();
      const remote = {
        players: Array.isArray(data.players)
          ? data.players.map(ensurePlayerShape)
          : [],
        updatedAt: Number(data.updatedAt) || 0
      };

      if (remote.updatedAt >= state.updatedAt) {
        state.players = remote.players;
        state.updatedAt = remote.updatedAt;
        writeLocal();
        render();
      } else {
        await saveOnline(false);
      }

      remoteReady = true;
      syncPending = false;
      clearRetry();
      setSaveStatus("Plantel online sincronizado.");
    } catch (error) {
      console.error(error);
      remoteReady = false;

      if (state.players.length) {
        try {
          await createFallbackStorage();
          const time = new Date().toLocaleTimeString("pt-PT", {
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit"
          });
          setSaveStatus("Guardado online às " + time);
          return;
        } catch (fallbackError) {
          console.error(fallbackError);
        }
      }

      markPending("Guardado neste dispositivo — sem ligação ao armazenamento online.");
      scheduleRetry();
    }
  }

'''
text = text[:start] + new_load + text[end:]

start = text.find('  async function saveOnline(manual = true) {')
end = text.find('  async function shareApp() {', start)
if start < 0 or end < 0:
    raise RuntimeError('saveOnline block not found')
new_save = r'''  async function saveOnline(manual = true) {
    if (saving) {
      saveAgain = true;
      return;
    }

    clearTimeout(saveTimer);
    saving = true;

    try {
      if (plantelViewActive) rememberPlantelLayout();
      state.updatedAt = Date.now();
      writeLocal();
      setSaveStatus("A guardar online…");

      if (storeId) {
        await putFallbackStorage();
      } else {
        await ensureRemote();
        const response = await fetch(blobUrl(), {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json"
          },
          body: JSON.stringify({
            players: state.players,
            updatedAt: state.updatedAt
          })
        });
        if (!response.ok) throw new Error("Não foi possível guardar.");
      }

      remoteReady = true;
      syncPending = false;
      retryDelay = 2000;
      clearRetry();

      const time = new Date().toLocaleTimeString("pt-PT", {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit"
      });
      setSaveStatus("Guardado online às " + time);
    } catch (error) {
      console.error(error);
      remoteReady = false;

      if (!storeId && state.players.length) {
        try {
          await createFallbackStorage();
          const time = new Date().toLocaleTimeString("pt-PT", {
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit"
          });
          setSaveStatus("Guardado online às " + time);
          return;
        } catch (fallbackError) {
          console.error(fallbackError);
        }
      }

      markPending("Guardado neste dispositivo — sem ligação ao armazenamento online.");
      scheduleRetry();
    } finally {
      saving = false;

      if (saveAgain) {
        saveAgain = false;
        saveTimer = setTimeout(() => saveOnline(false), 150);
      } else if (syncPending && !retryTimer) {
        scheduleRetry();
      }
    }
  }

'''
text = text[:start] + new_save + text[end:]

required = [
    'JSONSTORAGE_FALLBACK_V1',
    'https://api.jsonstorage.net/v1/json',
    'function setStoreId(id)',
    'async function createFallbackStorage()',
    'async function putFallbackStorage()',
    'params.get("store")',
    'LIST_DRAG_FIX_V2',
    '"AV": "PL"',
]
for marker in required:
    if marker not in text:
        raise RuntimeError(f'Missing required marker: {marker}')

path.write_text(text, encoding='utf-8')
