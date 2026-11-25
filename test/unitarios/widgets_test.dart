// Testes unitários dos componentes visuais, cada um sozinho na tela.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/theme/app_theme.dart';
import 'package:hidro_app/widgets/aero_logo.dart';
import 'package:hidro_app/widgets/gauge_card.dart';
import 'package:hidro_app/widgets/nivel_agua_card.dart';

Future<void> _mostrar(WidgetTester tester, Widget w, {double largura = 300, double altura = 200,
    Size tela = const Size(800, 600)}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: Center(child: SizedBox(width: largura, height: altura, child: w))),
  ));
}

GaugeCard _ph(double? valor) => GaugeCard(
      title: 'pH',
      value: valor,
      unit: '',
      min: 0,
      max: 14,
      icon: Icons.water_drop_outlined,
      accentColor: AeroColors.agua,
      ranges: [
        GaugeRange(startValue: 0, endValue: 5.5, color: AeroColors.erro, rotulo: 'fora do ideal'),
        GaugeRange(startValue: 5.5, endValue: 6.5, color: AeroColors.musgo, rotulo: 'ideal'),
        GaugeRange(startValue: 6.5, endValue: 14, color: AeroColors.erro, rotulo: 'fora do ideal'),
      ],
    );

void main() {
  group('GaugeCard', () {
    testWidgets('valor dentro da faixa mostra o número e "ideal"', (tester) async {
      await _mostrar(tester, _ph(6.0));
      expect(find.text('6.0'), findsOneWidget);
      expect(find.text('ideal'), findsOneWidget);
    });

    testWidgets('valor fora da faixa', (tester) async {
      await _mostrar(tester, _ph(7.8));
      expect(find.text('fora do ideal'), findsOneWidget);
    });

    testWidgets('sem leitura mostra traços', (tester) async {
      await _mostrar(tester, _ph(null));
      expect(find.text('--'), findsWidgets);
    });

    testWidgets('valor acima do máximo fica preso no fim da barra; unidade aparece', (tester) async {
      await _mostrar(tester, GaugeCard(
        title: 'TDS', value: 5000, unit: 'ppm', min: 0, max: 2000,
        icon: Icons.science_outlined, accentColor: AeroColors.terracota,
        ranges: [GaugeRange(startValue: 0, endValue: 1000, color: AeroColors.musgo)],
      ));
      expect(find.textContaining('ppm'), findsOneWidget);
    });

    testWidgets('cartão estreito usa o layout compacto', (tester) async {
      await _mostrar(tester, _ph(5.0), largura: 160, altura: 190);
      expect(find.text('5.0'), findsOneWidget);
    });
  });

  group('NivelAguaCard', () {
    for (final caso in [
      (null, 'sem leitura'),
      (20.0, 'reabastecer'),
      (40.0, 'atenção'),
      (80.0, null),
    ]) {
      testWidgets('nível ${caso.$1}', (tester) async {
        await _mostrar(tester, NivelAguaCard(valor: caso.$1, minimoAlerta: 35), altura: 220);
        expect(find.text(caso.$1 == null ? '--' : '${caso.$1!.round()}%'), findsOneWidget);
        if (caso.$2 != null) expect(find.textContaining(caso.$2!), findsWidgets);
      });
    }

    testWidgets('em tela estreita esconde o detalhe', (tester) async {
      await _mostrar(tester, const NivelAguaCard(valor: 60, minimoAlerta: 35),
          largura: 200, altura: 220, tela: const Size(340, 600));
      expect(find.text('60%'), findsOneWidget);
    });
  });

  testWidgets('logo', (tester) async {
    await _mostrar(tester, const AeroLogo(tamanho: 64));
    expect(find.byType(AeroLogo), findsOneWidget);
  });
}
