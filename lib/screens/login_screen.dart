import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../services/backend_service.dart';
import '../services/sessao.dart';
import 'torres_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Web: clientId = client ID web (o token devolvido é um access token).
  // Android: serverClientId = client ID web, para o idToken sair com ele
  // como destinatário — é o que o serviço de auth confere.
  // iOS: clientId vem do GoogleService-Info.plist / Info.plist.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? AppConfig.googleWebClientId : null,
    serverClientId: kIsWeb || AppConfig.googleWebClientId.isEmpty
        ? null
        : AppConfig.googleWebClientId,
    scopes: ['openid', 'email', 'profile'],
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

      if (tokenParaEnvio == null) {
        _mostrarErro('Não foi possível obter o token de autenticação do Google.');
        return;
      }

      // O serviço de auth confere o token e devolve a sessão do AeroTower,
      // que vale também no Backend.
      await Sessao.instance.entrarComGoogle(tokenParaEnvio);
      _seguir();
    } on BackendException catch (e) {
      _mostrarErro(e.message);
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

  /// Login sem Google, para desenvolver e para a banca (LOGIN_DEV=true no
  /// build e AUTH_MODO_DEV=true no servidor).
  Future<void> _loginDev() async {
    setState(() => _isLoading = true);
    try {
      await Sessao.instance.entrarDev('demo');
      _seguir();
    } on BackendException catch (e) {
      _mostrarErro(e.message);
    } catch (e) {
      _mostrarErro('Sem resposta do servidor: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// A tela de torres decide: abre o painel da torre ou pede o código.
  void _seguir() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TorresScreen()),
    );
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
                    if (AppConfig.loginDev) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading ? null : _loginDev,
                        child: const Text(
                          'Entrar sem Google (modo de teste)',
                          style: TextStyle(color: Color(0xFF8B949E)),
                        ),
                      ),
                    ],
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