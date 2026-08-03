from pathlib import Path

path = Path('flutter_app/lib/field_widget.dart')
text = path.read_text(encoding='utf-8')
old = '''                      ..onEnd = (_) => onInteractionEnd()\n                      ..onCancel = onInteractionEnd;'''
new = '''                      ..onEnd = (_) {\n                        onInteractionEnd();\n                      }\n                      ..onCancel = () {\n                        onInteractionEnd();\n                      };'''
if old not in text and new not in text:
    raise RuntimeError('Android drag callback block not found')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
