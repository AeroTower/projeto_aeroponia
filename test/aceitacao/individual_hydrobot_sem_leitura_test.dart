// CT-ACEIT-03 (teste individual) — História: pedir orientação ao HydroBot.
//
// Critério de aceite em BDD (Dado / Quando / Então), executado na tela.
// Obtido hoje: a tela mostra "pH: NULO", mas o app manda para a IA pH 7,5,
// 28,5 °C e 45% de umidade, valores que a torre nunca mediu. A resposta da
// IA fala de uma água que não existe.
@Tags(['defeito'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/chat_bot.dart';

import '../apoio.dart';

void main() {
  setUp(logar);

  group('História: pedir orientação ao HydroBot', () {
    testWidgets(
        'Dado que a torre ainda não mandou leitura de pH, temperatura e umidade, '
        'Quando peço uma orientação ao HydroBot, '
        'Então ele avisa que falta leitura e não manda valores inventados para a IA', (tester) async {
      final servidor = servidorComTorre()
        ..quando('POST /analisar-cultivo', {'status_sistema': 'Alerta', 'sugestoes_acao': ['Baixe o pH']});
      await servidor.rodar(() async {
        await montar(tester, const ChatbotScreen(torreId: idTorre));   // sem leitura
        await tester.tap(find.text('Gerar orientação'));
        await assentar(tester);
      });
      final pedidos = servidor.para('POST /analisar-cultivo');
      final enviado = pedidos.isEmpty ? null : jsonDecode(pedidos.single.body);
      expect(enviado, isNull, reason: 'a IA recebeu valores que a torre não mediu: $enviado');
      expect(find.textContaining('leitura', findRichText: true), findsWidgets);
    });
  });
}
