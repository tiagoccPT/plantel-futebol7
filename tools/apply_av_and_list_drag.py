from pathlib import Path

path = Path("plantel-online.html")
text = path.read_text(encoding="utf-8")

if "LIST_DRAG_AV_V1" in text:
    raise SystemExit(0)

# Reconhecer AV como posição ofensiva equivalente a PL.
alias_marker = '      "PL": "PL",\n'
if alias_marker not in text:
    raise RuntimeError("PL alias marker not found")
text = text.replace(alias_marker, alias_marker + '      "AV": "PL",\n', 1)

legend_old = "GR, DD, DE, DC, MC, ED, EE e PL"
legend_new = "GR, DD, DE, DC, MC, ED, EE, PL e AV"
if legend_old not in text:
    raise RuntimeError("Legend marker not found")
text = text.replace(legend_old, legend_new, 1)

# Estilos da pega de arrasto e da linha durante a ordenação.
css_marker = "  /* PLANTEL_LAYOUT_MEMORY_V1 */"
css = '''  /* LIST_DRAG_AV_V1 */
  .drag-handle{
    cursor:grab;
    touch-action:none;
    font-weight:700;
    min-width:31px;
  }

  .drag-handle:active{cursor:grabbing}

  .dragging-row{
    opacity:.58;
    outline:2px dashed #b9c9e3;
    outline-offset:-2px;
  }

  body.reordering-list{
    user-select:none;
    cursor:grabbing;
  }

'''
if css_marker not in text:
    raise RuntimeError("CSS marker not found")
text = text.replace(css_marker, css + css_marker, 1)

# Funções de reordenação por pointer events, válidas em rato e toque.
helper_marker = "  function renderTable() {"
helpers = r'''  function commitPlayerOrderFromTable() {
    const ids = Array.from(els.lista.querySelectorAll("tr[data-player-id]"))
      .map(row => row.dataset.playerId)
      .filter(Boolean);

    if (ids.length !== state.players.length) return;

    const playersById = new Map(state.players.map(player => [player.id, player]));
    const reordered = ids.map(id => playersById.get(id)).filter(Boolean);

    if (reordered.length !== state.players.length) return;

    state.players = reordered;
    save();
    render();
  }

  function enablePlayerRowDrag(row) {
    const handle = row.querySelector('[data-action="drag"]');
    if (!handle) return;

    handle.addEventListener("pointerdown", event => {
      if (event.pointerType === "mouse" && event.button !== 0) return;

      event.preventDefault();
      event.stopPropagation();

      let moved = false;
      row.classList.add("dragging-row");
      document.body.classList.add("reordering-list");
      handle.setPointerCapture(event.pointerId);

      const onMove = moveEvent => {
        moveEvent.preventDefault();

        const element = document.elementFromPoint(moveEvent.clientX, moveEvent.clientY);
        const target = element && element.closest("tr[data-player-id]");

        if (!target || target === row || target.parentElement !== els.lista) return;

        const rect = target.getBoundingClientRect();
        const insertBefore = moveEvent.clientY < rect.top + rect.height / 2;

        if (insertBefore) {
          els.lista.insertBefore(row, target);
        } else {
          els.lista.insertBefore(row, target.nextSibling);
        }

        moved = true;
      };

      const finish = () => {
        row.classList.remove("dragging-row");
        document.body.classList.remove("reordering-list");

        handle.removeEventListener("pointermove", onMove);
        handle.removeEventListener("pointerup", finish);
        handle.removeEventListener("pointercancel", finish);

        if (moved) commitPlayerOrderFromTable();
      };

      handle.addEventListener("pointermove", onMove);
      handle.addEventListener("pointerup", finish);
      handle.addEventListener("pointercancel", finish);
    });
  }

'''
if helper_marker not in text:
    raise RuntimeError("renderTable marker not found")
text = text.replace(helper_marker, helpers + helper_marker, 1)

# Adicionar pega apenas nas linhas em modo normal, sem interferir com a edição.
buttons_marker = '''            <div class="actions">
              <button type="button" data-role="inicial"'''
buttons_replacement = '''            <div class="actions">
              <button type="button" data-action="drag" class="drag-handle" title="Arrastar jogador" aria-label="Arrastar jogador">☰</button>
              <button type="button" data-role="inicial"'''
if buttons_marker not in text:
    raise RuntimeError("Normal action buttons marker not found")
text = text.replace(buttons_marker, buttons_replacement, 1)

# Ativar o arrasto depois de ligar os restantes botões da linha normal.
listener_marker = '''        row.querySelector('[data-action="delete"]').addEventListener("click", () => {
          removePlayer(player.id);
        });
      }

      els.lista.appendChild(row);'''
listener_replacement = '''        row.querySelector('[data-action="delete"]').addEventListener("click", () => {
          removePlayer(player.id);
        });

        enablePlayerRowDrag(row);
      }

      els.lista.appendChild(row);'''
if listener_marker not in text:
    raise RuntimeError("Normal row listener marker not found")
text = text.replace(listener_marker, listener_replacement, 1)

required = [
    "LIST_DRAG_AV_V1",
    '"AV": "PL"',
    "function enablePlayerRowDrag(row)",
    "function commitPlayerOrderFromTable()",
    'data-action="drag"',
    "GR, DD, DE, DC, MC, ED, EE, PL e AV",
    "function togglePlantel()",
    "INLINE_EDIT_V1",
    "PLANTEL_LAYOUT_MEMORY_V1",
]
for marker in required:
    if marker not in text:
        raise RuntimeError(f"Required marker missing: {marker}")

path.write_text(text, encoding="utf-8")
