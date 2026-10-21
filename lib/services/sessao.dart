import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_service.dart';

/// Guarda o token de sessão do back-end enquanto o app está aberto.
///
/// Fluxo do login com Google (para quem está fazendo essa parte;
/// exemplo com google_sign_in 6.x):
///
/// ```dart
/// final conta = await GoogleSignIn(scopes: ['email']).signIn();
/// final auth = await conta!.authentication;
/// await Sessao.instance.entrarComGoogle(auth.idToken!);
/// ```
///
/// O back-end confere o idToken com o Google e devolve um token próprio,
/// que vale 30 dias. Enquanto o login com Google não está pronto, use
/// [entrarDev] (o servidor precisa estar com AUTH_MODO_DEV=true).
class Sessao {
  Sessao._();
  static final Sessao instance = Sessao._();

  String? token;
  String? usuarioId;
  String? nome;

  bool get logado => token != null;

  Map<String, String> get headers =>
      token == null ? const {} : {'Authorization': 'Bearer $token'};

  Future<void> entrarComGoogle(String idToken) =>
      _entrar('/auth/google', {'idToken': idToken});

  Future<void> entrarDev(String identificador) =>
      _entrar('/auth/dev', {'id': identificador});

  void sair() {
    token = null;
    usuarioId = null;
    nome = null;
  }

  Future<void> _entrar(String caminho, Map<String, dynamic> corpo) async {
    final resposta = await http
        .post(
          BackendService.uriRaiz(caminho),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(corpo),
        )
        .timeout(const Duration(seconds: 30));

    final json = resposta.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(resposta.body) as Map<String, dynamic>;
    if (resposta.statusCode != 200) {
      throw BackendException(
        json['detail']?.toString() ?? 'Falha no login (${resposta.statusCode}).',
        statusCode: resposta.statusCode,
      );
    }
    token = json['token'] as String;
    final usuario = json['usuario'] as Map<String, dynamic>? ?? const {};
    usuarioId = usuario['id'] as String?;
    nome = usuario['nome'] as String?;
  }
}
