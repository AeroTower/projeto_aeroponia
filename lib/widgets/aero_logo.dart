import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A gota terracota em círculo claro, igual ao cabeçalho da página inicial.
class AeroLogo extends StatelessWidget {
  final double tamanho;

  const AeroLogo({super.key, this.tamanho = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: const BoxDecoration(
        color: AeroColors.terracotaClara,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.water_drop_outlined,
        color: AeroColors.terracotaEscuro,
        size: tamanho * 0.55,
      ),
    );
  }
}
