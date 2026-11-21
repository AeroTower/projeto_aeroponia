// Testes funcionais da tela "Minhas torres".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/dashboard_screen.dart';
import 'package:hidro_app/screens/login_screen.dart';
import 'package:hidro_app/screens/torres_screen.dart';
import 'package:hidro_app/screens/vincular_torre_screen.dart';
import 'package:hidro_app/services/sessao.dart';

import '../apoio.dart';

void main() {
  setUp(logar);

  testWidgets('com duas torres mostra a lista e abre a escolhida', (tester) async {
    final servidor = servidorComTorre()
      ..quando('GET /torres', [
        torreJson(),
        torreJson(id: 'AT-OUTRA0001', apelido: null, kit: 'basico', online: false),
      ]);
    await servidor.rodar(() async {
      await montar(tester, const TorresScreen());
      expect(find.text('Varanda'), findsOneWidget);
      expect(find.text('Kit Pro · online'), findsOneWidget);
      expect(find.text('Kit Básico · offline'), findsOneWidget);
      await tester.tap(find.text('Varanda'));
      await assentar(tester);
    });
    expect(find.byType(DashboardScreen), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('sem torre vai para o vínculo', (tester) async {
    await (ServidorFalso()..quando('GET /torres', [])).rodar(() => montar(tester, const TorresScreen()));
    expect(find.byType(VincularTorreScreen), findsOneWidget);
  });

  testWidgets('erro do Backend e rede fora deixam tentar de novo', (tester) async {
    final servidor = ServidorFalso()..quando('GET /torres', {'detail': 'Backend em manutenção'}, status: 500);
    await servidor.rodar(() async {
      await montar(tester, const TorresScreen());
      expect(find.text('Backend em manutenção'), findsOneWidget);
      servidor.caiu('GET /torres');
      await tester.tap(find.text('Tentar de novo'));
      await assentar(tester);
    });
    expect(find.text('Sem resposta do servidor.'), findsOneWidget);
  });

  testWidgets('sessão expirada (401) volta ao login', (tester) async {
    await (ServidorFalso()..quando('GET /torres', {'detail': 'Sessão expirada.'}, status: 401))
        .rodar(() => montar(tester, const TorresScreen()));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(Sessao.instance.logado, isFalse);
  });

  testWidgets('botão sair', (tester) async {
    final servidor = servidorComTorre()
      ..quando('GET /torres', [torreJson(), torreJson(id: 'AT-OUTRA0001')]);
    await servidor.rodar(() async {
      await montar(tester, const TorresScreen());
      await tester.tap(find.byTooltip('Sair'));
      await assentar(tester);
    });
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a seta do painel volta para a lista', (tester) async {
    final servidor = servidorComTorre();
    await servidor.rodar(() async {
      await montar(tester, const TorresScreen());
      await tester.tap(find.byTooltip('Minhas torres'));
      await assentar(tester);
    });
    expect(find.byType(DashboardScreen), findsNothing);
    expect(find.text('Minhas torres'), findsOneWidget);
    expect(find.byIcon(Icons.water_drop), findsOneWidget);
  });
}
