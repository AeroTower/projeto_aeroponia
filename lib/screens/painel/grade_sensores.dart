import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/gauge_card.dart';
import '../../widgets/nivel_agua_card.dart';

/// Cartoes dos sensores, so os que o kit da torre tem.
class GradeSensores extends StatelessWidget {
  /// O kit tem esta capacidade? ('ph', 'tds', 'clima', 'nivel')
  final bool Function(String capacidade) tem;
  final double? ph;
  final double? tds;
  final double? temperatura;
  final double? nivelAgua;

  const GradeSensores({
    super.key,
    required this.tem,
    this.ph,
    this.tds,
    this.temperatura,
    this.nivelAgua,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final crossAxisCount = compact
            ? 2
            : (constraints.maxWidth / 260).floor().clamp(2, 4);
        // Altura fixa, e não proporção: com proporção, o card ficava baixo
        // demais em certas larguras e o conteúdo estourava. Acompanha o
        // tamanho de fonte escolhido no aparelho.
        final alturaCard = MediaQuery.textScalerOf(context).scale(176);
        final cards = _cards();
        if (cards.isEmpty) return const _SemSensores();
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: alturaCard,
          ),
          children: cards,
        );
      },
    );
  }

  /// Só os cards dos sensores que o kit tem.
  List<Widget> _cards() {
    return [
      if (tem('ph'))
        GaugeCard(
          title: "pH",
          value: ph,
          unit: "",
          min: 0,
          max: 14,
          icon: Icons.water_drop_outlined,
          accentColor: AeroColors.agua,
          ranges: [
            GaugeRange(
              startValue: 0,
              endValue: 5.5,
              color: AeroColors.erro,
              rotulo: 'fora do ideal',
            ),
            GaugeRange(
              startValue: 5.5,
              endValue: 6.5,
              color: AeroColors.musgo,
              rotulo: 'ideal',
            ),
            GaugeRange(
              startValue: 6.5,
              endValue: 14,
              color: AeroColors.erro,
              rotulo: 'fora do ideal',
            ),
          ],
        ),
      if (tem('tds'))
        GaugeCard(
          title: "TDS",
          value: tds,
          unit: "ppm",
          min: 0,
          max: 2000,
          icon: Icons.science_outlined,
          accentColor: AeroColors.terracotaEscuro,
          ranges: [
            GaugeRange(
              startValue: 0,
              endValue: 560,
              color: AeroColors.erro,
              rotulo: 'fora do ideal',
            ),
            GaugeRange(
              startValue: 560,
              endValue: 1260,
              color: AeroColors.musgo,
              rotulo: 'ideal',
            ),
            GaugeRange(
              startValue: 1260,
              endValue: 2000,
              color: AeroColors.erro,
              rotulo: 'fora do ideal',
            ),
          ],
        ),
      if (tem('clima'))
        GaugeCard(
          title: "Temperatura",
          value: temperatura,
          unit: "°C",
          min: 10,
          max: 35,
          icon: Icons.thermostat_rounded,
          accentColor: AeroColors.terracota,
          ranges: [
            GaugeRange(
              startValue: 10,
              endValue: 20,
              color: AeroColors.erro,
              rotulo: 'fora do ideal',
            ),
            GaugeRange(
              startValue: 20,
              endValue: 28,
              color: AeroColors.musgo,
              rotulo: 'ideal',
            ),
            GaugeRange(
              startValue: 28,
              endValue: 35,
              color: AeroColors.erro,
              rotulo: 'fora do ideal',
            ),
          ],
        ),
      // Nivel de tanque nao e grandeza que oscila em torno de um
      // ideal como pH ou temperatura: o que importa e quanto ainda
      // resta. A ampola mostra isso de imediato; o medidor circular
      // obrigava a interpretar um ponteiro.
      if (tem('nivel')) NivelAguaCard(valor: nivelAgua, minimoAlerta: 35),
    ];
  }
}

/// Kit Básico: não há sensores, só a rega automática.
class _SemSensores extends StatelessWidget {
  const _SemSensores();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AeroColors.areia,
        borderRadius: BorderRadius.circular(AeroRadius.card),
      ),
      child: const Row(
        children: [
          Icon(Icons.water_rounded, color: AeroColors.musgo, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Sua torre rega sozinha no ciclo abaixo. '
              'Sensor de nível (Kit Completo) e pH, nutrientes e clima '
              '(Kit Pro) podem ser adicionados depois.',
              style: TextStyle(
                color: AeroColors.tintaSuave,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
