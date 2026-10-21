import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'dashboard_screen.dart';
import 'vincular_torre_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    scopes: ['email', 'profile'],
  );

  bool _isLoading = false;

  Future<void> _loginComGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      // Suporte para Mobile (idToken) e Web (accessToken)
      final String? tokenParaEnvio = auth.idToken ?? auth.accessToken;

      if (tokenParaEnvio != null) {
        final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

        final response = await http.post(
          Uri.parse('$baseUrl/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': tokenParaEnvio}),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final bool possuiTorre = data['possui_torre'] ?? false;
          final String userEmail = data['email'] ?? account.email;

          if (!mounted) return;

          if (possuiTorre) {
            // Utilizador com torre vinculada segue para o Dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          } else {
            // Utilizador sem torre segue para o ecrã de vinculação com o e-mail
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => VincularTorreScreen(userEmail: userEmail),
              ),
            );
          }
        } else {
          _mostrarErro('Falha na autenticação pelo servidor (${response.statusCode}).');
        }
      } else {
        _mostrarErro('Não foi possível obter o token de autenticação do Google.');
      }
    } catch (error) {
      _mostrarErro('Erro ao conectar com o Google: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.redAccent,
      ),
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
                padding: const EdgeInsets.all(32),
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
                      Icons.eco_rounded,
                      size: 56,
                      color: Color(0xFF39D353),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AeroTower',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFE6EDF3),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sistema Integrado de Automação e Monitorização Hidropónica',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginComGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21262D),
                          foregroundColor: const Color(0xFFE6EDF3),
                          side: const BorderSide(color: Color(0xFF30363D)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFF39D353),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                    height: 20,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(
                                      Icons.account_circle,
                                      color: Color(0xFFE6EDF3),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continuar com o Google',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
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