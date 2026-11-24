// CT-INT-03 (teste individual) — Integração app → microsserviço de IA.
//
// Interface testada: tela do HydroBot → BackendService.analisarCultivoIA →
// POST /analisar-cultivo da IA. O contrato da IA pede a "cultura" (espécie:
// Alface, Manjericão...) e aceita no máximo 100 caracteres.
// Obtido em 24/11/2026 (antes da correção): o app manda o APELIDO que o dono deu à planta ("Minha
// favorita") no lugar da espécie (campo `tipo`), e não limita o tamanho, que
// o Backend também não limita. 
// Corrigido na refatoração: saiu da tag "defeito" e roda na suíte normal,
// protegendo contra a volta do defeito.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/chat_bot.dart';
import 'package:http/http.dart' as http;

import '../apoio.dart';

Map<String, dynamic> _planta(String nome, String tipo) =>
    {'id': 1, 'nome': nome, 'tipo': tipo, 'data_plantio': '2026-11-01', 'foto_url': null};

/// IA falsa com a mesma regra da IA publicada: cultura de 1 a 100 caracteres.
http.Response _iaComContrato(http.Request pedido) {
  final cultura = (jsonDecode(pedido.body) as Map)['cultura'] as String;
  if (cultura.length > 100) {
    return resposta({
      'detail': [
        {'type': 'string_too_long', 'loc': ['body', 'cultura'],
         'msg': 'String should have at most 100 characters', 'ctx': {'max_length': 100}},
      ],
    }, status: 422);
  }
  return resposta({'status_sistema': 'Normal', 'diagnostico_breve': 'Condições adequadas para $cultura.'});
}

ChatbotScreen _chat() =>
    const ChatbotScreen(torreId: idTorre, phAtual: 6.0, tempAtual: 22.0, umidadeAtual: 65.0);

void main() {
  setUp(logar);

  testWidgets('a IA recebe a espécie da planta (tipo), não o apelido dado pelo dono', (tester) async {
    final servidor = servidorComTorre()
      ..quando('GET /torres/$idTorre/plantas', [_planta('Minha favorita', 'Alface')])
      ..quandoFn('POST /analisar-cultivo', _iaComContrato);
    await servidor.rodar(() async {
      await montar(tester, _chat());
      await tester.tap(find.text('Gerar orientação'));
      await assentar(tester);
    });
    final cultura = (jsonDecode(servidor.para('POST /analisar-cultivo').single.body) as Map)['cultura'];
    expect(cultura, 'Alface', reason: 'a IA recebeu "$cultura" como cultura');
  });

  testWidgets('apelido comprido (mais de 100 letras) não impede a análise', (tester) async {
    final apelido = 'Alface crespa da varanda que a vó plantou no inverno ' * 2;   // 106 caracteres
    final servidor = servidorComTorre()
      ..quando('GET /torres/$idTorre/plantas', [_planta(apelido, 'Alface')])
      ..quandoFn('POST /analisar-cultivo', _iaComContrato);
    await servidor.rodar(() async {
      // Tela larga: o menu de plantas mostra o apelido inteiro sem estourar.
      await montar(tester, _chat(), tamanho: const Size(2400, 2000));
      await tester.tap(find.text('Gerar orientação'));
      await assentar(tester);
    });
    expect(find.textContaining('Erro da IA', findRichText: true), findsNothing,
        reason: 'a IA recusou o pedido (422: cultura com mais de 100 caracteres)');
    expect(find.textContaining('Condições adequadas', findRichText: true), findsOneWidget);
  });
}
