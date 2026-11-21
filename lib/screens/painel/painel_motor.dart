import 'package:flutter/material.dart';

import '../../models/backend_models.dart';
import '../../theme/app_theme.dart';
import 'componentes.dart';

/// Controle da bomba: status atual, minutos do ciclo e os botoes.
/// Quem manda o comando e o painel; aqui so a tela.
class PainelMotor extends StatelessWidget {
  final MotorStatus? motorStatus;
  final String? erro;

  /// true enquanto um comando vai para o Backend (trava os campos).
  final bool enviando;
  final TextEditingController minutosLigado;
  final TextEditingController minutosDesligado;
  final VoidCallback onAtualizar;
  final VoidCallback onIniciar;
  final VoidCallback onDesligar;

  const PainelMotor({
    super.key,
    required this.motorStatus,
    required this.erro,
    required this.enviando,
    required this.minutosLigado,
    required this.minutosDesligado,
    required this.onAtualizar,
    required this.onIniciar,
    required this.onDesligar,
  });

  @override
  Widget build(BuildContext context) {
    final status = motorStatus?.resumo ?? 'Aguardando status do motor';
    final hora = formatarHora(motorStatus?.recebidoEm);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AeroColors.mint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AeroColors.mintForte,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_rounded,
                  color: AeroColors.musgo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Controle da bomba',
                      style: TextStyle(
                        fontFamily: AeroFonts.titulo,
                        color: AeroColors.tinta,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Status: $status | Atualizado as $hora',
                      style: const TextStyle(
                        color: AeroColors.tintaSuave,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Atualizar status',
                onPressed: onAtualizar,
                color: AeroColors.tintaSuave,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (erro != null) ...[
            const SizedBox(height: 12),
            Text(
              erro!,
              style: const TextStyle(color: AeroColors.alerta, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final ligadoField = MotorCycleField(
                controller: minutosLigado,
                label: 'Ligado',
                icon: Icons.power_settings_new_rounded,
                enabled: !enviando,
              );
              final desligadoField = MotorCycleField(
                controller: minutosDesligado,
                label: 'Desligado',
                icon: Icons.power_off_rounded,
                enabled: !enviando,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  compact
                      ? Column(
                          children: [
                            ligadoField,
                            const SizedBox(height: 10),
                            desligadoField,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: ligadoField),
                            const SizedBox(width: 10),
                            Expanded(child: desligadoField),
                          ],
                        ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      MotorButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Iniciar ciclo',
                        enabled: !enviando,
                        onPressed: onIniciar,
                      ),
                      MotorButton(
                        icon: Icons.stop_rounded,
                        label: 'Desligar',
                        enabled: !enviando,
                        isDanger: true,
                        onPressed: onDesligar,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
