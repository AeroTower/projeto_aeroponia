import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'dashboard_screen.dart';

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
      _mostrarErro('Por favor, informe o token da torre.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

      final response = await http.post(
        Uri.parse('$baseUrl/torre/vincular'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token_torre': tokenTorre}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        _mostrarErro('Token de torre inválido ou já em uso.');
      }
    } catch (e) {
      _mostrarErro('Erro ao comunicar com o servidor: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.sensors_rounded,
                      size: 48,
                      color: Color(0xFF39D353),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Vincular AeroTower',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFE6EDF3),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Insira o token/código impresso no seu dispositivo para iniciar o monitoramento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _tokenController,
                      style: const TextStyle(color: Color(0xFFE6EDF3)),
                      decoration: InputDecoration(
                        hintText: 'Ex: TOWER-8080-XYZ',
                        hintStyle: const TextStyle(color: Color(0xFF8B949E)),
                        prefixIcon: const Icon(Icons.key, color: Color(0xFF8B949E)),
                        filled: true,
                        fillColor: const Color(0xFF1C2129),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF30363D)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF39D353)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _vincularTorre,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF39D353),
                          foregroundColor: const Color(0xFF0A0F14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Color(0xFF0A0F14))
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