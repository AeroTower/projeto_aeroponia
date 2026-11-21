import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'componentes.dart';

/// O que o selo do topo do painel diz. Antes era um ternario de quatro
/// niveis repetido para o texto e para a cor.
enum SituacaoPainel {
  offline('Offline', AeroColors.erro),
  torreSemConexao('Torre sem conexão', AeroColors.alerta),
  online('Online', AeroColors.musgo),
  conectando('Conectando', AeroColors.alerta);

  const SituacaoPainel(this.rotulo, this.cor);
  final String rotulo;
  final Color cor;

  /// Servidor respondendo nao quer dizer torre conectada: a falta da torre
  /// vem antes do "Online".
  static SituacaoPainel de({
    required bool erroDeConexao,
    required bool torreSumiu,
    required bool conectado,
  }) {
    if (erroDeConexao) return SituacaoPainel.offline;
    if (torreSumiu) return SituacaoPainel.torreSemConexao;
    return conectado ? SituacaoPainel.online : SituacaoPainel.conectando;
  }
}

/// Etiqueta + titulo grande + linha de informacoes, no topo do painel.
class CabecalhoPainel extends StatelessWidget {
  final SituacaoPainel situacao;
  final DateTime? ultimaAtualizacao;
  final Duration intervalo;

  const CabecalhoPainel({
    super.key,
    required this.situacao,
    required this.ultimaAtualizacao,
    required this.intervalo,
  });

  @override
  Widget build(BuildContext context) {
    // Etiqueta + título grande + linha de informações: mesma hierarquia do
    // topo da página inicial, sem caixa em volta.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusBadge(label: situacao.rotulo, color: situacao.cor),
        const SizedBox(height: 12),
        const Text(
          'Sensores em tempo real',
          style: TextStyle(
            fontFamily: AeroFonts.titulo,
            color: AeroColors.tinta,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            MetaPill(
              icon: Icons.schedule_rounded,
              label: 'Atualizado às ${formatarHora(ultimaAtualizacao)}',
            ),
            MetaPill(
              icon: Icons.autorenew_rounded,
              label: 'Intervalo ${intervalo.inSeconds}s',
            ),
          ],
        ),
      ],
    );
  }
}
