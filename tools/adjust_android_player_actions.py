from pathlib import Path

main = Path('flutter_app/lib/main.dart')
pubspec = Path('flutter_app/pubspec.yaml')
text = main.read_text(encoding='utf-8')

old = """  Widget _playerRow(Player player, int index) {
    final activeColor = !player.selected
"""
new = """  Widget _playerRow(Player player, int index) {
    final androidCompact = defaultTargetPlatform == TargetPlatform.android &&
        MediaQuery.sizeOf(context).width < 600;
    final activeColor = !player.selected
"""
if old not in text:
    raise SystemExit('playerRow marker not found')
text = text.replace(old, new, 1)

repls = [
    ("""            SizedBox(
              width: 150,
              child: Column(""", """            SizedBox(
              width: androidCompact ? 96 : 150,
              child: Column("""),
    ("""                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.05),""", """                    style: TextStyle(
                      fontSize: androidCompact ? 11.2 : 13,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),"""),
    ("""                    style: const TextStyle(color: _muted, fontSize: 9.5, height: 1.0),""", """                    style: TextStyle(
                      color: _muted,
                      fontSize: androidCompact ? 8.7 : 9.5,
                      height: 1.0,
                    ),"""),
    ("""            const SizedBox(width: 6),
            Flexible(
              child: Align(""", """            SizedBox(width: androidCompact ? 3 : 6),
            Flexible(
              child: Align("""),
    ("""                      const SizedBox(width: 2),
                      _statusButton(player, PlayerStatus.suplente, 'Suplente', Icons.event_seat_outlined),
                      const SizedBox(width: 2),
                      _statusButton(player, PlayerStatus.reserva, 'Reserva', Icons.inventory_2_outlined),
                      const SizedBox(width: 2),""", """                      SizedBox(width: androidCompact ? 1 : 2),
                      _statusButton(player, PlayerStatus.suplente, 'Suplente', Icons.event_seat_outlined),
                      SizedBox(width: androidCompact ? 1 : 2),
                      _statusButton(player, PlayerStatus.reserva, 'Reserva', Icons.inventory_2_outlined),
                      SizedBox(width: androidCompact ? 1 : 2),"""),
    ("""                        constraints: const BoxConstraints.tightFor(width: 26, height: 26),""", """                        constraints: BoxConstraints.tightFor(
                          width: androidCompact ? 29 : 26,
                          height: androidCompact ? 29 : 26,
                        ),"""),
    ("""                        icon: const Icon(Icons.edit_outlined, size: 16),""", """                        icon: Icon(Icons.edit_outlined, size: androidCompact ? 18 : 16),"""),
    ("""                        icon: const Icon(Icons.delete_outline, size: 17),""", """                        icon: Icon(Icons.delete_outline, size: androidCompact ? 19 : 17),"""),
]

for old, new in repls:
    if old not in text:
        raise SystemExit(f'missing pattern: {old[:80]!r}')
    text = text.replace(old, new, 1)

# second identical IconButton constraint for delete
old_constraint = """                        constraints: const BoxConstraints.tightFor(width: 26, height: 26),"""
new_constraint = """                        constraints: BoxConstraints.tightFor(
                          width: androidCompact ? 29 : 26,
                          height: androidCompact ? 29 : 26,
                        ),"""
if old_constraint not in text:
    raise SystemExit('delete constraint not found')
text = text.replace(old_constraint, new_constraint, 1)

old = """  Widget _statusButton(Player player, PlayerStatus status, String label, IconData icon) {
    final active = player.selected && player.status == status;
"""
new = """  Widget _statusButton(Player player, PlayerStatus status, String label, IconData icon) {
    final androidCompact = defaultTargetPlatform == TargetPlatform.android &&
        MediaQuery.sizeOf(context).width < 600;
    final active = player.selected && player.status == status;
"""
if old not in text:
    raise SystemExit('statusButton marker not found')
text = text.replace(old, new, 1)

old = """        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 11),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),"""
new = """        padding: EdgeInsets.symmetric(
          horizontal: androidCompact ? 6.5 : 5,
          vertical: androidCompact ? 4.5 : 3,
        ),
        minimumSize: Size(0, androidCompact ? 29 : 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: androidCompact ? 13 : 11),
      label: Text(
        label,
        style: TextStyle(
          fontSize: androidCompact ? 11.2 : 10,
          fontWeight: FontWeight.w700,
        ),
      ),"""
if old not in text:
    raise SystemExit('status style block not found')
text = text.replace(old, new, 1)

main.write_text(text, encoding='utf-8')

p = pubspec.read_text(encoding='utf-8')
if 'version: 1.0.4+5' in p:
    p = p.replace('version: 1.0.4+5', 'version: 1.0.5+6', 1)
elif 'version: 1.0.5+6' not in p:
    raise SystemExit('unexpected version')
pubspec.write_text(p, encoding='utf-8')
print('ANDROID_ACTIONS_PATCH_OK')
