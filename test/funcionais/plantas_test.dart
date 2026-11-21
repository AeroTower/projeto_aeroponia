// Testes funcionais da tela de plantas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/plants_screen.dart';

import '../apoio.dart';

void main() {
  setUp(logar);

  testWidgets('lista as plantas da torre, com e sem foto', (tester) async {
    final servidor = servidorComTorre()
      ..quando('GET /torres/$idTorre/plantas',
          [plantaJson(1, 'Alface', foto: '/static/fotos/alface.jpg'), plantaJson(2, 'Manjericão')]);
    await servidor.rodar(() => montar(tester, const PlantsScreen(torreId: idTorre, torreNome: 'Varanda')));
    expect(find.text('Alface'), findsOneWidget);
    expect(find.text('Manjericão'), findsOneWidget);
    expect(find.text('2 plantas'), findsOneWidget);
    expect(find.text('AeroTower · Varanda'), findsOneWidget);
  });

  testWidgets('sem plantas mostra o convite para adicionar', (tester) async {
    final servidor = ServidorFalso()..quando('GET /torres/$idTorre/plantas', []);
    await servidor.rodar(() => montar(tester, const PlantsScreen(torreId: idTorre)));
    expect(find.text('Nenhuma planta cadastrada'), findsOneWidget);
    expect(find.text('AeroTower · Minha torre'), findsOneWidget);
  });

  testWidgets('erro ao carregar e tentar de novo', (tester) async {
    final servidor = ServidorFalso()..quando('GET /torres/$idTorre/plantas', {'detail': 'x'}, status: 500);
    await servidor.rodar(() async {
      await montar(tester, const PlantsScreen(torreId: idTorre));
      expect(find.text('Erro ao carregar plantas'), findsOneWidget);
      servidor.quando('GET /torres/$idTorre/plantas', [plantaJson(1, 'Alface')]);
      await tester.tap(find.text('Tentar novamente'));
      await assentar(tester);
      await tester.tap(find.byIcon(Icons.refresh));
      await assentar(tester);
    });
    expect(find.text('Alface'), findsOneWidget);
  });

  testWidgets('adicionar planta com foto, tipo e data', (tester) async {
    usarGaleriaFalsa();
    final servidor = ServidorFalso()
      ..quando('GET /torres/$idTorre/plantas', [])
      ..quando('POST /torres/$idTorre/plantas', plantaJson(7, 'Rúcula'), status: 201);
    await servidor.rodar(() async {
      await montar(tester, const PlantsScreen(torreId: idTorre));
      await tester.tap(find.text('Adicionar planta'));
      await assentar(tester);

      await tester.tap(find.text('Salvar planta'));          // nada preenchido
      await tester.pump();
      expect(find.text('Preencha todos os campos obrigatórios'), findsOneWidget);

      await tester.tap(find.text('Adicionar foto (opcional)'));
      await assentar(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Nome da planta'), 'Rúcula');
      await tester.tap(find.text('Selecione o tipo'));
      await assentar(tester);
      await tester.tap(find.text('Folhosa').last);
      await assentar(tester);
      await tester.tap(find.widgetWithText(TextFormField, 'Data de plantio'));
      await assentar(tester);
      await tester.tap(find.text('OK'));
      await assentar(tester);

      servidor.quando('GET /torres/$idTorre/plantas', [plantaJson(7, 'Rúcula')]);
      await tester.tap(find.text('Salvar planta'));
      await assentar(tester);
    });
    final envio = servidor.para('POST /torres/$idTorre/plantas').single;
    expect(envio.body, contains('Rúcula'));
    expect(envio.body, contains('Folhosa'));
    expect(envio.body, contains('filename="alface.png"'));
    expect(RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(envio.body), isTrue);
    expect(find.text('Rúcula'), findsOneWidget);
  });

  testWidgets('erro ao salvar fica no formulário', (tester) async {
    final galeria = usarGaleriaFalsa()..foto = null;      // pessoa fechou a galeria
    final servidor = ServidorFalso()
      ..quando('GET /torres/$idTorre/plantas', [])
      ..quando('POST /torres/$idTorre/plantas', {'detail': 'x'}, status: 400);
    await servidor.rodar(() async {
      await montar(tester, const PlantsScreen(torreId: idTorre));
      await tester.tap(find.text('Adicionar planta'));
      await assentar(tester);
      await tester.tap(find.text('Adicionar foto (opcional)'));
      await assentar(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Nome da planta'), 'X');
      await tester.tap(find.text('Selecione o tipo'));
      await assentar(tester);
      await tester.tap(find.text('Outro').last);
      await assentar(tester);
      await tester.tap(find.widgetWithText(TextFormField, 'Data de plantio'));
      await assentar(tester);
      await tester.tap(find.text('Cancel'));                // fechou o calendário
      await assentar(tester);
      await tester.tap(find.widgetWithText(TextFormField, 'Data de plantio'));
      await assentar(tester);
      await tester.tap(find.text('OK'));
      await assentar(tester);
      await tester.tap(find.text('Salvar planta'));
      await assentar(tester);
    });
    expect(galeria.foto, isNull);
    expect(find.text('Erro ao salvar planta'), findsOneWidget);
  });

  testWidgets('remover planta: cancelar, confirmar e erro', (tester) async {
    final servidor = servidorComTorre()
      ..quando('DELETE /torres/$idTorre/plantas/1', {'sucesso': true})
      ..quando('DELETE /torres/$idTorre/plantas/2', {'detail': 'x'}, status: 404);
    await servidor.rodar(() async {
      await montar(tester, const PlantsScreen(torreId: idTorre));
      final lixeiras = find.byIcon(Icons.delete_outline);

      await tester.tap(lixeiras.first);
      await assentar(tester);
      await tester.tap(find.text('Cancelar'));
      await assentar(tester);
      expect(servidor.para('DELETE /torres/$idTorre/plantas/1'), isEmpty);

      await tester.tap(lixeiras.first);
      await assentar(tester);
      expect(find.text('Deseja remover "Alface"?'), findsOneWidget);
      await tester.tap(find.text('Remover'));
      await assentar(tester);
      expect(find.text('Alface removida!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      await tester.tap(lixeiras.last);
      await assentar(tester);
      await tester.tap(find.text('Remover'));
      await assentar(tester);
    });
    expect(servidor.para('DELETE /torres/$idTorre/plantas/1'), hasLength(1));
    expect(find.text('Erro ao remover planta'), findsOneWidget);
  });
}
