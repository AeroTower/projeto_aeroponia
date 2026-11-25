import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'componentes.dart';

/// Faixa no fim do painel: buscando, erro ou "tudo certo".
class BarraStatus extends StatelessWidget {
  final String? erroConexao;
  final bool conectado;

  /// Ja ha alerta ou cartao de Wi-Fi na tela: dizer "tudo certo" aqui
  /// contradiria esses avisos.
  final bool temAvisoAcima;

  const BarraStatus({
    super.key,
    required this.erroConexao,
    required this.conectado,
    required this.temAvisoAcima,
  });

  @override
  Widget build(BuildContext context) {
    final mensagem = erroConexao;
    if (mensagem != null) return _Erro(mensagem: mensagem);
    if (!conectado) return const _Carregando();
    if (temAvisoAcima) return const SizedBox.shrink();
    return const _TudoCerto();
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return StatusContainer(
      color: AeroColors.aguaFundo,
      borderColor: AeroColors.agua.withValues(alpha: 0.3),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(AeroColors.agua),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Buscando dados do backend…',
            style: TextStyle(color: AeroColors.agua, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  final String mensagem;

  const _Erro({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return StatusContainer(
      color: AeroColors.erroFundo,
      borderColor: AeroColors.erro.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AeroColors.erro, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(color: AeroColors.erro, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _TudoCerto extends StatelessWidget {
  const _TudoCerto();

  @override
  Widget build(BuildContext context) {
    return StatusContainer(
      color: AeroColors.mint,
      borderColor: AeroColors.musgo.withValues(alpha: 0.3),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AeroColors.musgo, size: 18),
          SizedBox(width: 12),
          Text(
            'Todos os sistemas operacionais',
            style: TextStyle(color: AeroColors.musgo, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
