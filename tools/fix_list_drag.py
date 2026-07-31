from pathlib import Path

path = Path("plantel-online.html")
text = path.read_text(encoding="utf-8")

start = text.find("  function enablePlayerRowDrag(row) {")
end = text.find("  function renderTable() {", start)
if start < 0 or end < 0:
    raise RuntimeError("Drag function block not found")

new_function = r'''  function enablePlayerRowDrag(row) {
    const handle = row.querySelector('[data-action="drag"]');
    if (!handle) return;

    handle.addEventListener("pointerdown", event => {
      if (event.pointerType === "mouse" && event.button !== 0) return;

      event.preventDefault();
      event.stopPropagation();

      const pointerId = event.pointerId;
      let moved = false;

      row.classList.add("dragging-row");
      document.body.classList.add("reordering-list");

      const onMove = moveEvent => {
        if (moveEvent.pointerId !== pointerId) return;
        moveEvent.preventDefault();

        const y = moveEvent.clientY;
        const rows = Array.from(
          els.lista.querySelectorAll("tr[data-player-id]")
        ).filter(item => item !== row);

        let placed = false;

        for (const target of rows) {
          const rect = target.getBoundingClientRect();
          if (y < rect.top + rect.height / 2) {
            if (row.nextSibling !== target) {
              els.lista.insertBefore(row, target);
              moved = true;
            }
            placed = true;
            break;
          }
        }

        if (!placed && row !== els.lista.lastElementChild) {
          els.lista.appendChild(row);
          moved = true;
        }

        const edge = 70;
        if (y < edge) window.scrollBy(0, -12);
        if (y > window.innerHeight - edge) window.scrollBy(0, 12);
      };

      const finish = finishEvent => {
        if (finishEvent && finishEvent.pointerId !== pointerId) return;

        document.removeEventListener("pointermove", onMove, true);
        document.removeEventListener("pointerup", finish, true);
        document.removeEventListener("pointercancel", finish, true);

        row.classList.remove("dragging-row");
        document.body.classList.remove("reordering-list");

        if (moved) commitPlayerOrderFromTable();
      };

      document.addEventListener("pointermove", onMove, {
        capture: true,
        passive: false
      });
      document.addEventListener("pointerup", finish, true);
      document.addEventListener("pointercancel", finish, true);
    });
  }

'''

text = text[:start] + new_function + text[end:]

# Add an explicit marker so the deployed fix can be verified.
if "LIST_DRAG_FIX_V2" not in text:
    text = text.replace(
        "  /* LIST_DRAG_AV_V1 */",
        "  /* LIST_DRAG_AV_V1 */\n  /* LIST_DRAG_FIX_V2 */",
        1,
    )

required = [
    "LIST_DRAG_FIX_V2",
    'document.addEventListener("pointermove", onMove',
    'window.scrollBy(0, -12)',
    "function commitPlayerOrderFromTable()",
    'data-action="drag"',
]
for marker in required:
    if marker not in text:
        raise RuntimeError(f"Required marker missing: {marker}")

path.write_text(text, encoding="utf-8")
