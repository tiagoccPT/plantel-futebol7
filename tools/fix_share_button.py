from pathlib import Path

path = Path('plantel-online.html')
text = path.read_text(encoding='utf-8')

old = '''  async function shareApp() {\n    try {\n      await ensureRemote();\n      await saveOnline(true);\n\n      if (!remoteReady) {\n        throw new Error("O plantel ainda não está online.");\n      }\n\n      const url = location.href;\n\n      if (navigator.share) {\n        try {\n          await navigator.share({\n            title: "Plantel Futebol de 7",\n            text: "Ligação para abrir e editar o mesmo plantel.",\n            url\n          });\n          return;\n        } catch (error) {\n          if (error && error.name === "AbortError") return;\n        }\n      }\n\n      try {\n        await navigator.clipboard.writeText(url);\n        setSaveStatus("Ligação do plantel copiada.");\n      } catch {\n        prompt("Copie esta ligação do plantel:", url);\n      }\n    } catch (error) {\n      console.error(error);\n      alert("Não foi possível preparar a ligação porque o plantel não está online.");\n    }\n  }\n'''

new = '''  /* SHARE_IMMEDIATE_V1 */\n  async function shareApp() {\n    const url = location.href;\n\n    // A sincronização não deve bloquear o gesto de partilha do utilizador.\n    // Guardar/sincronizar continua em segundo plano.\n    saveOnline(false);\n\n    if (navigator.share) {\n      try {\n        await navigator.share({\n          title: "Plantel Futebol de 7",\n          text: "Ligação para abrir e editar o mesmo plantel.",\n          url\n        });\n        return;\n      } catch (error) {\n        if (error && error.name === "AbortError") return;\n        console.error(error);\n      }\n    }\n\n    try {\n      await navigator.clipboard.writeText(url);\n      setSaveStatus("Ligação do plantel copiada.");\n    } catch (error) {\n      console.error(error);\n      prompt("Copie esta ligação do plantel:", url);\n    }\n  }\n'''

if 'SHARE_IMMEDIATE_V1' in text:
    raise SystemExit(0)
if old not in text:
    raise RuntimeError('shareApp block not found')

text = text.replace(old, new, 1)

required = [
    'SHARE_IMMEDIATE_V1',
    'const url = location.href;',
    'saveOnline(false);',
    'await navigator.share({',
    'LIST_DRAG_FIX_V2',
    '"AV": "PL"',
]
for marker in required:
    if marker not in text:
        raise RuntimeError(f'Required marker missing: {marker}')

path.write_text(text, encoding='utf-8')
