from pathlib import Path

main_path = Path('flutter_app/lib/main.dart')
pubspec_path = Path('flutter_app/pubspec.yaml')
text = main_path.read_text(encoding='utf-8')

start = text.find('  Widget _playerRow(Player player, int index) {')
end = text.find('  Widget _fieldPanel() {', start)
if start == -1 or end == -1:
    raise SystemExit('Bloco _playerRow/_fieldPanel não encontrado')

new_block = r'''  Widget _playerRow(Player player, int index) {
    final activeColor = !player.selected
        ? _reserve
        : switch (player.status) {
            PlayerStatus.inicial => _primary,
            PlayerStatus.suplente => _gold,
            PlayerStatus.reserva => _reserve,
          };
    return Card(
      key: ValueKey(player.id),
      color: _panel2,
      margin: const EdgeInsets.symmetric(vertical: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: activeColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.drag_indicator, color: _muted, size: 18),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                player.numero.isEmpty ? '—' : player.numero,
                style: TextStyle(
                  color: player.status == PlayerStatus.suplente ? _bg : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.05),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${player.ano.isEmpty ? '—' : player.ano} • ${player.principal.isEmpty ? '—' : player.principal}${player.secundaria.isEmpty ? '' : ' / ${player.secundaria}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 9.5, height: 1.0),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 9,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _statusButton(player, PlayerStatus.inicial, 'Inicial', Icons.sports_soccer),
                      const SizedBox(width: 2),
                      _statusButton(player, PlayerStatus.suplente, 'Suplente', Icons.event_seat_outlined),
                      const SizedBox(width: 2),
                      _statusButton(player, PlayerStatus.reserva, 'Reserva', Icons.inventory_2_outlined),
                      const SizedBox(width: 2),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Editar',
                        onPressed: () => _editPlayer(player),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Eliminar',
                        onPressed: () => _removePlayer(player),
                        icon: const Icon(Icons.delete_outline, size: 17),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(Player player, PlayerStatus status, String label, IconData icon) {
    final active = player.selected && player.status == status;
    final color = switch (status) {
      PlayerStatus.inicial => const Color(0xFF3F91DC),
      PlayerStatus.suplente => _gold,
      PlayerStatus.reserva => _reserve,
    };
    return FilledButton.tonalIcon(
      onPressed: () => _placePlayer(player, status),
      style: FilledButton.styleFrom(
        backgroundColor: active ? color.withValues(alpha: 0.95) : _panel,
        foregroundColor: active && status == PlayerStatus.suplente ? _bg : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 11),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

'''

text = text[:start] + new_block + text[end:]
main_path.write_text(text, encoding='utf-8')

pubspec = pubspec_path.read_text(encoding='utf-8')
if 'version: 1.0.1+2' in pubspec:
    pubspec = pubspec.replace('version: 1.0.1+2', 'version: 1.0.2+3', 1)
elif 'version: 1.0.2+3' not in pubspec:
    raise SystemExit('Versão inesperada no pubspec.yaml')
pubspec_path.write_text(pubspec, encoding='utf-8')

print('PLAYER_ROW_V3_OK')
