from pathlib import Path

main_path = Path('flutter_app/lib/main.dart')
pubspec_path = Path('flutter_app/pubspec.yaml')
text = main_path.read_text(encoding='utf-8')

# Mobile plantel panel: avoid a huge empty panel when there are no/few players.
old_mobile = """    return ListView(
      physics: _dragInteractionActive ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(9),
      children: [
        SizedBox(height: 620, child: _leftPanel()),
        const SizedBox(height: 10),
        _fieldPanel(),
      ],
    );
"""
new_mobile = """    final mobilePanelHeight = _data.players.isEmpty
        ? 330.0
        : (_data.players.length <= 3 ? 410.0 : 520.0);
    return ListView(
      physics: _dragInteractionActive ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(9),
      children: [
        SizedBox(height: mobilePanelHeight, child: _leftPanel()),
        const SizedBox(height: 8),
        _fieldPanel(),
      ],
    );
"""
if old_mobile not in text:
    raise SystemExit('Mobile workspace block not found')
text = text.replace(old_mobile, new_mobile, 1)

# Tighten vertical rhythm around the form.
text = text.replace("            const SizedBox(height: 12),\n            _form(),\n            const SizedBox(height: 10),", "            const SizedBox(height: 8),\n            _form(),\n            const SizedBox(height: 6),", 1)

# Replace the complete form with a responsive compact version.
start = text.find("  Widget _form() {")
end = text.find("\n  Widget _playerRow(Player player, int index) {", start)
if start == -1 or end == -1:
    raise SystemExit('Form block not found')

new_form = r'''  Widget _form() {
    final compact = MediaQuery.sizeOf(context).width < 600;

    Widget field(
      TextEditingController controller,
      String hint, {
      required double mobileWidth,
      required double desktopWidth,
    }) {
      return SizedBox(
        width: compact ? mobileWidth : desktopWidth,
        height: compact ? 38 : 42,
        child: TextField(
          controller: controller,
          style: TextStyle(fontSize: compact ? 13 : 14),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 11,
              vertical: compact ? 8 : 9,
            ),
          ),
          onSubmitted: (_) => _addPlayer(),
        ),
      );
    }

    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        field(_nome, 'Nome do jogador', mobileWidth: 150, desktopWidth: 180),
        field(_ano, 'Ano', mobileWidth: 72, desktopWidth: 90),
        field(_numero, 'N.º', mobileWidth: 58, desktopWidth: 74),
        field(_principal, 'Posição principal', mobileWidth: 120, desktopWidth: 140),
        field(_secundaria, 'Posição secundária', mobileWidth: 126, desktopWidth: 145),
        SizedBox(
          height: compact ? 38 : 42,
          child: FilledButton.icon(
            onPressed: _addPlayer,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 15),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(Icons.person_add_alt_1, size: compact ? 15 : 17),
            label: Text('Adicionar', style: TextStyle(fontSize: compact ? 13 : 14)),
          ),
        ),
      ],
    );
  }
'''
text = text[:start] + new_form + text[end:]
main_path.write_text(text, encoding='utf-8')

pubspec = pubspec_path.read_text(encoding='utf-8')
if 'version: 1.0.3+4' not in pubspec:
    raise SystemExit('Unexpected version in pubspec.yaml')
pubspec = pubspec.replace('version: 1.0.3+4', 'version: 1.0.4+5', 1)
pubspec_path.write_text(pubspec, encoding='utf-8')

print('COMPACT_MOBILE_FORM_OK')
