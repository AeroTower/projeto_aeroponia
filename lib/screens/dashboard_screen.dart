import 'dart:async';
import 'package:flutter/material.dart';
import '../models/backend_models.dart';
import '../models/torre.dart';
import '../services/backend_service.dart';
import '../services/sessao.dart';
import '../theme/app_theme.dart';
import '../widgets/aero_logo.dart';
import 'chat_bot.dart';
import 'login_screen.dart';
import 'painel/aviso_conexao.dart';
import 'painel/barra_status.dart';
import 'painel/cabecalho_painel.dart';
import 'painel/cartao_wifi.dart';
import 'painel/componentes.dart';
import 'painel/faixa_alertas.dart';
import 'painel/grade_sensores.dart';
import 'painel/painel_motor.dart';
import 'plants_screen.dart';
import 'vincular_torre_screen.dart';

const _intervalo = Duration(seconds: 3);

// ── Painel da torre ─────────────────────────────────────────────────────────
// Esta tela cuida do estado (leituras, presença, comandos da bomba) e monta
// as partes que ficam em painel/: cada uma só desenha o que recebe.

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

  SituacaoPainel get _situacao => SituacaoPainel.de(
    erroDeConexao: _erroConexao != null,
    torreSumiu: _mostrarCartaoWifi,
    conectado: _conectado,
  );

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(sucesso)));
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
    return Scaffold(
      backgroundColor: AeroColors.bg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Center(
          // Em tela larga o conteúdo não estica até as bordas.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CabecalhoPainel(
                  situacao: _situacao,
                  ultimaAtualizacao: _ultimaAtualizacao,
                  intervalo: _intervalo,
                ),
                const SizedBox(height: 20),

                // Faixa de alertas críticos
                if (_alertas.isNotEmpty) ...[
                  FaixaAlertas(alertas: _alertas),
                  const SizedBox(height: 16),
                ],

                // Torre sem internet (nunca configurada ou caiu)
                if (_mostrarCartaoWifi) ...[
                  CartaoWifi(
                    torre: widget.torre!,
                    nuncaConectou: !_torreJaConectou,
                  ),
                  const SizedBox(height: 16),
                ],

                // Aviso de erro de conexão
                if (_erroConexao != null) ...[
                  AvisoConexao(
                    mensagem: _erroConexao!,
                    onTentarDeNovo: _buscarDados,
                  ),
                  const SizedBox(height: 16),
                ],

                GradeSensores(
                  tem: _tem,
                  ph: _ph,
                  tds: _ec,
                  temperatura: _tempAgua,
                  nivelAgua: _nivelAgua,
                ),
                const SizedBox(height: 16),
                PainelMotor(
                  motorStatus: _motorStatus,
                  erro: _erroMotor,
                  enviando: _enviandoComandoMotor,
                  minutosLigado: _minutosLigadoCtrl,
                  minutosDesligado: _minutosDesligadoCtrl,
                  onAtualizar: _buscarStatusMotor,
                  onIniciar: _iniciarCicloPersonalizado,
                  onDesligar: _desligarMotor,
                ),
                const SizedBox(height: 16),
                BarraStatus(
                  erroConexao: _erroConexao,
                  conectado: _conectado,
                  temAvisoAcima: _alertas.isNotEmpty || _mostrarCartaoWifi,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AeroColors.borda),
      ),
      // Com a lista de torres por trás, a seta volta para ela.
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AeroColors.tinta,
              ),
              tooltip: 'Minhas torres',
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : const Padding(padding: EdgeInsets.all(10), child: AeroLogo()),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.torre?.nome ?? 'AeroTower',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AeroFonts.titulo,
              color: AeroColors.tinta,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          Text(
            widget.torre?.kitNome ?? 'Sistema de Monitoramento',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AeroFonts.corpo,
              color: AeroColors.tintaSuave,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        // Indicador de conexão animado
        IndicadorConexao(pulso: _pulseController, conectado: _conectado),
        const SizedBox(width: 12),
        // A IA analisa pH, temperatura e umidade: só faz sentido no kit Pro.
        if (_tem('ph')) ...[
          AppBarButton(
            icon: Icons.smart_toy_outlined,
            label: 'IA',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatbotScreen(
                  torreId: widget.torre?.id,
                  phAtual: _ph,
                  tempAtual: _tempAgua,
                  umidadeAtual: _umidade,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (widget.torre != null) ...[
          AppBarButton(
            icon: Icons.eco_outlined,
            label: 'Plantas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlantsScreen(
                  torreId: widget.torre!.id,
                  torreNome: widget.torre!.nome,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            icon: const Icon(Icons.more_vert_rounded, color: AeroColors.tinta),
            onSelected: (opcao) {
              if (opcao == 'remover') _removerTorre();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'remover',
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded, color: AeroColors.erro, size: 20),
                    SizedBox(width: 10),
                    Text('Remover torre da minha conta'),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Remover torre da conta ─────────────────────────────────────────────────

  Future<void> _removerTorre() async {
    final torre = widget.torre!;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text(
          'Remover torre da sua conta?',
          style: TextStyle(
            fontFamily: AeroFonts.titulo,
            color: AeroColors.tinta,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          '"${torre.nome}" deixa de aparecer no app. A torre continua '
          'funcionando no último ciclo configurado.\n\n'
          'Para usar de novo — ou passar para outra pessoa — basta digitar o '
          'código do adesivo. Suas plantas desta torre ficam guardadas e '
          'voltam se você a vincular de novo; quem vincular depois não as vê.',
          style: const TextStyle(color: AeroColors.tintaSuave, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar', style: TextStyle(color: AeroColors.tintaSuave)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Remover', style: TextStyle(color: AeroColors.erro)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await Sessao.instance.desvincularTorre(torre.id);
    } on BackendException catch (e) {
      if (e.statusCode == 401) {
        Sessao.instance.sair();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }
      _avisar(e.message, erro: true);
      return;
    } catch (_) {
      _avisar('Sem resposta do servidor. Tente de novo.', erro: true);
      return;
    }
    if (!mounted) return;
    _avisar('Torre removida da sua conta.');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const VincularTorreScreen()),
      (_) => false,
    );
  }

  void _avisar(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensagem),
      backgroundColor: erro ? AeroColors.erro : AeroColors.musgo,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
