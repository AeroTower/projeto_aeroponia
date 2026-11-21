import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'backend_service.dart';

/// Guarda o token de sessão enquanto o app está aberto.
///
/// Quem emite o token é o serviço de autenticação (auth-aerotower); o
/// Backend aceita o mesmo token. Então: login uma vez, mesmo header nos dois.
class Sessao {
  Sessao._();
  static final Sessao instance = Sessao._();

  String? token;
  String? usuarioId;
  String? nome;
  String? email;

  /// O que o serviço de auth respondeu no login (campos do Rafael).
  bool possuiTorre = false;
  String? torreId;

  bool get logado => token != null;

  Map<String, String> get headers =>
      token == null ? const {} : {'Authorization': 'Bearer $token'};

  /// [tokenGoogle]: idToken no celular, accessToken na web.
  Future<void> entrarComGoogle(String tokenGoogle) =>
      _entrar('/auth/google', {'token': tokenGoogle});

  Future<void> entrarDev(String identificador) =>
      _entrar('/auth/dev', {'id': identificador});

  /// Vincula a torre do adesivo à conta de quem está logado
  /// (POST /torre/vincular no serviço de auth). O dono é quem manda o token:
  /// o e-mail não vai no corpo, senão qualquer um vincularia em nome de outro.
  /// Devolve o id da torre; erro do auth (400/409) vira [BackendException]
  /// com a mensagem dele.
  Future<String?> vincularTorre(String codigo) async {
    final resposta = await http
        .post(
          Uri.parse('${AppConfig.authBaseUrl}/torre/vincular'),
          headers: {'Content-Type': 'application/json', ...headers},
          body: jsonEncode({'codigo': codigo}),
        )
        .timeout(const Duration(seconds: 30));
    final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
    if (resposta.statusCode != 200 && resposta.statusCode != 201) {
      throw BackendException(
        corpo['detail']?.toString() ?? 'Erro ao vincular torre.',
        statusCode: resposta.statusCode,
      );
    }
    return corpo['torre_id'] as String?;
  }

  /// Tira a torre da conta (DELETE /torre/{id}/vinculo no serviço de auth).
  /// O código do adesivo volta a valer: dá para vincular de novo, ou passar
  /// a torre para outra pessoa. O Backend fica sabendo pelo RabbitMQ.
  Future<void> desvincularTorre(String torreId) async {
    final resposta = await http
        .delete(
          Uri.parse('${AppConfig.authBaseUrl}/torre/$torreId/vinculo'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));
    if (resposta.statusCode != 200) {
      String? detalhe;
      try {
        detalhe = (jsonDecode(resposta.body) as Map<String, dynamic>)['detail']?.toString();
      } catch (_) {}
      throw BackendException(
        detalhe ?? 'Não foi possível remover a torre (${resposta.statusCode}).',
        statusCode: resposta.statusCode,
      );
    }
    if (this.torreId == torreId) {
      this.torreId = null;
      possuiTorre = false;
    }
  }

  void sair() {
    token = null;
    usuarioId = null;
    nome = null;
    email = null;
    possuiTorre = false;
    torreId = null;
  }

  Future<void> _entrar(String caminho, Map<String, dynamic> corpo) async {
    final resposta = await http
        .post(
          Uri.parse('${AppConfig.authBaseUrl}$caminho'),
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
    email = usuario['email'] as String?;
    possuiTorre = json['possui_torre'] as bool? ?? false;
    torreId = json['torre_id'] as String?;
  }
}
