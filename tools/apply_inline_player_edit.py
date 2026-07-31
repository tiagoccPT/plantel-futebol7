from pathlib import Path

path = Path("plantel-online.html")
text = path.read_text(encoding="utf-8")

if "INLINE_EDIT_V1" in text:
    raise SystemExit(0)

css_marker = "  /* ACTIONS_ONLY_V1 */"
css = '''  /* INLINE_EDIT_V1 */
  .edit-input{
    width:100%;
    min-width:68px;
    padding:5px 6px;
    font-size:12px;
  }

  .editing-row td{
    background:rgba(255,255,255,.04);
  }

  .actions [data-action="save-edit"]{
    background:#dff4e4;
    border-color:#72a77d;
    font-weight:700;
  }

  .actions [data-action="cancel-edit"]{
    background:#fff0d9;
    border-color:#c99b55;
  }

'''
if css_marker not in text:
    raise RuntimeError("CSS marker not found")
text = text.replace(css_marker, css + css_marker, 1)

variables_marker = "  let plantelSnapshot = null;\n"
if variables_marker not in text:
    raise RuntimeError("Variables marker not found")
text = text.replace(
    variables_marker,
    variables_marker + "  let editingPlayerId = null;\n",
    1,
)

helper_marker = "  function removePlayer(playerId) {"
helpers = r'''  function startEditPlayer(playerId) {
    if (plantelViewActive) restorePlantelSnapshot(false);

    editingPlayerId = playerId;
    render();

    requestAnimationFrame(() => {
      const row = Array.from(els.lista.querySelectorAll("tr")).find(
        item => item.dataset.playerId === playerId
      );
      const input = row && row.querySelector('[data-edit-field="nome"]');
      if (input) {
        input.focus();
        input.select();
      }
    });
  }

  function cancelEditPlayer() {
    editingPlayerId = null;
    renderTable();
  }

  function preserveEditedCardLayout(player, previousCards) {
    const rebuiltCards = buildPlayerCards(player);

    player.cards = rebuiltCards.map((card, index) => {
      const previous = previousCards[index];
      if (!previous) return card;

      return {
        ...card,
        id: previous.id || card.id,
        x: previous.x,
        y: previous.y,
        width: previous.width,
        height: previous.height,
        fontSize: previous.fontSize
      };
    });

    if (player.selected && player.cards.length === 0) {
      player.selected = false;
    }
  }

  function savePlayerEdit(playerId, row) {
    const player = state.players.find(item => item.id === playerId);
    if (!player || !row) return;

    const readField = name => {
      const input = row.querySelector(`[data-edit-field="${name}"]`);
      return input ? input.value.trim() : "";
    };

    const nome = readField("nome");
    if (!nome) {
      const input = row.querySelector('[data-edit-field="nome"]');
      if (input) input.focus();
      alert("O nome do jogador não pode ficar vazio.");
      return;
    }

    const previousCards = cloneCards(player.cards);

    player.numero = readField("numero");
    player.nome = nome;
    player.ano = readField("ano");
    player.principal = readField("principal");
    player.secundaria = readField("secundaria");

    if (player.selected || previousCards.length > 0) {
      preserveEditedCardLayout(player, previousCards);
    }

    if (state.selectedCardId && !getSelectedCard()) {
      state.selectedCardId = null;
    }

    editingPlayerId = null;
    save();
    render();
  }

'''
if helper_marker not in text:
    raise RuntimeError("Helper marker not found")
text = text.replace(helper_marker, helpers + helper_marker, 1)

remove_marker = '''  function removePlayer(playerId) {
    if (plantelViewActive) restorePlantelSnapshot(false);
'''
remove_replacement = '''  function removePlayer(playerId) {
    if (plantelViewActive) restorePlantelSnapshot(false);
    if (editingPlayerId === playerId) editingPlayerId = null;
'''
if remove_marker not in text:
    raise RuntimeError("Remove-player marker not found")
text = text.replace(remove_marker, remove_replacement, 1)

start = text.find("  function renderTable() {")
end = text.find("  function renderField() {", start)
if start < 0 or end < 0:
    raise RuntimeError("Render table block not found")

new_render_table = r'''  function renderTable() {
    els.lista.innerHTML = "";

    state.players.forEach(player => {
      player.status = normalizeStatus(player.status);
      const editing = editingPlayerId === player.id;

      const row = document.createElement("tr");
      row.dataset.playerId = player.id;

      if (editing) {
        row.classList.add("editing-row");
        row.innerHTML = `
          <td><input class="edit-input" data-edit-field="numero" value="${escapeHtml(player.numero)}" aria-label="Número"></td>
          <td><input class="edit-input" data-edit-field="nome" value="${escapeHtml(player.nome)}" aria-label="Nome"></td>
          <td><input class="edit-input" data-edit-field="ano" value="${escapeHtml(player.ano)}" aria-label="Ano"></td>
          <td><input class="edit-input" data-edit-field="principal" value="${escapeHtml(player.principal)}" aria-label="Posição principal"></td>
          <td><input class="edit-input" data-edit-field="secundaria" value="${escapeHtml(player.secundaria)}" aria-label="Posição secundária"></td>
          <td>
            <div class="actions">
              <button type="button" data-action="save-edit">Guardar</button>
              <button type="button" data-action="cancel-edit">Cancelar</button>
              <button type="button" data-action="delete" title="Eliminar jogador">🗑️</button>
            </div>
          </td>
        `;

        const submitEdit = () => savePlayerEdit(player.id, row);

        row.querySelector('[data-action="save-edit"]').addEventListener("click", submitEdit);
        row.querySelector('[data-action="cancel-edit"]').addEventListener("click", cancelEditPlayer);
        row.querySelector('[data-action="delete"]').addEventListener("click", () => {
          removePlayer(player.id);
        });

        row.querySelectorAll(".edit-input").forEach(input => {
          input.addEventListener("keydown", event => {
            if (event.key === "Enter") {
              event.preventDefault();
              submitEdit();
            }
            if (event.key === "Escape") {
              event.preventDefault();
              cancelEditPlayer();
            }
          });
        });
      } else {
        row.innerHTML = `
          <td>${escapeHtml(player.numero)}</td>
          <td>${escapeHtml(player.nome)}</td>
          <td>${escapeHtml(player.ano)}</td>
          <td>${escapeHtml(player.principal)}</td>
          <td>${escapeHtml(player.secundaria)}</td>
          <td>
            <div class="actions">
              <button type="button" data-role="inicial" class="${player.selected && player.status === "inicial" ? "active" : ""}">Inicial</button>
              <button type="button" data-role="suplente" class="${player.selected && player.status === "suplente" ? "active" : ""}">Suplente</button>
              <button type="button" data-role="reserva" class="${player.selected && player.status === "reserva" ? "active" : ""}">Reserva</button>
              <button type="button" data-action="edit" title="Editar jogador">Editar</button>
              <button type="button" data-action="delete" title="Eliminar jogador">🗑️</button>
            </div>
          </td>
        `;

        row.querySelectorAll("[data-role]").forEach(button => {
          button.addEventListener("click", () => {
            placePlayer(player.id, button.dataset.role);
          });
        });

        row.querySelector('[data-action="edit"]').addEventListener("click", () => {
          startEditPlayer(player.id);
        });

        row.querySelector('[data-action="delete"]').addEventListener("click", () => {
          removePlayer(player.id);
        });
      }

      els.lista.appendChild(row);
    });

    els.plantel.classList.toggle("active", plantelViewActive);
    els.plantel.setAttribute("aria-pressed", String(plantelViewActive));
  }

'''
text = text[:start] + new_render_table + text[end:]

required = [
    "INLINE_EDIT_V1",
    "function startEditPlayer(playerId)",
    "function savePlayerEdit(playerId, row)",
    'data-action="edit"',
    'data-edit-field="numero"',
    'data-edit-field="nome"',
    'data-edit-field="ano"',
    'data-edit-field="principal"',
    'data-edit-field="secundaria"',
    "function togglePlantel()",
    'const JSON_BLOB_API = "https://jsonblob.com/api/jsonBlob"',
]
for marker in required:
    if marker not in text:
        raise RuntimeError(f"Required marker missing: {marker}")

path.write_text(text, encoding="utf-8")
