import 'package:flutter/material.dart';

import '../services/backend_service.dart';
import 'plants_screen.dart'; // Importa a classe Plant e PlantaService

// ── Design tokens ──────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const surfaceEl = Color(0xFF1C2129);
  static const border = Color(0xFF30363D);
  static const accent = Color(0xFF39D353);
  static const accentDim = Color(0xFF1A4731);
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const userBubble = Color(0xFF1A4731);
  static const aiBubble = Color(0xFF1C2129);
}

// ── Modelo de mensagem ─────────────────────────────────────────────────────────
class _Message {
  final String text;
  final bool isUser;

  const _Message({required this.text, required this.isUser});
}

// ── Tela de Chatbot ────────────────────────────────────────────────────────────
class ChatbotScreen extends StatefulWidget {
  final double? phAtual;
  final double? tempAtual;
  final double? umidadeAtual;

  /// Torre do painel: a IA conhece só as plantas dela.
  final String? torreId;

  const ChatbotScreen({
    super.key,
    this.torreId,
    this.phAtual,
    this.tempAtual,
    this.umidadeAtual,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_Message> _messages = [];
  final _scrollCtrl = ScrollController();
  
  // Variáveis para as plantas reais da API
  List<Plant> _plantasReais = [];
  String? _selectedPlantNome; 
  bool _carregandoPlantas = true;

  bool _isTyping = false;
  final List<Map<String, String>> _history = [];
  
  // Instância do serviço que faz a chamada HTTP
  final _backend = BackendService();

  @override
  void initState() {
    super.initState();
    // Mensagem de boas-vindas local (sem chamar a API)
    _messages.add(
      const _Message(
        text:
            'Olá! Sou o **HydroBot** 🌱\n\nSou especialista em hidroponia e aeroponia. Pode me perguntar sobre pH, EC, temperatura, nutrientes, pragas ou qualquer dúvida do seu cultivo!',
        isUser: false,
      ),
    );
    
    // Busca as plantas da API assim que abre o chat
    _buscarPlantas(); 
  }

  Future<void> _buscarPlantas() async {
    try {
      final lista = await PlantaService.listar(widget.torreId);
      if (mounted) {
        setState(() {
          _plantasReais = lista;
          _carregandoPlantas = false;
          // Seleciona a primeira planta da lista por padrão, se existir
          if (_plantasReais.isNotEmpty) {
            _selectedPlantNome = _plantasReais.first.nome;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregandoPlantas = false;
          _selectedPlantNome = null; 
        });
      }
    }
  }

  @override
  void dispose() {
    _backend.close();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Gerar orientação usando o Microserviço ───────────────────────────────────

  Future<void> _solicitarOrientacaoMicroservico() async {
    if (_isTyping) return;
    
    // Trava de segurança: impede o envio se não houver planta selecionada
    if (_selectedPlantNome == null) {
      _addError('Selecione uma planta primeiro. Se não houver nenhuma, cadastre na tela de Plantas.');
      return;
    }

    setState(() {
      final phTela = widget.phAtual?.toStringAsFixed(1) ?? 'NULO';
      final tempTela = widget.tempAtual?.toStringAsFixed(1) ?? 'NULO';
      final umiTela = widget.umidadeAtual?.toStringAsFixed(1) ?? 'NULO';

      _messages.add(_Message(
          text: 'Analisando **$_selectedPlantNome**...\n💧 pH: $phTela\n🌡️ Temp: $tempTela\n💦 Umid: $umiTela',
          isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final reply = await _backend.analisarCultivoIA(
        cultura: _selectedPlantNome!,
        ph: widget.phAtual ?? 7.5,
        temperatura: widget.tempAtual ?? 28.5,
        umidade: widget.umidadeAtual ?? 45.0,
      );

      if (!mounted) return;

      _history.add({'role': 'assistant', 'content': reply});

      setState(() {
        _isTyping = false;
        _messages.add(_Message(text: reply, isUser: false));
      });
    } on BackendException catch (e) {
      _addError('Erro da IA: ${e.message}');
    } catch (e) {
      _addError('Falha ao conectar com hidroponia-ia.azurewebsites.net.');
    }

    _scrollToBottom();
  }

  void _addError(String msg) {
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(_Message(text: '⚠️ $msg', isUser: false));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkTheme(),
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildPlantContextCard(),
            Expanded(child: _buildMessageList()),
            _buildTypingIndicator(),
            _buildGenerateBar(),
          ],
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.surface,
      elevation: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _C.border),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: _C.textSecondary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _C.accentDim,
              shape: BoxShape.circle,
              border: Border.all(color: _C.accent.withOpacity(0.4)),
            ),
            child: const Icon(Icons.eco, color: _C.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HydroBot',
                style: TextStyle(
                  color: _C.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Online · Especialista em hidroponia',
                    style: TextStyle(color: _C.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: _C.textSecondary,
            size: 20,
          ),
          tooltip: 'Limpar conversa',
          onPressed: _clearChat,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _history.clear();
      _messages.add(
        const _Message(
          text:
              'Olá! Sou o **HydroBot** 🌱\n\nSou especialista em hidroponia e aeroponia. Pode me perguntar sobre pH, EC, temperatura, nutrientes, pragas ou qualquer dúvida do seu cultivo!',
          isUser: false,
        ),
      );
    });
  }

  Widget _buildPlantContextCard() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: _carregandoPlantas
          ? const Center(child: CircularProgressIndicator(color: _C.accent))
          : _plantasReais.isEmpty
              ? const Text(
                  'Nenhuma planta cadastrada na torre.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14),
                )
              : DropdownButtonFormField<String>(
                  value: _selectedPlantNome,
                  dropdownColor: _C.surfaceEl,
                  iconEnabledColor: _C.textSecondary,
                  style: const TextStyle(color: _C.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Planta em análise',
                    labelStyle: const TextStyle(color: _C.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.local_florist_outlined,
                      color: _C.textSecondary,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: _C.surfaceEl,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.accent, width: 1.4)),
                  ),
                  items: _plantasReais.map((plant) => DropdownMenuItem<String>(
                            value: plant.nome,
                            child: Text(plant.nome),
                          )).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedPlantNome = value);
                  },
                ),
    );
  }

  // ── Lista de mensagens ───────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(_Message msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _C.accentDim,
                shape: BoxShape.circle,
                border: Border.all(color: _C.accent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.eco, color: _C.accent, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _C.userBubble : _C.aiBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser ? _C.accent.withOpacity(0.3) : _C.border,
                ),
              ),
              child: _buildMessageText(msg.text, isUser),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Renderiza **negrito** simples via `TextSpan`
  Widget _buildMessageText(String text, bool isUser) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: isUser ? _C.textPrimary : _C.textPrimary,
          fontSize: 14,
          height: 1.45,
        ),
        children: spans,
      ),
    );
  }

  // ── Indicador de digitação ───────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    if (!_isTyping) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _C.accentDim,
              shape: BoxShape.circle,
              border: Border.all(color: _C.accent.withOpacity(0.3)),
            ),
            child: const Icon(Icons.eco, color: _C.accent, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _C.aiBubble,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ── Ação principal ───────────────────────────────────────────────────────────

  Widget _buildGenerateBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isTyping ? null : _solicitarOrientacaoMicroservico,
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.accent,
            disabledBackgroundColor: _C.surfaceEl,
            foregroundColor: _C.bg,
            disabledForegroundColor: _C.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(
            _isTyping ? Icons.hourglass_top_rounded : Icons.auto_awesome,
            size: 18,
          ),
          label: Text(
            _isTyping ? 'Gerando orientação...' : 'Gerar orientação',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  ThemeData _darkTheme() => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _C.bg,
        primaryColor: _C.accent,
      );
}

// ── Animação de digitação (três pontos) ────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (offset < 0.5 ? offset : 1.0 - offset) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _C.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}