from pathlib import Path
import re

path = Path("plantel-online.html")
text = path.read_text(encoding="utf-8")

if "PLANTEL_LAYOUT_MEMORY_V1" in text:
    raise SystemExit(0)

# Mark the feature without changing the interface.
marker = "  /* INLINE_EDIT_V1 */"
if marker not in text:
    raise RuntimeError("Inline edit marker not found")
text = text.replace(marker, "  /* PLANTEL_LAYOUT_MEMORY_V1 */\n" + marker, 1)

# Keep a separate, persistent layout for the complete Plantel view.
old_shape = '''  function ensurePlayerShape(player) {
    player.status = normalizeStatus(player.status);
    if (!Array.isArray(player.cards)) player.cards = [];
    if (typeof player.selected !== "boolean") {
      player.selected = player.cards.length > 0;
    }
    return player;
  }
'''
new_shape = '''  function ensurePlayerShape(player) {
    player.status = normalizeStatus(player.status);
    if (!Array.isArray(player.cards)) player.cards = [];
    if (!Array.isArray(player.plantelCards)) player.plantelCards = [];
    if (typeof player.selected !== "boolean") {
      player.selected = player.cards.length > 0;
    }
    return player;
  }
'''
if old_shape not in text:
    raise RuntimeError("Player shape block not found")
text = text.replace(old_shape, new_shape, 1)

# Synchronise the remembered layout before local and online saves while Plantel is visible.
old_save = '''  function save() {
    state.updatedAt = Date.now();
    writeLocal();
'''
new_save = '''  function save() {
    if (plantelViewActive) rememberPlantelLayout();
    state.updatedAt = Date.now();
    writeLocal();
'''
if old_save not in text:
    raise RuntimeError("Save function marker not found")
text = text.replace(old_save, new_save, 1)

old_online_save = '''      state.updatedAt = Date.now();
      writeLocal();

      const response = await fetch(blobUrl(), {
'''
new_online_save = '''      if (plantelViewActive) rememberPlantelLayout();
      state.updatedAt = Date.now();
      writeLocal();

      const response = await fetch(blobUrl(), {
'''
if old_online_save not in text:
    raise RuntimeError("Online save marker not found")
text = text.replace(old_online_save, new_online_save, 1)

# New players start without a remembered Plantel layout.
old_new_player = '''      status: "inicial",
      selected: false,
      cards: []
'''
new_new_player = '''      status: "inicial",
      selected: false,
      cards: [],
      plantelCards: []
'''
if old_new_player not in text:
    raise RuntimeError("New player block not found")
text = text.replace(old_new_player, new_new_player, 1)

# Add reusable layout helpers immediately after cloneCards.
clone_block = '''  function cloneCards(cards) {
    return (Array.isArray(cards) ? cards : []).map(card => ({ ...card }));
  }
'''
helpers = '''  function cloneCards(cards) {
    return (Array.isArray(cards) ? cards : []).map(card => ({ ...card }));
  }

  function rebuildCardsPreservingLayout(player, previousCards) {
    const rebuiltCards = buildPlayerCards(player);
    const savedCards = cloneCards(previousCards);

    return rebuiltCards.map((card, index) => {
      const previous = savedCards[index];
      if (!previous) return card;

      return {
        ...card,
        id: previous.id || card.id,
        x: Number.isFinite(previous.x) ? previous.x : card.x,
        y: Number.isFinite(previous.y) ? previous.y : card.y,
        width: Number.isFinite(previous.width) ? previous.width : card.width,
        height: Number.isFinite(previous.height) ? previous.height : card.height,
        fontSize: Number.isFinite(previous.fontSize) ? previous.fontSize : card.fontSize
      };
    });
  }

  function rememberPlantelLayout() {
    state.players.forEach(player => {
      player.plantelCards = cloneCards(player.cards);
    });
  }

  function buildRememberedPlantelCards(player) {
    const remembered = Array.isArray(player.plantelCards) && player.plantelCards.length
      ? player.plantelCards
      : player.cards;

    return rebuildCardsPreservingLayout(player, remembered);
  }
'''
if clone_block not in text:
    raise RuntimeError("cloneCards block not found")
text = text.replace(clone_block, helpers, 1)

# Editing a player also refreshes the remembered Plantel labels while keeping its layout.
pattern = re.compile(
    r'''  function preserveEditedCardLayout\(player, previousCards\) \{.*?\n  \}\n\n  function savePlayerEdit''',
    re.S,
)
replacement = '''  function preserveEditedCardLayout(player, previousCards) {
    const previousPlantelCards = cloneCards(player.plantelCards);

    player.cards = rebuildCardsPreservingLayout(player, previousCards);

    if (previousPlantelCards.length > 0) {
      player.plantelCards = rebuildCardsPreservingLayout(player, previousPlantelCards);
    }

    if (player.selected && player.cards.length === 0) {
      player.selected = false;
    }
  }

  function savePlayerEdit'''
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise RuntimeError("preserveEditedCardLayout block not found")

# Always remember movements made in Plantel before restoring the normal field.
old_restore = '''  function restorePlantelSnapshot(shouldSave = true) {
    if (!plantelViewActive) return;

    const snapshotByPlayer = new Map(
'''
new_restore = '''  function restorePlantelSnapshot(shouldSave = true) {
    if (!plantelViewActive) return;

    rememberPlantelLayout();

    const snapshotByPlayer = new Map(
'''
if old_restore not in text:
    raise RuntimeError("Restore Plantel block not found")
text = text.replace(old_restore, new_restore, 1)

# Reopen Plantel using the last arranged positions instead of rebuilding every card on top of the others.
old_toggle_part = '''      state.players.forEach(player => {
        player.status = normalizeStatus(player.status);
        player.cards = buildPlayerCards(player);
      });

      plantelViewActive = true;
'''
new_toggle_part = '''      state.players.forEach(player => {
        player.status = normalizeStatus(player.status);
        player.cards = buildRememberedPlantelCards(player);
      });

      plantelViewActive = true;
'''
if old_toggle_part not in text:
    raise RuntimeError("Toggle Plantel layout block not found")
text = text.replace(old_toggle_part, new_toggle_part, 1)

required = [
    "PLANTEL_LAYOUT_MEMORY_V1",
    "player.plantelCards",
    "function rememberPlantelLayout()",
    "function buildRememberedPlantelCards(player)",
    "player.cards = buildRememberedPlantelCards(player);",
    "function togglePlantel()",
    "INLINE_EDIT_V1",
    'const JSON_BLOB_API = "https://jsonblob.com/api/jsonBlob"',
]
for required_marker in required:
    if required_marker not in text:
        raise RuntimeError(f"Required marker missing: {required_marker}")

path.write_text(text, encoding="utf-8")
