// Testes funcionais do HydroBot (IA).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/chat_bot.dart';

import '../apoio.dart';

ChatbotScreen _chat({String? torreId = idTorre}) =>
    ChatbotScreen(torreId: torreId, phAtual: 7.4, tempAtual: 22.5, umidadeAtual: 60);

void main() {
  setUp(logar);

  testWidgets('pede orientação para a planta escolhida e mostra a resposta', (tester) async {
    final servidor = servidorComTorre()
      ..quando('POST /analisar-cultivo', {'status_sistema': 'Alerta', 'sugestoes_acao': ['Baixe o pH para 6,0']});
    await servidor.rodar(() async {
      await montar(tester, _chat());
      expect(find.textContaining('HydroBot'), findsWidgets);
      await tester.tap(find.text('Alface'));                 // troca a planta no menu
      await assentar(tester);
      await tester.tap(find.text('Manjericão').last);
      await assentar(tester);
      await tester.tap(find.text('Gerar orientação'));
      await assentar(tester);
    });
    final pedido = jsonDecode(servidor.para('POST /analisar-cultivo').single.body);
    expect(pedido, {'cultura': 'Manjericão', 'ph': 7.4, 'temperatura': 22.5, 'umidade': 60});
    expect(find.textContaining('Baixe o pH para 6,0', findRichText: true), findsOneWidget);
    expect(find.textContaining('pH: 7.4', findRichText: true), findsOneWidget);
  });

  testWidgets('erro da IA e IA fora do ar', (tester) async {
    final servidor = servidorComTorre()
      ..quando('POST /analisar-cultivo', {'detail': 'O serviço de IA não retornou dados processáveis.'}, status: 500);
    await servidor.rodar(() async {
      await montar(tester, _chat());
      await tester.tap(find.text('Gerar orientação'));
      await assentar(tester);
      expect(find.textContaining('Erro da IA', findRichText: true), findsOneWidget);
      servidor.caiu('POST /analisar-cultivo');
      await tester.tap(find.text('Gerar orientação'));
      await assentar(tester);
    });
    expect(find.textContaining('Falha ao conectar', findRichText: true), findsOneWidget);
  });

  testWidgets('sem planta cadastrada não chama a IA', (tester) async {
    final servidor = ServidorFalso()..quando('GET /torres/$idTorre/plantas', []);
    await servidor.rodar(() async {
      await montar(tester, _chat());
      expect(find.text('Nenhuma planta cadastrada na torre.'), findsOneWidget);
      await tester.tap(find.text('Gerar orientação'));
      await assentar(tester);
    });
    expect(find.textContaining('Selecione uma planta primeiro', findRichText: true), findsOneWidget);
    expect(servidor.para('POST /analisar-cultivo'), isEmpty);
  });

  testWidgets('plantas fora do ar e modo sem torre', (tester) async {
    final servidor = ServidorFalso()..caiu('GET /torres/$idTorre/plantas');
    await servidor.rodar(() => montar(tester, _chat()));
    expect(find.text('Nenhuma planta cadastrada na torre.'), findsOneWidget);

    await servidor.rodar(() => montar(tester, _chat(torreId: null)));
    expect(find.text('Nenhuma planta cadastrada na torre.'), findsOneWidget);
  });

  testWidgets('limpar a conversa e voltar', (tester) async {
    final servidor = servidorComTorre()..quando('POST /analisar-cultivo', {'diagnostico_breve': 'Tudo certo.'});
    await servidor.rodar(() async {
      await montar(tester, _chat());
      await tester.tap(find.text('Gerar orientação'));
      await assentar(tester);
      expect(find.textContaining('Tudo certo.', findRichText: true), findsOneWidget);
      await tester.tap(find.byTooltip('Limpar conversa'));
      await assentar(tester);
      expect(find.textContaining('Tudo certo.', findRichText: true), findsNothing);
    });
  });
}
