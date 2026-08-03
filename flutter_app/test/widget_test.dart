import 'package:flutter_test/flutter_test.dart';
import 'package:plantel_futebol7/main.dart';

void main() {
  testWidgets('Plantel app starts', (tester) async {
    await tester.pumpWidget(const PlantelApp());
    expect(find.text('Gestor de Plantel — Futebol de 7'), findsOneWidget);
  });
}
