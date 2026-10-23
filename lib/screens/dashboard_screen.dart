import 'dart:async';
import 'package:flutter/material.dart';
import '../models/backend_models.dart';
import '../models/torre.dart';
import '../services/backend_service.dart';
import '../widgets/gauge_card.dart';
import '../widgets/nivel_agua_card.dart';
import 'chat_bot.dart';
import 'plants_screen.dart';

const _intervalo = Duration(seconds: 3);

// ── Design tokens ──────────────────────────────────────────────────────────────
class _Colors {
  static const bg = Color(0xFF0A0F14);
  static const surface = Color(0xFF161B22);
  static const surfaceElevated = Color(0xFF1C2129);
  static const border = Color(0xFF30363D);
  static const accent = Color(0xFF39D353); // verde hidropônico
  static const accentDim = Color(0xFF1A4731);
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const red = Color(0xFFFF6B6B);
  static const redDim = Color(0xFF3D1515);
  static const orange = Color(0xFFFF9500);
  static const orangeDim = Color(0xFF3D2400);
  static const blue = Color(0xFF58A6FF);
  static const blueDim = Color(0xFF0D2040);
  static const cyan = Color(0xFF2DD4BF);
  static const violet = Color(0xFFA78BFA);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  /// Torre exibida. Nula = modo antigo (torre única, rotas sem login).
  final Torre? torre;

  const DashboardScreen({super.key, this.torre});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final BackendService _backend;
  final _minutosLigadoCtrl = TextEditingController(text: '15');
  final _minutosDesligadoCtrl = TextEditingController(text: '45');
  Timer? _timer;
  late AnimationController _pulseController;

  double? _ph;
  double? _ec;
  double? _tempAgua;
  double? _nivelAgua;
  double? _umidade;

  List<String> _alertas = [];
  MotorStatus? _motorStatus;
  bool _conectado = false;
  bool _enviandoComandoMotor = false;
  String? _erroConexao;
  String? _erroMotor;
  DateTime? _ultimaAtualizacao;

  // Presença da torre (só com torre selecionada). Atualizada a cada 15 s:
  // a torre avisa online/offline pelo MQTT e o Backend repassa.
  Timer? _timerPresenca;
  bool? _torreOnline;
  bool _torreJaConectou = false;

  /// O kit decide o que aparece. Sem torre (modo antigo), mostra tudo.
  bool _tem(String capacidade) =>
      widget.torre == null || widget.torre!.tem(capacidade);

  @override
  void initState() {
    super.initState();
    _backend = BackendService(torreId: widget.torre?.id);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _torreOnline = widget.torre?.online;
    _torreJaConectou = widget.torre?.ultimaLeituraEm != null;

    _buscarDados();
    _timer = Timer.periodic(_intervalo, (_) => _buscarDados());
    if (widget.torre != null) {
      _timerPresenca = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _atualizarPresenca(),
      );
    }
  }

  Future<void> _atualizarPresenca() async {
    try {
      final torre = await _backend.getTorre();
      if (!mounted) return;
      setState(() {
        _torreOnline = torre.online;
        _torreJaConectou = _torreJaConectou || torre.ultimaLeituraEm != null;
      });
    } catch (_) {
      // Sem resposta: o aviso de conexão do painel já cobre esse caso.
    }
  }

  /// Mostra o cartão de Wi-Fi quando a torre não está mandando dados.
  bool get _mostrarCartaoWifi => widget.torre != null && _torreOnline != true;

  Future<void> _buscarDados() async {
    try {
      final snapshot = await _backend.getDados();

      if (!mounted) return;
      setState(() {
        _ph = snapshot.ph;
        _ec = snapshot.tds ?? snapshot.ec;
        _tempAgua = snapshot.temperaturaAgua ?? snapshot.temperaturaAmbiente;
        _nivelAgua = snapshot.nivelAgua;
        _umidade = snapshot.umidadeRelativa;
        _alertas = snapshot.alertas;
        _conectado = true;
        _erroConexao = null;
        _ultimaAtualizacao = snapshot.recebidoEm ?? DateTime.now();
        _torreJaConectou = true;
      });

      await _buscarStatusMotor();
    } on BackendException catch (e) {
      // 503 com torre selecionada = o servidor está bem, a torre é que
      // ainda não mandou leitura. Quem explica isso é o cartão de Wi-Fi.
      if (e.statusCode == 503 && widget.torre != null) {
        if (!mounted) return;
        setState(() {
          _conectado = true;
          _erroConexao = null;
        });
        return;
      }
      _setErro(e.message);
    } catch (_) {
      _setErro('Sem resposta do backend. Ele está rodando?');
    }
  }

  Future<void> _buscarStatusMotor() async {
    try {
      final status = await _backend.getMotorStatus();
      if (!mounted) return;
      setState(() {
        _motorStatus = status;
        _erroMotor = null;
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _erroMotor = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erroMotor = 'Status do motor indisponivel.');
    }
  }

  Future<void> _iniciarCicloPersonalizado() async {
    final minutosLigado = int.tryParse(_minutosLigadoCtrl.text.trim());
    final minutosDesligado = int.tryParse(_minutosDesligadoCtrl.text.trim());

    if (minutosLigado == null ||
        minutosDesligado == null ||
        minutosLigado < 1 ||
        minutosDesligado < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe minutos ligados e desligados maiores que zero.',
          ),
          backgroundColor: _Colors.surface,
        ),
      );
      return;
    }

    await _executarComandoMotor(
      () => _backend.iniciarCiclo(
        minutosLigado: minutosLigado,
        minutosDesligado: minutosDesligado,
      ),
      sucesso:
          'Ciclo iniciado: $minutosLigado min ligado / $minutosDesligado min desligado.',
    );
  }

  Future<void> _desligarMotor() async {
    await _executarComandoMotor(
      _backend.desligarMotor,
      sucesso: 'Comando para desligar enviado.',
    );
  }

  Future<void> _executarComandoMotor(
    Future<void> Function() comando, {
    required String sucesso,
  }) async {
    if (_enviandoComandoMotor) return;

    setState(() {
      _enviandoComandoMotor = true;
      _erroMotor = null;
    });

    try {
      await comando();
      await _buscarStatusMotor();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sucesso), backgroundColor: _Colors.surface),
      );
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _erroMotor = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erroMotor = 'Nao foi possivel enviar o comando.');
    } finally {
      if (mounted) {
        setState(() => _enviandoComandoMotor = false);
      }
    }
  }

  void _setErro(String mensagem) {
    if (!mounted) return;
    setState(() {
      _erroConexao = mensagem;
      _conectado = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerPresenca?.cancel();
    _pulseController.dispose();
    _backend.close();
    _minutosLigadoCtrl.dispose();
    _minutosDesligadoCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _buildDarkTheme(),
      child: Scaffold(
        backgroundColor: _Colors.bg,
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho da seção
              _buildSectionHeader(),
              const SizedBox(height: 14),

              // Faixa de alertas críticos
              if (_alertas.isNotEmpty) ...[
                _buildAlertBanner(),
                const SizedBox(height: 16),
              ],

              // Torre sem internet (nunca configurada ou caiu)
              if (_mostrarCartaoWifi) ...[
                _buildCartaoWifi(),
                const SizedBox(height: 16),
              ],

              // Aviso de erro de conexão
              if (_erroConexao != null) ...[
                _buildConnectionError(),
                const SizedBox(height: 16),
              ],

              // Grid de gauges
              _buildGaugeGrid(),

              const SizedBox(height: 24),

              _buildMotorPanel(),

              const SizedBox(height: 24),

              // Barra de status inferior
              _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _Colors.bg,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _Colors.border.withOpacity(0.75)),
      ),
      // Com a lista de torres por trás, a seta volta para ela.
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _Colors.textPrimary),
              tooltip: 'Minhas torres',
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: _Colors.accentDim,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.water_drop, color: _Colors.accent, size: 20),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.torre?.nome ?? 'AeroTower',
            style: const TextStyle(
              color: _Colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            widget.torre?.kitNome ?? 'Sistema de Monitoramento',
            style: TextStyle(
              color: _Colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        // Indicador de conexão animado
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _conectado
                    ? _Colors.accent.withOpacity(
                        0.4 + 0.6 * _pulseController.value,
                      )
                    : _Colors.red.withOpacity(0.6),
                boxShadow: _conectado
                    ? [
                        BoxShadow(
                          color: _Colors.accent.withOpacity(
                            0.3 * _pulseController.value,
                          ),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // A IA analisa pH, temperatura e umidade: só faz sentido no kit Pro.
        if (_tem('ph')) ...[
          _AppBarButton(
            icon: Icons.smart_toy_outlined,
            label: 'IA',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatbotScreen(
                phAtual: _ph,
                tempAtual: _tempAgua,
                umidadeAtual: _umidade,)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        _AppBarButton(
          icon: Icons.eco_outlined,
          label: 'Plantas',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlantsScreen()),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ── Cabeçalho da seção ─────────────────────────────────────────────────────

  Widget _buildSectionHeader() {
    final hora = _ultimaAtualizacao != null
        ? '${_ultimaAtualizacao!.hour.toString().padLeft(2, '0')}:'
              '${_ultimaAtualizacao!.minute.toString().padLeft(2, '0')}:'
              '${_ultimaAtualizacao!.second.toString().padLeft(2, '0')}'
        : '--:--:--';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sensores em Tempo Real',
                  style: TextStyle(
                    color: _Colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _MetaPill(
                      icon: Icons.schedule_rounded,
                      label: 'Atualizado às $hora',
                    ),
                    _MetaPill(
                      icon: Icons.autorenew_rounded,
                      label: 'Intervalo ${_intervalo.inSeconds}s',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusBadge(
            label: _erroConexao != null
                ? 'Offline'
                : _conectado
                ? 'Online'
                : 'Conectando',
            color: _erroConexao != null
                ? _Colors.red
                : _conectado
                ? _Colors.accent
                : _Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSensorSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        final children = [
          _SummaryMetric(
            icon: Icons.water_drop_outlined,
            label: 'pH',
            value: _formatMetric(_ph, ''),
            color: _sensorColor(_ph, 5.5, 6.5),
          ),
          _SummaryMetric(
            icon: Icons.science_outlined,
            label: 'TDS',
            value: _formatMetric(_ec, 'ppm'),
            color: _sensorColor(_ec, 560, 1260),
          ),
          _SummaryMetric(
            icon: Icons.thermostat_rounded,
            label: 'Temperatura',
            value: _formatMetric(_tempAgua, '°C'),
            color: _sensorColor(_tempAgua, 20, 28),
          ),
          _SummaryMetric(
            icon: Icons.opacity_rounded,
            label: 'Umidade',
            value: _formatMetric(_nivelAgua, '%'),
            color: _sensorColor(_nivelAgua, 50, 100),
          ),
        ];

        if (isCompact) {
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: children,
          );
        }

        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  String _formatMetric(double? value, String unit) {
    if (value == null) return '--';
    final suffix = unit.isEmpty ? '' : ' $unit';
    return '${value.toStringAsFixed(1)}$suffix';
  }

  Color _sensorColor(double? value, double idealMin, double idealMax) {
    if (value == null) return _Colors.textSecondary;
    if (value < idealMin || value > idealMax) return _Colors.orange;
    return _Colors.accent;
  }

  // ── Faixa de alertas ───────────────────────────────────────────────────────

  Widget _buildAlertBanner() {
    return Container(
      decoration: BoxDecoration(
        color: _Colors.redDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.red.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da faixa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _Colors.red.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: _Colors.red, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_alertas.length} alerta${_alertas.length > 1 ? 's' : ''} ativo${_alertas.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: _Colors.red,
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
              children: _alertas
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '›  ',
                            style: TextStyle(color: _Colors.red, fontSize: 14),
                          ),
                          Expanded(
                            child: Text(
                              a,
                              style: const TextStyle(
                                color: Color(0xFFFFB3B3),
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

  // ── Cartão "Conectar a torre ao Wi-Fi" ─────────────────────────────────────

  Widget _buildCartaoWifi() {
    final torre = widget.torre!;
    final nuncaConectou = !_torreJaConectou;
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Colors.blueDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Colors.blue.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                nuncaConectou ? Icons.wifi_find_rounded : Icons.wifi_off_rounded,
                color: _Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: _Colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            resumo,
            style: const TextStyle(
              color: _Colors.textSecondary,
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
                      color: _Colors.blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      passos[i],
                      style: const TextStyle(
                        color: _Colors.textPrimary,
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
            style: TextStyle(color: _Colors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Erro de conexão ────────────────────────────────────────────────────────

  Widget _buildConnectionError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Colors.orangeDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: _Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _erroConexao!,
              style: const TextStyle(color: _Colors.orange, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _buscarDados,
            style: TextButton.styleFrom(
              foregroundColor: _Colors.orange,
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

  // ── Grid de Gauges ─────────────────────────────────────────────────────────

  Widget _buildGaugeGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final crossAxisCount = compact
            ? 2
            : (constraints.maxWidth / 260).floor().clamp(2, 4);
        final childAspectRatio = compact ? 1.08 : 1.7;
        final cards = _cardsDoKit();
        if (cards.isEmpty) return _buildSemSensores();
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: childAspectRatio,
          children: cards,
        );
      },
    );
  }

  /// Só os cards dos sensores que o kit tem. A bomba fica sempre.
  List<Widget> _cardsDoKit() {
    return [
      if (_tem('ph'))
        GaugeCard(
          title: "pH",
          value: _ph,
          unit: "",
          min: 0,
          max: 14,
          icon: Icons.water_drop_outlined,
          accentColor: _Colors.cyan,
          ranges: [
            GaugeRange(startValue: 0, endValue: 5.5, color: _Colors.red),
            GaugeRange(
              startValue: 5.5,
              endValue: 6.5,
              color: _Colors.accent,
            ),
            GaugeRange(startValue: 6.5, endValue: 14, color: _Colors.red),
          ],
        ),
      if (_tem('tds'))
        GaugeCard(
          title: "TDS",
          value: _ec,
          unit: "ppm",
          min: 0,
          max: 2000,
          icon: Icons.science_outlined,
          accentColor: _Colors.violet,
          ranges: [
            GaugeRange(startValue: 0, endValue: 560, color: _Colors.red),
            GaugeRange(
              startValue: 560,
              endValue: 1260,
              color: _Colors.accent,
            ),
            GaugeRange(
              startValue: 1260,
              endValue: 2000,
              color: _Colors.red,
            ),
          ],
        ),
      if (_tem('clima'))
        GaugeCard(
          title: "Temperatura",
          value: _tempAgua,
          unit: "°C",
          min: 10,
          max: 35,
          icon: Icons.thermostat_rounded,
          accentColor: _Colors.orange,
          ranges: [
            GaugeRange(startValue: 10, endValue: 20, color: _Colors.red),
            GaugeRange(startValue: 20, endValue: 28, color: _Colors.accent),
            GaugeRange(startValue: 28, endValue: 35, color: _Colors.red),
          ],
        ),
      // Nivel de tanque nao e grandeza que oscila em torno de um
      // ideal como pH ou temperatura: o que importa e quanto ainda
      // resta. A ampola mostra isso de imediato; o medidor circular
      // obrigava a interpretar um ponteiro.
      if (_tem('nivel'))
        NivelAguaCard(
          valor: _nivelAgua,
          minimoAlerta: 35,
          corFundo: _Colors.surface,
          corBorda: _Colors.border,
          corTexto: _Colors.textPrimary,
          corTextoSecundario: _Colors.textSecondary,
        ),
    ];
  }

  /// Kit Básico: não há sensores, só a rega automática.
  Widget _buildSemSensores() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Colors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.water_rounded, color: _Colors.accent, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Sua torre rega sozinha no ciclo abaixo. '
              'Sensor de nível (Kit Completo) e pH, nutrientes e clima '
              '(Kit Pro) podem ser adicionados depois.',
              style: TextStyle(color: _Colors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotorPanel() {
    final status = _motorStatus?.resumo ?? 'Aguardando status do motor';
    final atualizadoEm = _motorStatus?.recebidoEm;
    final hora = atualizadoEm != null
        ? '${atualizadoEm.hour.toString().padLeft(2, '0')}:'
              '${atualizadoEm.minute.toString().padLeft(2, '0')}:'
              '${atualizadoEm.second.toString().padLeft(2, '0')}'
        : '--:--:--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _Colors.blueDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.waterfall_chart,
                  color: _Colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Controle da Bomba',
                      style: TextStyle(
                        color: _Colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Status: $status | Atualizado as $hora',
                      style: const TextStyle(
                        color: _Colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Atualizar status',
                onPressed: _buscarStatusMotor,
                color: _Colors.textSecondary,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (_erroMotor != null) ...[
            const SizedBox(height: 12),
            Text(
              _erroMotor!,
              style: const TextStyle(color: _Colors.orange, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final ligadoField = _MotorCycleField(
                controller: _minutosLigadoCtrl,
                label: 'Ligado',
                icon: Icons.power_settings_new_rounded,
                enabled: !_enviandoComandoMotor,
              );
              final desligadoField = _MotorCycleField(
                controller: _minutosDesligadoCtrl,
                label: 'Desligado',
                icon: Icons.power_off_rounded,
                enabled: !_enviandoComandoMotor,
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
                      _MotorButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Iniciar ciclo',
                        enabled: !_enviandoComandoMotor,
                        onPressed: _iniciarCicloPersonalizado,
                      ),
                      _MotorButton(
                        icon: Icons.stop_rounded,
                        label: 'Desligar',
                        enabled: !_enviandoComandoMotor,
                        isDanger: true,
                        onPressed: _desligarMotor,
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
  // ── Barra de status inferior ───────────────────────────────────────────────

  Widget _buildStatusBar() {
    if (_erroConexao != null) return _statusErro();
    if (!_conectado) return _statusCarregando();
    return _statusOk();
  }

  Widget _statusCarregando() {
    return _StatusContainer(
      color: _Colors.blueDim,
      borderColor: _Colors.blue.withOpacity(0.3),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(_Colors.blue),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Buscando dados do backend…',
            style: TextStyle(color: _Colors.blue, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _statusErro() {
    return _StatusContainer(
      color: _Colors.redDim,
      borderColor: _Colors.red.withOpacity(0.3),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _Colors.red, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _erroConexao!,
              style: const TextStyle(color: _Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusOk() {
    return _StatusContainer(
      color: _Colors.accentDim,
      borderColor: _Colors.accent.withOpacity(0.3),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: _Colors.accent, size: 18),
          SizedBox(width: 12),
          Text(
            'Todos os sistemas operacionais',
            style: TextStyle(color: _Colors.accent, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Theme ──────────────────────────────────────────────────────────────────

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _Colors.bg,
      primaryColor: _Colors.accent,
      cardColor: _Colors.surface,
      cardTheme: CardThemeData(
        color: _Colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _Colors.border),
        ),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: _Colors.textPrimary,
        displayColor: _Colors.textPrimary,
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _StatusContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;

  const _StatusContainer({
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _Colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _Colors.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: _Colors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
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

class _MotorButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isDanger;
  final VoidCallback onPressed;

  const _MotorButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? _Colors.red : _Colors.accent;

    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: _Colors.textSecondary,
        backgroundColor: color.withOpacity(enabled ? 0.12 : 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(enabled ? 0.35 : 0.1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _MotorCycleField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;

  const _MotorCycleField({
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
      style: const TextStyle(color: _Colors.textPrimary, fontSize: 14),
      cursorColor: _Colors.accent,
      decoration: InputDecoration(
        labelText: '$label (min)',
        labelStyle: const TextStyle(color: _Colors.textSecondary, fontSize: 12),
        prefixIcon: Icon(icon, color: _Colors.textSecondary, size: 18),
        filled: true,
        fillColor: _Colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _Colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _Colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _Colors.accent, width: 1.4),
        ),
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _AppBarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _Colors.textSecondary,
        backgroundColor: _Colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _Colors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
