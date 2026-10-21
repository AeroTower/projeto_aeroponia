import 'package:flutter/material.dart';

import '../models/torre.dart';
import '../services/backend_service.dart';
import 'dashboard_screen.dart';

/// Depois do login: lista as torres da conta ou pede o código do adesivo.
///
/// Com uma torre só, abre o painel direto (a seta do painel volta para cá,
/// onde dá para adicionar outra).
class TorresScreen extends StatefulWidget {
  const TorresScreen({super.key});

  @override
  State<TorresScreen> createState() => _TorresScreenState();
}

class _TorresScreenState extends State<TorresScreen> {
  static const _bg = Color(0xFF0A0F14);
  static const _surface = Color(0xFF161B22);
  static const _border = Color(0xFF30363D);
  static const _accent = Color(0xFF39D353);
  static const _text = Color(0xFFE6EDF3);
  static const _textDim = Color(0xFF8B949E);
  static const _red = Color(0xFFFF6B6B);

  final _backend = BackendService();
  final _codigoCtrl = TextEditingController();
  final _apelidoCtrl = TextEditingController();

  List<Torre>? _torres;
  String? _erro;
  bool _ativando = false;
  bool _mostrarFormulario = false;
  bool _abriuSozinho = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _backend.close();
    _codigoCtrl.dispose();
    _apelidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final torres = await _backend.listarTorres();
      if (!mounted) return;
      setState(() => _torres = torres);
      if (torres.length == 1 && !_abriuSozinho) {
        _abriuSozinho = true;
        _abrir(torres.first);
      }
    } on BackendException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Sem resposta do servidor.');
    }
  }

  Future<void> _ativar() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) return;
    setState(() {
      _ativando = true;
      _erro = null;
    });
    try {
      final torre = await _backend.ativarTorre(codigo, apelido: _apelidoCtrl.text);
      _codigoCtrl.clear();
      _apelidoCtrl.clear();
      if (!mounted) return;
      setState(() {
        _torres = [...?_torres, torre];
        _mostrarFormulario = false;
      });
      _abrir(torre);
    } on BackendException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível ativar agora.');
    } finally {
      if (mounted) setState(() => _ativando = false);
    }
  }

  void _abrir(Torre torre) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(torre: torre)),
    ).then((_) => _carregar());
  }

  @override
  Widget build(BuildContext context) {
    final torres = _torres;
    final semTorres = torres != null && torres.isEmpty;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Minhas torres', style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (torres == null && _erro == null)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: _accent)),
                  ),
                if (torres != null)
                  for (final torre in torres) _cartaoTorre(torre),
                if (torres != null && torres.isNotEmpty && !_mostrarFormulario)
                  TextButton.icon(
                    onPressed: () => setState(() => _mostrarFormulario = true),
                    icon: const Icon(Icons.add_rounded, color: _accent),
                    label: const Text('Adicionar outra torre', style: TextStyle(color: _accent)),
                  ),
                if (semTorres || _mostrarFormulario) _formularioAtivacao(primeira: semTorres),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(_erro!, style: const TextStyle(color: _red, fontSize: 13)),
                  if (torres == null)
                    TextButton(onPressed: _carregar, child: const Text('Tentar de novo')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartaoTorre(Torre torre) {
    final online = torre.online == true;
    return Card(
      color: _surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(Icons.water_drop, color: online ? _accent : _textDim),
        title: Text(torre.nome, style: const TextStyle(color: _text, fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${torre.kitNome} · ${online ? 'online' : 'offline'}',
          style: const TextStyle(color: _textDim, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: _textDim),
        onTap: () => _abrir(torre),
      ),
    );
  }

  Widget _formularioAtivacao({required bool primeira}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            primeira ? 'Vamos ligar sua torre' : 'Nova torre',
            style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Digite o código do adesivo que veio na caixa (ex.: K9X2-7QHM).',
            style: TextStyle(color: _textDim, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          _campo(_codigoCtrl, 'Código de ativação', Icons.qr_code_2_rounded, maiusculas: true),
          const SizedBox(height: 10),
          _campo(_apelidoCtrl, 'Nome da torre (opcional): Varanda, Cozinha…', Icons.edit_outlined),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _ativando ? null : _ativar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _ativando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _bg),
                    )
                  : const Text('Ativar torre', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String dica, IconData icone, {bool maiusculas = false}) {
    return TextField(
      controller: ctrl,
      textCapitalization: maiusculas ? TextCapitalization.characters : TextCapitalization.sentences,
      style: const TextStyle(color: _text),
      decoration: InputDecoration(
        hintText: dica,
        hintStyle: const TextStyle(color: _textDim, fontSize: 13),
        prefixIcon: Icon(icone, color: _textDim, size: 20),
        filled: true,
        fillColor: _bg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent),
        ),
      ),
    );
  }
}
