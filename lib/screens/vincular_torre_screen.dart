import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/app_config.dart';
import '../services/sessao.dart';
import '../theme/app_theme.dart';
import 'torres_screen.dart';

class VincularTorreScreen extends StatefulWidget {
  const VincularTorreScreen({super.key});

  @override
  State<VincularTorreScreen> createState() => _VincularTorreScreenState();
}

class _VincularTorreScreenState extends State<VincularTorreScreen> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

Future<void> _vincularTorre() async {
  final tokenTorre = _tokenController.text.trim();

  if (tokenTorre.isEmpty) {
    _mostrarErro('Por favor, insira o código do adesivo da AeroTower.');
    return;
  }

  setState(() => _isLoading = true);

  try {
    // Quem vincula é quem está logado (token no header). O e-mail não vai
    // mais no corpo: antes, qualquer um podia vincular em nome de outro.
    final response = await http.post(
      Uri.parse('${AppConfig.authBaseUrl}/torre/vincular'),
      headers: {
        'Content-Type': 'application/json',
        ...Sessao.instance.headers,
      },
      body: jsonEncode({'codigo': tokenTorre}),
    ).timeout(const Duration(seconds: 30));

    final Map<String, dynamic> bodyData = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AeroTower vinculada com sucesso!'),
          backgroundColor: AeroColors.musgo,
        ),
      );

      // O Backend fica sabendo do vínculo pelo RabbitMQ (alguns instantes
      // depois): a tela de torres espera ela aparecer e abre o painel.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TorresScreen(aguardarTorreId: bodyData['torre_id'] as String?),
        ),
      );
    } else {
      // Exibe a mensagem de erro exata retornada pela API (HTTP 400 / 409)
      final String mensagemErro = bodyData['detail'] ?? 'Erro ao vincular torre.';
      _mostrarErro(mensagemErro);
    }
  } catch (e) {
    _mostrarErro('Erro de conexão com o servidor: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: AeroColors.erro),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AeroColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AeroColors.creme,
                  borderRadius: BorderRadius.circular(AeroRadius.card),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.sensors_rounded,
                      size: 48,
                      color: AeroColors.terracota,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Vincular AeroTower',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AeroFonts.titulo,
                        color: AeroColors.tinta,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Insira o token/código impresso no seu dispositivo para iniciar o monitoramento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AeroColors.tintaSuave,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _tokenController,
                      style: const TextStyle(color: AeroColors.tinta),
                      decoration: const InputDecoration(
                        hintText: 'Ex: K9X2-7QHM',
                        prefixIcon: Icon(Icons.key, color: AeroColors.tintaSuave),
                        fillColor: AeroColors.bg,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _vincularTorre,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text(
                                'Conectar Torre',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}