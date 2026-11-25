// Testes unitários das partes do painel, cada uma sozinha na tela.
// Antes da refatoração estas partes eram métodos privados do
// dashboard_screen.dart e só dava para testá-las abrindo o painel inteiro.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/painel/barra_status.dart';
import 'package:hidro_app/screens/painel/cabecalho_painel.dart';
import 'package:hidro_app/screens/painel/componentes.dart';
import 'package:hidro_app/screens/painel/grade_sensores.dart';
import 'package:hidro_app/theme/app_theme.dart';

Future<void> _mostrar(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: w)),
  ));
}

void main() {
  group('formatarHora', () {
    test('com dois dígitos em cada parte', () {
      expect(formatarHora(DateTime(2026, 11, 21, 9, 5, 7)), '09:05:07');
    });
    test('sem leitura mostra traços', () => expect(formatarHora(null), '--:--:--'));
  });

  group('SituacaoPainel', () {
    SituacaoPainel de({bool erro = false, bool sumiu = false, bool conectado = false}) =>
        SituacaoPainel.de(erroDeConexao: erro, torreSumiu: sumiu, conectado: conectado);

    test('erro do servidor vem antes de tudo', () {
      expect(de(erro: true, sumiu: true, conectado: true), SituacaoPainel.offline);
    });
    test('servidor ok mas torre sem dados não é "Online"', () {
      expect(de(sumiu: true, conectado: true), SituacaoPainel.torreSemConexao);
    });
    test('conectado e conectando', () {
      expect(de(conectado: true).rotulo, 'Online');
      expect(de().rotulo, 'Conectando');
      expect(de().cor, AeroColors.alerta);
    });
  });

  group('BarraStatus', () {
    testWidgets('erro, buscando, tudo certo e silêncio quando há aviso', (tester) async {
      await _mostrar(tester, const BarraStatus(erroConexao: 'Sem resposta.', conectado: false, temAvisoAcima: false));
      expect(find.text('Sem resposta.'), findsOneWidget);

      await _mostrar(tester, const BarraStatus(erroConexao: null, conectado: false, temAvisoAcima: false));
      expect(find.text('Buscando dados do backend…'), findsOneWidget);

      await _mostrar(tester, const BarraStatus(erroConexao: null, conectado: true, temAvisoAcima: false));
      expect(find.text('Todos os sistemas operacionais'), findsOneWidget);

      await _mostrar(tester, const BarraStatus(erroConexao: null, conectado: true, temAvisoAcima: true));
      expect(find.text('Todos os sistemas operacionais'), findsNothing);
    });
  });

  group('CabecalhoPainel', () {
    testWidgets('mostra a situação, a hora e o intervalo', (tester) async {
      await _mostrar(tester, CabecalhoPainel(
        situacao: SituacaoPainel.torreSemConexao,
        ultimaAtualizacao: DateTime(2026, 11, 21, 14, 30, 0),
        intervalo: const Duration(seconds: 3),
      ));
      expect(find.text('Torre sem conexão'), findsOneWidget);
      expect(find.text('Atualizado às 14:30:00'), findsOneWidget);
      expect(find.text('Intervalo 3s'), findsOneWidget);
    });
  });

  group('GradeSensores', () {
    testWidgets('só os cartões do kit; sem sensores explica a rega', (tester) async {
      await _mostrar(tester, GradeSensores(tem: (c) => c == 'ph', ph: 6.1));
      expect(find.text('pH'), findsOneWidget);
      expect(find.text('TDS'), findsNothing);

      await _mostrar(tester, GradeSensores(tem: (_) => false));
      expect(find.textContaining('Sua torre rega sozinha'), findsOneWidget);
    });
  });
}
