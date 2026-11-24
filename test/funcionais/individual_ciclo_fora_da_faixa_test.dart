// CT-FUNC-03 (teste individual) — Ciclo da bomba fora da faixa, pela tela.
//
// Cenário: o dono digita 2000 minutos ligada (o limite do Backend é 1440,
// um dia). O app só confere se o número é maior que zero e manda o pedido;
// o Backend devolve 422 com a lista de erros do FastAPI.
// Esperado: o app explica o limite em português ("de 1 a 1440 minutos") e
// nem chega a mandar o comando.
// Obtido hoje: a tela mostra o erro técnico cru, em inglês:
// [{type: less_than_equal, loc: [body, minutos_ligado], msg: Input should be ...}]
@Tags(['defeito'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/dashboard_screen.dart';

import '../apoio.dart';

/// Corpo exato que o Backend publicado devolve para 2000 minutos.
const _erro422DoBackend = {
  'detail': [
    {
      'type': 'less_than_equal',
      'loc': ['body', 'minutos_ligado'],
      'msg': 'Input should be less than or equal to 1440',
      'input': 2000,
      'ctx': {'le': 1440},
    },
  ],
};

void main() {
  setUp(logar);

  testWidgets('2000 minutos: o app explica o limite em português, sem erro técnico', (tester) async {
    final servidor = servidorComTorre()
      ..quando('POST /torres/$idTorre/motor/ciclo', _erro422DoBackend, status: 422);
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre()));
      await tester.enterText(find.byType(TextField).at(0), '2000');
      await tester.enterText(find.byType(TextField).at(1), '30');
      await tester.tap(find.text('Iniciar ciclo'));
      await assentar(tester);
    });
    final erroTecnico = find.textContaining('Input should be').evaluate().isNotEmpty ||
        find.textContaining('less_than_equal').evaluate().isNotEmpty;
    final pedidos = servidor.para('POST /torres/$idTorre/motor/ciclo').length;
    final explicou = find.textContaining('1440').evaluate().isNotEmpty;
    await desmontar(tester);

    expect(erroTecnico, isFalse, reason: 'a tela mostrou o erro técnico do FastAPI, em inglês');
    expect(pedidos, 0, reason: 'o app mandou um ciclo que o Backend não aceita');
    expect(explicou, isTrue, reason: 'faltou dizer que o limite é 1440 minutos');
  });
}
