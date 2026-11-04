import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GaugeRange {
  final double startValue;
  final double endValue;
  final Color color;

  /// Diz em palavras o que a cor indica ("ideal", "fora do ideal").
  final String? rotulo;

  const GaugeRange({
    required this.startValue,
    required this.endValue,
    required this.color,
    this.rotulo,
  });
}

class GaugeCard extends StatelessWidget {
  final String title;
  final double? value;
  final String unit;
  final double min;
  final double max;
  final List<GaugeRange> ranges;
  final IconData icon;
  final Color accentColor;
  final int precision;

  const GaugeCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.ranges,
    this.icon = Icons.sensors,
    this.accentColor = AeroColors.musgo,
    this.precision = 1,
  });

  double _percentValue() {
    if (value == null) return 0;

    final clampedValue = value!.clamp(min, max);
    return ((clampedValue - min) / (max - min)).clamp(0.0, 1.0);
  }

  Color _getPointerColor() {
    if (value == null) return AeroColors.tintaSuave;

    for (final range in ranges) {
      if (value! >= range.startValue && value! <= range.endValue) {
        return range.color;
      }
    }

    return accentColor;
  }

  String? _rotuloAtual() {
    if (value == null) return null;

    for (final range in ranges) {
      if (value! >= range.startValue && value! <= range.endValue) {
        return range.rotulo;
      }
    }

    return null;
  }

  List<double> _getStops() {
    final stops = <double>[];

    for (final range in ranges) {
      final start = ((range.startValue - min) / (max - min)).clamp(0.0, 1.0);
      final end = ((range.endValue - min) / (max - min)).clamp(0.0, 1.0);

      stops.add(start);
      stops.add(end);
    }

    return stops;
  }

  List<Color> _getColors() {
    final colors = <Color>[];

    for (final range in ranges) {
      // Fora do ideal fica claro na barra: o trilho não pode parecer um alarme
      // quando o valor está certo. O marcador é que mostra o estado atual.
      final cor = range.color == AeroColors.erro
          ? range.color.withValues(alpha: 0.3)
          : range.color;
      colors.add(cor);
      colors.add(cor);
    }

    return colors;
  }

  String _formattedValue() {
    if (value == null) return '--';
    final suffix = unit.isEmpty ? '' : ' $unit';
    return '${value!.toStringAsFixed(precision)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final percent = _percentValue();
    final pointerColor = _getPointerColor();

    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final compact = cardConstraints.maxWidth < 190;
        final padding = compact ? 12.0 : 16.0;
        final iconSize = compact ? 30.0 : 34.0;
        final titleFontSize = compact ? 13.0 : 14.0;
        final valueFontSize = compact ? 23.0 : 26.0;
        final headerGap = compact ? 12.0 : 18.0;
        final barGap = compact ? 14.0 : 20.0;
        final bottomGap = compact ? 8.0 : 12.0;

        return Container(
          decoration: BoxDecoration(
            color: AeroColors.areia,
            borderRadius: BorderRadius.circular(AeroRadius.card),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: AeroColors.creme,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: accentColor,
                        size: compact ? 16 : 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      // Reduz o título quando não cabe, em vez de cortar a palavra.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            color: AeroColors.tinta,
                            fontWeight: FontWeight.w700,
                            fontSize: titleFontSize,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: headerGap),

                Expanded(
                  child: value == null
                      ? Center(
                          child: Text(
                            _formattedValue(),
                            style: const TextStyle(
                              fontFamily: AeroFonts.titulo,
                              color: AeroColors.tintaSuave,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final barWidth = constraints.maxWidth;
                            const pointerWidth = 14.0;
                            final maxPointerLeft = (barWidth - pointerWidth)
                                .clamp(0.0, double.infinity);
                            final pointerLeft =
                                (barWidth * percent) - (pointerWidth / 2);

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _formattedValue(),
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontFamily: AeroFonts.titulo,
                                      color: AeroColors.tinta,
                                      fontSize: valueFontSize,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                SizedBox(height: barGap),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: _getColors(),
                                          stops: _getStops(),
                                        ),
                                      ),
                                    ),

                                    Positioned(
                                      left: pointerLeft.clamp(
                                        0,
                                        maxPointerLeft,
                                      ),
                                      top: -6,
                                      child: Container(
                                        width: pointerWidth,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: pointerColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AeroColors.creme,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: bottomGap),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      min.toStringAsFixed(0),
                                      style: const TextStyle(
                                        color: AeroColors.tintaSuave,
                                        fontSize: 12,
                                      ),
                                    ),
                                    // A cor sozinha não basta: o estado
                                    // também aparece escrito.
                                    if (_rotuloAtual() != null)
                                      Flexible(
                                        child: Text(
                                          _rotuloAtual()!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: pointerColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      max.toStringAsFixed(0),
                                      style: const TextStyle(
                                        color: AeroColors.tintaSuave,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
