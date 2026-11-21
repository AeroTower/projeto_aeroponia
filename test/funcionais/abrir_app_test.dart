import 'package:flutter_test/flutter_test.dart';

import 'package:hidro_app/main.dart';

void main() {
  testWidgets('o app abre na tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('AeroTower'), findsOneWidget);
    expect(find.text('Continuar com o Google'), findsOneWidget);
  });
}
