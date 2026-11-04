import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Nível do reservatório desenhado como uma ampola vertical que enche de
/// água, com a porcentagem em cima.
///
/// Um medidor circular serve bem para grandeza que sobe e desce em torno
/// de um ideal (pH, temperatura). Nível de tanque não é isso: o que
/// importa é "quanto ainda tem", e disso a leitura é imediata quando a
/// forma imita o próprio tanque.
class NivelAguaCard extends StatelessWidget {
  /// Porcentagem de 0 a 100. Nulo enquanto não chegou leitura.
  final double? valor;

  /// Abaixo disto o backend dispara alerta — a água fica vermelha.
  final double minimoAlerta;

  final Color corFundo;
  final Color corBorda;
  final Color corTexto;

  const NivelAguaCard({
    super.key,
    required this.valor,
    this.minimoAlerta = 35,
    this.corFundo = AeroColors.areia,
    this.corBorda = AeroColors.borda,
    this.corTexto = AeroColors.tinta,
  });

  static const _azul = AeroColors.agua;
  static const _azulFundo = AeroColors.aguaFundo;
  static const _vermelho = AeroColors.erro;
  static const _laranja = AeroColors.alerta;

  /// Verde não entra aqui: a água é azul porque é água. A cor só muda
  /// para avisar que está acabando.
  Color get _corAgua {
    final v = valor;
    if (v == null) return _azul;
    if (v < minimoAlerta) return _vermelho;
    if (v < minimoAlerta + 15) return _laranja;
    return _azul;
  }

  String get _rotuloEstado {
    final v = valor;
    if (v == null) return 'sem leitura';
    if (v < minimoAlerta) return 'reabastecer';
    if (v < minimoAlerta + 15) return 'atenção';
    return 'nível ok';
  }

  @override
  Widget build(BuildContext context) {
    final v = valor;
    final temLeitura = v != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(AeroRadius.card),
      ),
      // O card da grade é largo e baixo. Empilhar número e ampola deixaria
      // a ampola com uns 40px de altura; lado a lado ela usa toda a altura
      // disponível e o número fica com a largura.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    // Em celular bem estreito, o ícone tiraria espaço do título.
                    if (MediaQuery.sizeOf(context).width >= 360) ...[
                      Icon(Icons.water_drop_rounded, size: 16, color: _corAgua),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        'Nível da água',
                        style: TextStyle(
                          color: corTexto,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    temLeitura ? '${v.round()}%' : '--',
                    style: TextStyle(
                      fontFamily: AeroFonts.titulo,
                      color: corTexto,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _rotuloEstado,
                  style: TextStyle(
                    color: _corAgua,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Ampola(
            preenchimento: temLeitura ? (v.clamp(0, 100)) / 100 : 0,
            cor: _corAgua,
            corVazio: _azulFundo,
            corBorda: corBorda,
            marcaAlerta: minimoAlerta / 100,
            temLeitura: temLeitura,
          ),
        ],
      ),
    );
  }
}

class _Ampola extends StatelessWidget {
  final double preenchimento; // 0..1
  final Color cor;
  final Color corVazio;
  final Color corBorda;
  final double marcaAlerta;
  final bool temLeitura;

  const _Ampola({
    required this.preenchimento,
    required this.cor,
    required this.corVazio,
    required this.corBorda,
    required this.marcaAlerta,
    required this.temLeitura,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Estreita e alta, como um tubo de ensaio. A altura vem do card;
        // a largura acompanha para não virar uma faixa larga em tela grande.
        final altura = constraints.maxHeight.clamp(48.0, 150.0);
        final largura = (altura * 0.36).clamp(24.0, 46.0);
        final raio = largura / 2;

        return SizedBox(
          width: largura,
          height: altura,
          child: Stack(
            children: [
              // Corpo vazio
              Container(
                decoration: BoxDecoration(
                  color: corVazio,
                  borderRadius: BorderRadius.circular(raio),
                  border: Border.all(color: corBorda),
                ),
              ),

              // Água: cresce de baixo para cima. AnimatedFractionallySized
              // faz a transicao suave quando chega leitura nova, em vez de
              // pular de um valor para o outro.
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(raio),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      heightFactor: preenchimento,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              cor.withValues(alpha: 0.9),
                              cor.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Linha do limite de alerta: mostra onde o backend passa a
              // reclamar, para o numero nao ser so um numero.
              if (temLeitura)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: altura * marcaAlerta,
                  child: Container(
                    height: 1,
                    color: AeroColors.erro.withValues(alpha: 0.55),
                  ),
                ),

              // Brilho lateral: dá o aspecto de vidro sem custar nada.
              Positioned(
                left: largura * 0.18,
                top: altura * 0.08,
                bottom: altura * 0.08,
                width: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),

              // Contorno por cima, para a água não vazar visualmente na borda
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(raio),
                    border: Border.all(color: corBorda),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
