import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Faixa vermelha com os alertas ativos da torre (vindos do Backend).
class FaixaAlertas extends StatelessWidget {
  final List<String> alertas;

  const FaixaAlertas({super.key, required this.alertas});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AeroColors.erroFundo,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da faixa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AeroColors.erro.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: AeroColors.erro,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${alertas.length} alerta${alertas.length > 1 ? 's' : ''} ativo${alertas.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AeroColors.erro,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Lista de alertas
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: alertas
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '›  ',
                            style: TextStyle(
                              color: AeroColors.erro,
                              fontSize: 14,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              a,
                              style: const TextStyle(
                                color: AeroColors.tinta,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
