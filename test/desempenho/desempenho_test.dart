// Testes de desempenho do app. Limites folgados (cerca de 10x o medido no
// GitHub Actions): falham só se algo ficar muito mais lento.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/models/backend_models.dart';
import 'package:hidro_app/screens/dashboard_screen.dart';
import 'package:hidro_app/screens/plants_screen.dart';

import '../apoio.dart';

void main() {
  test('volume: 50.000 leituras convertidas em menos de 2 s', () {
    final json = dadosJson();
    final relogio = Stopwatch()..start();
    for (var i = 0; i < 50000; i++) {
      SensorSnapshot.fromJson(json);
    }
    expect(relogio.elapsedMilliseconds, lessThan(2000));
  });

  testWidgets('resistência: painel atualizando a cada 3 s por 5 minutos', (tester) async {
    logar();
    final servidor = servidorComTorre();
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre()));
      final relogio = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(seconds: 3));
      }
      expect(relogio.elapsed.inSeconds, lessThan(30));
    });
    // 100 ciclos de 3 s = 5 minutos de painel aberto, sem erro e sem acumular pedidos.
    expect(servidor.para('GET /torres/$idTorre/dados').length, inInclusiveRange(100, 102));
    await desmontar(tester);
  });

  testWidgets('volume: horta com 200 plantas abre em menos de 3 s', (tester) async {
    logar();
    final servidor = ServidorFalso()
      ..quando('GET /torres/$idTorre/plantas', [for (var i = 0; i < 200; i++) plantaJson(i, 'Planta $i')]);
    final relogio = Stopwatch()..start();
    await servidor.rodar(() => montar(tester, const PlantsScreen(torreId: idTorre)));
    expect(relogio.elapsedMilliseconds, lessThan(3000));
    expect(find.text('200 plantas'), findsOneWidget);
  });
}
