import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

// Pecas pequenas do painel. Antes eram classes privadas no fim do
// dashboard_screen.dart (1370 linhas); agora cada parte do painel mora no
// seu arquivo e estas pecas sao compartilhadas entre elas.

/// "14:05:09", ou "--:--:--" antes da primeira leitura. Antes o mesmo calculo
/// aparecia duas vezes no painel (cabecalho e bomba).
String formatarHora(DateTime? momento) {
  if (momento == null) return '--:--:--';
  String doisDigitos(int n) => n.toString().padLeft(2, '0');
  return '${doisDigitos(momento.hour)}:${doisDigitos(momento.minute)}:'
      '${doisDigitos(momento.second)}';
}

/// Ponto que pulsa na barra do topo: verde conectado, vermelho sem conexao.
class IndicadorConexao extends StatelessWidget {
  final Animation<double> pulso;
  final bool conectado;

  const IndicadorConexao({super.key, required this.pulso, required this.conectado});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulso,
      builder: (context, child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: conectado
                ? AeroColors.musgo.withValues(
                    alpha: 0.4 + 0.6 * pulso.value,
                  )
                : AeroColors.erro.withValues(alpha: 0.6),
            boxShadow: conectado
                ? [
                    BoxShadow(
                      color: AeroColors.musgo.withValues(
                        alpha: 0.3 * pulso.value,
                      ),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class StatusContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;

  const StatusContainer({
    super.key,
    required this.child,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const MetaPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AeroColors.areia,
        borderRadius: BorderRadius.circular(AeroRadius.pilula),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AeroColors.tintaSuave, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: AeroColors.tintaSuave, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AeroRadius.pilula),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class MotorButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isDanger;
  final VoidCallback onPressed;

  const MotorButton({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    const texto = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    const espaco = EdgeInsets.symmetric(horizontal: 18, vertical: 12);

    // A ação principal é cheia; "Desligar" fica contornado para não competir.
    if (isDanger) {
      return OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AeroColors.erro,
          side: const BorderSide(color: AeroColors.erro),
          padding: espaco,
          shape: const StadiumBorder(),
        ),
        icon: Icon(icon, size: 18),
        label: const Text('Desligar', style: texto),
      );
    }

    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(padding: espaco),
      icon: Icon(icon, size: 18),
      label: Text(label, style: texto),
    );
  }
}

class MotorCycleField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;

  const MotorCycleField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AeroColors.tinta, fontSize: 14),
      cursorColor: AeroColors.musgo,
      decoration: InputDecoration(
        labelText: '$label (min)',
        prefixIcon: Icon(icon, color: AeroColors.tintaSuave, size: 18),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class AppBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const AppBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final borda = const BorderSide(color: AeroColors.tinta, width: 0.6);

    if (MediaQuery.sizeOf(context).width < 480) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: AeroColors.tinta,
          side: borda,
        ),
        icon: Icon(icon, size: 18),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AeroColors.tinta,
        side: borda,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
