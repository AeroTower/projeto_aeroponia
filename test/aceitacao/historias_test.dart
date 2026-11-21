// Testes de aceitação: os critérios de aceite das histórias de usuário do
// app, escritos no formato BDD (Dado / Quando / Então) e executados na tela.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/dashboard_screen.dart';

import '../apoio.dart';

void main() {
  setUp(logar);

  group('História: acompanhar a torre pelo celular', () {
    testWidgets(
        'Dado uma torre Pro com o reservatório em 20%, '
        'Quando abro o painel, '
        'Então vejo o alerta de nível baixo e a ampola pedindo para reabastecer', (tester) async {
      final servidor = servidorComTorre(alertas: ['Nível de água baixo: 20%'])
        ..quando('GET /torres/$idTorre/dados',
            dadosJson(dados: {'ph': 6.0, 'nivelAgua': 20}, alertas: ['Nível de água baixo: 20%']));
      await servidor.rodar(() => montar(tester, DashboardScreen(torre: torre())));
      expect(find.text('1 alerta ativo'), findsOneWidget);
      expect(find.textContaining('Nível de água baixo'), findsOneWidget);
      expect(find.text('reabastecer'), findsOneWidget);
      await desmontar(tester);
    });

    testWidgets(
        'Dado uma torre do kit Básico, '
        'Quando abro o painel, '
        'Então não aparecem sensores que o kit não tem', (tester) async {
      await servidorComTorre(kit: 'basico').rodar(() => montar(tester, DashboardScreen(torre: torre(kit: 'basico'))));
      for (final sensor in ['pH', 'TDS', 'Temperatura', 'Nível da água']) {
        expect(find.text(sensor), findsNothing, reason: sensor);
      }
      expect(find.text('Controle da bomba'), findsOneWidget);
      await desmontar(tester);
    });
  });

  group('História: programar a rega pelo app', () {
    testWidgets(
        'Dado o painel da minha torre aberto, '
        'Quando peço 20 minutos ligada e 40 desligada, '
        'Então a torre recebe o ciclo e o app confirma', (tester) async {
      final servidor = servidorComTorre();
      await servidor.rodar(() async {
        await montar(tester, DashboardScreen(torre: torre()));
        await tester.enterText(find.byType(TextField).at(0), '20');
        await tester.enterText(find.byType(TextField).at(1), '40');
        await tester.tap(find.text('Iniciar ciclo'));
        await assentar(tester);
      });
      expect(jsonDecode(servidor.para('POST /torres/$idTorre/motor/ciclo').single.body),
          {'minutos_ligado': 20, 'minutos_desligado': 40});
      expect(find.textContaining('Ciclo iniciado: 20 min ligado / 40 min desligado'), findsOneWidget);
      await desmontar(tester);
    });
  });

  group('História: torre nova sem internet', () {
    testWidgets(
        'Dado uma torre que nunca mandou leitura, '
        'Quando abro o painel, '
        'Então vejo como conectar a torre ao Wi-Fi, com o nome da rede dela', (tester) async {
      final servidor = servidorComTorre()
        ..quando('GET /torres/$idTorre/dados', {'detail': 'Nenhum dado recebido ainda.'}, status: 503);
      await servidor.rodar(
          () => montar(tester, DashboardScreen(torre: torre(online: null, ultimaLeituraEm: null))));
      expect(find.text('Conecte sua torre ao Wi-Fi'), findsOneWidget);
      expect(find.textContaining('"AeroTower-B2C4"'), findsOneWidget);
      expect(find.textContaining('192.168.4.1'), findsOneWidget);
      await desmontar(tester);
    });
  });
}
