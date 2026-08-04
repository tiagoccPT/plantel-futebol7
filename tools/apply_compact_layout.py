from pathlib import Path

main_path = Path('flutter_app/lib/main.dart')
pubspec_path = Path('flutter_app/pubspec.yaml')
text = main_path.read_text(encoding='utf-8')

replacements = {
    "SizedBox(height: 720, child: _leftPanel()),": "SizedBox(height: 620, child: _leftPanel()),",
    "margin: const EdgeInsets.symmetric(vertical: 4),": "margin: const EdgeInsets.symmetric(vertical: 2),",
    "padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),": "padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),",
    "child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.drag_indicator, color: _muted)),": "child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.drag_indicator, color: _muted, size: 20)),",
    "width: 38,\n              height: 38,": "width: 34,\n              height: 34,",
    "const SizedBox(width: 9),": "const SizedBox(width: 7),",
    "style: const TextStyle(color: _muted, fontSize: 11),": "style: const TextStyle(color: _muted, fontSize: 10),",
    "const SizedBox(height: 6),\n                  Wrap(": "const SizedBox(height: 3),\n                  Wrap(",
    "spacing: 4,\n                    runSpacing: 4,": "spacing: 3,\n                    runSpacing: 2,",
    "IconButton(visualDensity: VisualDensity.compact, tooltip: 'Editar', onPressed: () => _editPlayer(player), icon: const Icon(Icons.edit_outlined, size: 18)),": "IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 30, height: 30), visualDensity: VisualDensity.compact, tooltip: 'Editar', onPressed: () => _editPlayer(player), icon: const Icon(Icons.edit_outlined, size: 17)),",
    "IconButton(visualDensity: VisualDensity.compact, tooltip: 'Eliminar', onPressed: () => _removePlayer(player), icon: const Icon(Icons.delete_outline, size: 19)),": "IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 30, height: 30), visualDensity: VisualDensity.compact, tooltip: 'Eliminar', onPressed: () => _removePlayer(player), icon: const Icon(Icons.delete_outline, size: 18)),",
    "padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),\n        visualDensity: VisualDensity.compact,": "padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),\n        minimumSize: Size.zero,\n        tapTargetSize: MaterialTapTargetSize.shrinkWrap,\n        visualDensity: VisualDensity.compact,",
    "icon: Icon(icon, size: 14),\n      label: Text(label),": "icon: Icon(icon, size: 12),\n      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),",
}

for old, new in replacements.items():
    if old not in text:
        print(f'WARN: padrão não encontrado: {old[:70]!r}')
    text = text.replace(old, new)

old_field = """              FootballField(
                players: _data.players,
                selectedCardId: _selectedCardId,
                onSelect: (id) => setState(() => _selectedCardId = id),
                onMove: _moveCard,
                onResize: _resizeCard,
                onFontChange: _fontCard,
                onInteractionStart: () => _setDragInteraction(true),
                onInteractionEnd: () => _setDragInteraction(false),
              ),
              const SizedBox(height: 12),
              _substitutesBar(),
              if (_reserves.isNotEmpty) ...[
                const SizedBox(height: 8),
                _reservesBar(),
              ],
"""
new_field = """              _compactField(),
              const SizedBox(height: 8),
              _benchBars(),
"""
if old_field not in text:
    raise SystemExit('Bloco do campo principal não encontrado; atualização cancelada.')
text = text.replace(old_field, new_field, 1)

marker = """  List<Player> get _substitutes => _data.players.where((p) => p.selected && p.status == PlayerStatus.suplente).toList();
  List<Player> get _reserves => _data.players.where((p) => p.selected && p.status == PlayerStatus.reserva).toList();

"""
if marker not in text:
    raise SystemExit('Marcador de suplentes/reservas não encontrado.')
compact_field_method = """  Widget _compactField() {
    final size = MediaQuery.sizeOf(context);
    final desktop = size.width >= 980;
    final fittedWidth = ((size.height - 250) * 800 / 1100).clamp(360.0, 520.0).toDouble();
    final maxWidth = desktop ? fittedWidth : 520.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FootballField(
          players: _data.players,
          selectedCardId: _selectedCardId,
          onSelect: (id) => setState(() => _selectedCardId = id),
          onMove: _moveCard,
          onResize: _resizeCard,
          onFontChange: _fontCard,
          onInteractionStart: () => _setDragInteraction(true),
          onInteractionEnd: () => _setDragInteraction(false),
        ),
      ),
    );
  }

"""
text = text.replace(marker, marker + compact_field_method, 1)

start = text.find("  Widget _substitutesBar() {")
end = text.find("  Widget _tacticsWorkspace() {", start)
if start == -1 or end == -1:
    raise SystemExit('Bloco antigo de suplentes/reservas não encontrado.')
new_bench = """  Widget _benchBars() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _benchSection(
            title: 'Suplentes',
            icon: Icons.event_seat,
            color: _gold,
            players: _substitutes,
            canPromote: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _benchSection(
            title: 'Reservas',
            icon: Icons.inventory_2_outlined,
            color: _reserve,
            players: _reserves,
            canPromote: false,
          ),
        ),
      ],
    );
  }

  Widget _benchSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Player> players,
    required bool canPromote,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: _panel2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              Text('${players.length}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: players.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Sem jogadores', style: TextStyle(color: _muted, fontSize: 10)),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final player in players) ...[
                          _compactBenchCard(player, color, canPromote),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _compactBenchCard(Player player, Color color, bool canPromote) {
    return Container(
      width: canPromote ? 138 : 122,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF172238),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text(
              player.numero.isEmpty ? '—' : player.numero,
              style: TextStyle(
                color: color == _gold ? _bg : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                Text(player.principal.isEmpty ? '—' : player.principal, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 9)),
              ],
            ),
          ),
          if (canPromote)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 25, height: 25),
              tooltip: 'Colocar no campo',
              onPressed: () => _promoteSubstitute(player),
              icon: const Icon(Icons.arrow_upward, size: 15),
            ),
        ],
      ),
    );
  }

"""
text = text[:start] + new_bench + text[end:]

main_path.write_text(text, encoding='utf-8')

pubspec = pubspec_path.read_text(encoding='utf-8')
pubspec = pubspec.replace('version: 1.0.0+1', 'version: 1.0.1+2')
pubspec_path.write_text(pubspec, encoding='utf-8')

print('Layout compacto aplicado com sucesso.')
