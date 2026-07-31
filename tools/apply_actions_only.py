from pathlib import Path
import re

path = Path("plantel-online.html")
text = path.read_text(encoding="utf-8")

if "ACTIONS_ONLY_V1" in text:
    print("Actions update already applied.")
    raise SystemExit(0)


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 occurrence, found {count}")
    text = text.replace(old, new, 1)


replace_once(
    """  .actions button{
    padding:5px 7px;
    font-size:12px;
  }
""",
    """  .actions button{
    padding:5px 7px;
    font-size:12px;
  }

  /* ACTIONS_ONLY_V1 */
  .actions{flex-wrap:wrap}

  .actions button.active{
    font-weight:700;
    box-shadow:inset 0 0 0 2px rgba(255,255,255,.9);
  }

  .actions [data-role="inicial"].active{
    background:#e2ebff;
    border-color:#7791c8;
  }

  .actions [data-role="suplente"].active{
    background:#d4af37;
    border-color:#9a7615;
    color:#241b00;
  }

  .actions [data-role="reserva"].active{
    background:#777f8c;
    border-color:#555d68;
    color:#fff;
  }

  .plantel-bar{
    display:flex;
    justify-content:flex-end;
    margin-top:10px;
  }

  #plantel{
    min-width:110px;
    background:#e2ebff;
    border-color:#7791c8;
    font-weight:700;
  }

  #plantel.active{
    background:#d4af37;
    border-color:#9a7615;
    color:#241b00;
  }
""",
    "CSS actions",
)

replace_once(
    """    </table>

    <div class="legend">""",
    """    </table>

    <div class="plantel-bar">
      <button id="plantel" type="button" aria-pressed="false">Plantel</button>
    </div>

    <div class="legend">""",
    "Plantel button",
)

replace_once(
    """  let saveAgain = false;

  const els = {""",
    """  let saveAgain = false;
  let plantelViewActive = false;
  let plantelSnapshot = null;

  const els = {""",
    "Plantel variables",
)

replace_once(
    """    limparCampo: document.getElementById("limparCampo"),
    lista: document.getElementById("lista"),""",
    """    limparCampo: document.getElementById("limparCampo"),
    plantel: document.getElementById("plantel"),
    lista: document.getElementById("lista"),""",
    "Plantel element",
)

replace_once(
    """  function cardColor(position) {
    const pos = normalizePosition(position);
    if (pos === "GR") return "#f0c83f";
    if (["DD", "DE", "DC"].includes(pos)) return "#3f91dc";
    if (pos === "MC") return "#54a85c";
    return "#ed8434";
  }
""",
    """  function normalizeStatus(value) {
    const status = String(value || "").toLowerCase();
    return ["suplente", "reserva"].includes(status) ? status : "inicial";
  }

  function ensurePlayerShape(player) {
    player.status = normalizeStatus(player.status);
    if (!Array.isArray(player.cards)) player.cards = [];
    return player;
  }

  function cardColor(position, status) {
    const normalizedStatus = normalizeStatus(status);
    if (normalizedStatus === "suplente") return "#d4af37";
    if (normalizedStatus === "reserva") return "#777f8c";

    const pos = normalizePosition(position);
    if (pos === "GR") return "#f0c83f";
    if (["DD", "DE", "DC"].includes(pos)) return "#3f91dc";
    if (pos === "MC") return "#54a85c";
    return "#ed8434";
  }
""",
    "Card colours",
)

replace_once(
    """    state.players = local.players;
    state.updatedAt = local.updatedAt;""",
    """    state.players = local.players.map(ensurePlayerShape);
    state.updatedAt = local.updatedAt;""",
    "Local player normalization",
)

replace_once(
    """        players: Array.isArray(data.players) ? data.players : [],
        updatedAt: Number(data.updatedAt) || 0""",
    """        players: Array.isArray(data.players)
          ? data.players.map(ensurePlayerShape)
          : [],
        updatedAt: Number(data.updatedAt) || 0""",
    "Remote player normalization",
)

replace_once(
    """      secundaria: els.secundaria.value.trim(),
      cards: []""",
    """      secundaria: els.secundaria.value.trim(),
      status: "inicial",
      cards: []""",
    "New player status",
)

replace_once(
    """  function addPlayer() {
    const nome = els.nome.value.trim();""",
    """  function addPlayer() {
    if (plantelViewActive) restorePlantelSnapshot(false);

    const nome = els.nome.value.trim();""",
    "Add player exits Plantel view",
)

replace_once(
    """  function removePlayer(playerId) {
    state.players = state.players.filter(player => player.id !== playerId);""",
    """  function removePlayer(playerId) {
    if (plantelViewActive) restorePlantelSnapshot(false);

    state.players = state.players.filter(player => player.id !== playerId);""",
    "Remove player exits Plantel view",
)

replace_once(
    """  function clearField() {
    state.players.forEach(player => {""",
    """  function clearField() {
    plantelViewActive = false;
    plantelSnapshot = null;

    state.players.forEach(player => {""",
    "Clear Plantel state",
)

place_pattern = re.compile(
    r"  function placePlayer\(playerId\) \{[\s\S]*?\n  \}\n\n  function getSelectedCard\(\) \{"
)
place_replacement = """  function cloneCards(cards) {
    return (Array.isArray(cards) ? cards : []).map(card => ({ ...card }));
  }

  function buildPlayerCards(player) {
    const cards = [];
    const positions = [player.principal, player.secundaria];

    positions.forEach((label, index) => {
      if (!String(label || "").trim()) return;

      const canonical = normalizePosition(label);
      let [x, y] = POSITION_COORDINATES[canonical] || [334, 525];

      const sameAsFirst =
        index === 1 &&
        player.principal &&
        normalizePosition(player.principal) === canonical;

      if (sameAsFirst) {
        x += 20;
        y += 20;
      }

      cards.push({
        id: uid(),
        label: String(label).trim(),
        x,
        y,
        width: 132,
        height: 52,
        fontSize: 12
      });
    });

    return cards;
  }

  function restorePlantelSnapshot(shouldSave = true) {
    if (!plantelViewActive) return;

    const cardsByPlayer = new Map(
      (plantelSnapshot || []).map(item => [item.id, item.cards])
    );

    state.players.forEach(player => {
      if (cardsByPlayer.has(player.id)) {
        player.cards = cloneCards(cardsByPlayer.get(player.id));
      }
    });

    plantelViewActive = false;
    plantelSnapshot = null;
    state.selectedCardId = null;

    if (shouldSave) save();
  }

  function placePlayer(playerId, status) {
    if (plantelViewActive) restorePlantelSnapshot(false);

    const player = state.players.find(item => item.id === playerId);
    if (!player) return;

    player.status = normalizeStatus(status);
    player.cards = buildPlayerCards(player);

    save();
    render();
  }

  function togglePlantel() {
    if (!plantelViewActive) {
      plantelSnapshot = state.players.map(player => ({
        id: player.id,
        cards: cloneCards(player.cards)
      }));

      state.players.forEach(player => {
        player.status = normalizeStatus(player.status);
        player.cards = buildPlayerCards(player);
      });

      plantelViewActive = true;
      state.selectedCardId = null;
      render();
      return;
    }

    restorePlantelSnapshot(true);
    render();
  }

  function getSelectedCard() {"""

text, count = place_pattern.subn(place_replacement, text, count=1)
if count != 1:
    raise SystemExit(f"Place player block: expected 1 replacement, found {count}")

table_pattern = re.compile(
    r"  function renderTable\(\) \{[\s\S]*?\n  \}\n\n  function renderField\(\) \{"
)
table_replacement = """  function renderTable() {
    els.lista.innerHTML = "";

    state.players.forEach(player => {
      player.status = normalizeStatus(player.status);

      const row = document.createElement("tr");
      row.innerHTML = `
        <td>${escapeHtml(player.numero)}</td>
        <td>${escapeHtml(player.nome)}</td>
        <td>${escapeHtml(player.ano)}</td>
        <td>${escapeHtml(player.principal)}</td>
        <td>${escapeHtml(player.secundaria)}</td>
        <td>
          <div class="actions">
            <button type="button" data-role="inicial" class="${player.status === "inicial" ? "active" : ""}">Inicial</button>
            <button type="button" data-role="suplente" class="${player.status === "suplente" ? "active" : ""}">Suplente</button>
            <button type="button" data-role="reserva" class="${player.status === "reserva" ? "active" : ""}">Reserva</button>
            <button type="button" data-action="delete" title="Eliminar jogador">🗑️</button>
          </div>
        </td>
      `;

      row.querySelectorAll("[data-role]").forEach(button => {
        button.addEventListener("click", () => {
          placePlayer(player.id, button.dataset.role);
        });
      });

      row.querySelector('[data-action="delete"]').addEventListener("click", () => {
        removePlayer(player.id);
      });

      els.lista.appendChild(row);
    });

    els.plantel.classList.toggle("active", plantelViewActive);
    els.plantel.setAttribute("aria-pressed", String(plantelViewActive));
  }

  function renderField() {"""

text, count = table_pattern.subn(table_replacement, text, count=1)
if count != 1:
    raise SystemExit(f"Render table block: expected 1 replacement, found {count}")

replace_once(
    """      fill: cardColor(card.label)""",
    """      fill: cardColor(card.label, player.status)""",
    "Card status colour",
)

replace_once(
    """  els.limparCampo.addEventListener("click", clearField);

  [els.nome,""",
    """  els.limparCampo.addEventListener("click", clearField);
  els.plantel.addEventListener("click", togglePlantel);

  [els.nome,""",
    "Plantel event",
)

path.write_text(text, encoding="utf-8")
print("Actions-only update applied successfully.")
