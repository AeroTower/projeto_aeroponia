import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'vincular_torre_screen.dart';

import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  late final GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();

    final String clientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

    _googleSignIn = GoogleSignIn(
      clientId: clientId,
      // Se estiver a correr na Web, envia null. Se for no telemóvel, passa o clientId.
      serverClientId: kIsWeb ? null : clientId,
      scopes: ['email'],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  // ... restante do código permanece igual

  void _entrar() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

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
      
      // Captura o idToken no Mobile ou accessToken na Web
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

          if (!mounted) return;

          if (possuiTorre) {
            // Usuário já possui uma torre associada
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          } else {
            // Usuário autenticado, mas precisa vincular a torre
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const VincularTorreScreen()),
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF30363D)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A4731),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.water_drop,
                            color: Color(0xFF39D353),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AeroTower',
                                style: TextStyle(
                                  color: Color(0xFFE6EDF3),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Monitoramento hidropônico',
                                style: TextStyle(
                                  color: Color(0xFF8B949E),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _LoginField(
                      controller: _emailController,
                      icon: Icons.mail_outline_rounded,
                      hint: 'seu@email.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _LoginField(
                      controller: _passwordController,
                      icon: Icons.lock_outline_rounded,
                      hint: 'senha',
                      obscureText: true,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _entrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF39D353),
                          foregroundColor: const Color(0xFF0A0F14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text(
                          'Entrar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade800)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ou',
                            style: TextStyle(
                              color: Color(0xFF8B949E),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade800)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _loginComGoogle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE6EDF3),
                          side: const BorderSide(color: Color(0xFF30363D)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading 
                          ? const SizedBox(
                              width: 24, 
                              height: 24, 
                              child: CircularProgressIndicator(
                                strokeWidth: 2, 
                                color: Color(0xFFE6EDF3),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _GoogleMark(),
                                SizedBox(width: 10),
                                Text(
                                  'Continuar com Google',
                                  style: TextStyle(fontWeight: FontWeight.w700),
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

class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _LoginField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFFE6EDF3)),
      cursorColor: const Color(0xFF39D353),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8B949E)),
        prefixIcon: Icon(icon, color: const Color(0xFF8B949E), size: 20),
        filled: true,
        fillColor: const Color(0xFF1C2129),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF39D353), width: 1.4),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}