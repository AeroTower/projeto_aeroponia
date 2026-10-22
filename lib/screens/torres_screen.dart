import 'package:flutter/material.dart';

import '../models/torre.dart';
import '../services/backend_service.dart';
import '../services/sessao.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'vincular_torre_screen.dart';

/// Depois do login, decide para onde ir:
/// * sem torre -> tela de vínculo (do Rafael);
/// * uma torre -> painel dela direto;
/// * mais de uma (se a regra de negócio mudar) -> lista.
///
/// [aguardarTorreId]: acabou de vincular. O Backend só fica sabendo pelo
/// RabbitMQ, alguns instantes depois, então tenta de novo até a torre
/// aparecer (consistência eventual).
class TorresScreen extends StatefulWidget {
  final String? aguardarTorreId;

  const TorresScreen({super.key, this.aguardarTorreId});

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

  static const _tentativas = 10;
  static const _intervalo = Duration(seconds: 1);

  final _backend = BackendService();
  List<Torre>? _torres;
  String? _erro;
  String _aguarde = 'Carregando suas torres…';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _backend.close();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _erro = null;
      _torres = null;
    });
    try {
      var torres = await _backend.listarTorres();
      final esperada = widget.aguardarTorreId;
      for (var i = 0; esperada != null && !torres.any((t) => t.id == esperada) && i < _tentativas; i++) {
        if (!mounted) return;
        setState(() => _aguarde = 'Preparando sua torre…');
        await Future.delayed(_intervalo);
        torres = await _backend.listarTorres();
      }
      if (!mounted) return;

      if (torres.isEmpty) {
        if (esperada != null) {
          setState(() => _erro = 'A torre foi vinculada, mas ainda não apareceu. Tente de novo em instantes.');
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VincularTorreScreen()),
        );
        return;
      }
      setState(() => _torres = torres);
      // Uma torre: abre direto. A seta do painel volta para cá (onde fica o Sair).
      if (torres.length == 1) _abrir(torres.first);
    } on BackendException catch (e) {
      if (e.statusCode == 401) {
        _sair();
        return;
      }
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Sem resposta do servidor.');
    }
  }

  void _abrir(Torre torre) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(torre: torre)),
    );
  }

  void _sair() {
    Sessao.instance.sair();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final torres = _torres;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Minhas torres', style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout_rounded, color: _textDim),
            onPressed: _sair,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (torres == null && _erro == null)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(color: _accent),
                        const SizedBox(height: 16),
                        Text(_aguarde, style: const TextStyle(color: _textDim)),
                      ],
                    ),
                  ),
                if (torres != null)
                  for (final torre in torres) _cartaoTorre(torre),
                if (_erro != null) ...[
                  Text(_erro!, style: const TextStyle(color: _red, fontSize: 13)),
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
}
