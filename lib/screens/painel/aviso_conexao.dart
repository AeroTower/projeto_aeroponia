import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Aviso de que o servidor nao respondeu, com botao para tentar de novo.
class AvisoConexao extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentarDeNovo;

  const AvisoConexao({super.key, required this.mensagem, required this.onTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AeroColors.alertaFundo,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AeroColors.alerta,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(color: AeroColors.alerta, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onTentarDeNovo,
            style: TextButton.styleFrom(
              foregroundColor: AeroColors.alerta,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Tentar novamente',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
