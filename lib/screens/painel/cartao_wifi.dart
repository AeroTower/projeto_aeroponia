import 'package:flutter/material.dart';

import '../../models/torre.dart';
import '../../theme/app_theme.dart';

/// Passo a passo para (re)conectar a torre ao Wi-Fi, quando ela nao manda dados.
class CartaoWifi extends StatelessWidget {
  final Torre torre;

  /// true: a torre nunca mandou leitura (primeira configuracao).
  /// false: mandava e parou (roteador trocado, sem energia...).
  final bool nuncaConectou;

  const CartaoWifi({super.key, required this.torre, required this.nuncaConectou});

  @override
  Widget build(BuildContext context) {
    final titulo = nuncaConectou
        ? 'Conecte sua torre ao Wi-Fi'
        : 'Sua torre está sem conexão';
    final resumo = nuncaConectou
        ? 'A torre ainda não mandou nenhuma leitura. Ela já rega sozinha; '
              'para ver os dados aqui, conecte-a à internet:'
        : 'A torre parou de mandar dados. Ela continua regando no último '
              'ciclo. Confira se ela está ligada na tomada e se o Wi-Fi da '
              'casa funciona. Se você trocou o roteador ou a senha, '
              'configure de novo:';
    final passos = <String>[
      if (!nuncaConectou)
        'Segure o botão BOOT da placa por 5 segundos para a torre esquecer o Wi-Fi antigo.',
      'No celular, abra o Wi-Fi e conecte na rede "${torre.redeConfiguracao}" (a senha está no manual da torre).',
      'A página de configuração abre sozinha. Se não abrir, acesse 192.168.4.1 no navegador.',
      'Escolha o Wi-Fi da sua casa, digite a senha e salve.',
      'Volte a este app: em até um minuto a torre aparece online.',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AeroColors.aguaFundo,
        borderRadius: BorderRadius.circular(AeroRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                nuncaConectou
                    ? Icons.wifi_find_rounded
                    : Icons.wifi_off_rounded,
                color: AeroColors.agua,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontFamily: AeroFonts.titulo,
                    color: AeroColors.tinta,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            resumo,
            style: const TextStyle(
              color: AeroColors.tintaSuave,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < passos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: const TextStyle(
                      color: AeroColors.agua,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      passos[i],
                      style: const TextStyle(
                        color: AeroColors.tinta,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'A torre só funciona em redes 2,4 GHz. Redes com página de login '
            '(universidade, hotel) não funcionam: use o roteador do celular.',
            style: TextStyle(
              color: AeroColors.tintaSuave,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
