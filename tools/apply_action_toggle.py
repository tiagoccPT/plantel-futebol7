from pathlib import Path

path = Path("plantel-online.html")
text = path.read_text(encoding="utf-8")


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 occurrence, found {count}")
    text = text.replace(old, new, 1)


replace_once(
'''  function ensurePlayerShape(player) {
    player.status = normalizeStatus(player.status);
    if (!Array.isArray(player.cards)) player.cards = [];
    return player;
  }''',
'''  function ensurePlayerShape(player) {
    player.status = normalizeStatus(player.status);
    if (!Array.isArray(player.cards)) player.cards = [];
    if (typeof player.selected !== "boolean") {
      player.selected = player.cards.length > 0;
    }
    return player;
  }''',
"ensurePlayerShape",
)

replace_once(
'''      status: "inicial",
      cards: []''',
'''      status: "inicial",
      selected: false,
      cards: []''',
"new player selected state",
)

replace_once(
'''    state.players.forEach(player => {
      player.cards = [];
    });''',
'''    state.players.forEach(player => {
      player.selected = false;
      player.cards = [];
    });''',
"clearField",
)

replace_once(
'''  function restorePlantelSnapshot(shouldSave = true) {
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
  }''',
'''  function restorePlantelSnapshot(shouldSave = true) {
    if (!plantelViewActive) return;

    const snapshotByPlayer = new Map(
      (plantelSnapshot || []).map(item => [item.id, item])
    );

    state.players.forEach(player => {
      const saved = snapshotByPlayer.get(player.id);
      if (saved) {
        player.cards = cloneCards(saved.cards);
        player.selected = Boolean(saved.selected);
        player.status = normalizeStatus(saved.status);
      }
    });

    plantelViewActive = false;
    plantelSnapshot = null;
    state.selectedCardId = null;

    if (shouldSave) save();
  }''',
"restorePlantelSnapshot",
)

replace_once(
'''  function placePlayer(playerId, status) {
    if (plantelViewActive) restorePlantelSnapshot(false);

    const player = state.players.find(item => item.id === playerId);
    if (!player) return;

    player.status = normalizeStatus(status);
    player.cards = buildPlayerCards(player);

    save();
    render();
  }''',
'''  function placePlayer(playerId, status) {
    if (plantelViewActive) restorePlantelSnapshot(false);

    const player = state.players.find(item => item.id === playerId);
    if (!player) return;

    const requestedStatus = normalizeStatus(status);
    const sameSelection = player.selected && player.status === requestedStatus;

    if (sameSelection) {
      player.selected = false;
      player.cards = [];
      if (state.selectedCardId && !getSelectedCard()) {
        state.selectedCardId = null;
      }
    } else {
      player.status = requestedStatus;
      player.selected = true;
      player.cards = buildPlayerCards(player);
    }

    save();
    render();
  }''',
"placePlayer toggle",
)

replace_once(
'''      plantelSnapshot = state.players.map(player => ({
        id: player.id,
        cards: cloneCards(player.cards)
      }));''',
'''      plantelSnapshot = state.players.map(player => ({
        id: player.id,
        selected: Boolean(player.selected),
        status: normalizeStatus(player.status),
        cards: cloneCards(player.cards)
      }));''',
"plantel snapshot",
)

replace_once(
'''            <button type="button" data-role="inicial" class="${player.status === "inicial" ? "active" : ""}">Inicial</button>
            <button type="button" data-role="suplente" class="${player.status === "suplente" ? "active" : ""}">Suplente</button>
            <button type="button" data-role="reserva" class="${player.status === "reserva" ? "active" : ""}">Reserva</button>''',
'''            <button type="button" data-role="inicial" class="${player.selected && player.status === "inicial" ? "active" : ""}">Inicial</button>
            <button type="button" data-role="suplente" class="${player.selected && player.status === "suplente" ? "active" : ""}">Suplente</button>
            <button type="button" data-role="reserva" class="${player.selected && player.status === "reserva" ? "active" : ""}">Reserva</button>''',
"active role buttons",
)

path.write_text(text, encoding="utf-8")
