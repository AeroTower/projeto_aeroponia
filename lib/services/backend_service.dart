import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/backend_models.dart';
import '../models/torre.dart';
import 'sessao.dart';

class BackendException implements Exception {
  final String message;
  final int? statusCode;

  const BackendException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Corpo JSON de uma resposta 2xx. Fora disso, [BackendException] com o
/// "detail" do servidor (FastAPI) ou uma mensagem com o status.
dynamic decodificarResposta(http.Response response) {
  final dynamic body = response.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(response.body);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return body;
  }

  final detail = body is Map ? body['detail']?.toString() : null;
  throw BackendException(
    detail?.isNotEmpty == true
        ? detail!
        : 'Backend retornou erro ${response.statusCode}.',
    statusCode: response.statusCode,
  );
}

class BackendService {
  static const defaultBaseUrl =
      'https://aerotower-backend-bfb7frgsbccuanhf.eastus-01.azurewebsites.net/dados';

  static const _configuredBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  final http.Client _client;
  final String baseUrl;

  /// Torre que este serviço comanda. Nulo = rotas antigas (torre única,
  /// sem login), que o back-end mantém só durante a transição.
  final String? torreId;

  BackendService({http.Client? client, String? baseUrl, this.torreId})
    : _client = client ?? http.Client(),
      baseUrl = _normalizeBaseUrl(baseUrl ?? _configuredBaseUrl);

  /// URI na raiz do back-end, para quem não tem uma instância (login).
  static Uri uriRaiz(String path) {
    final base = _normalizeBaseUrl(_configuredBaseUrl);
    final raiz = base.endsWith('/dados')
        ? base.substring(0, base.length - '/dados'.length)
        : base;
    return Uri.parse('$raiz$path');
  }

  /// '/dados' -> '/torres/AT-.../dados' quando há torre selecionada.
  String _rota(String path) => torreId == null ? path : '/torres/$torreId$path';

  Uri _uri(String path) {
    if (baseUrl.endsWith('/dados')) {
      final root = baseUrl.substring(0, baseUrl.length - '/dados'.length);
      return Uri.parse(path == '/dados' ? baseUrl : '$root$path');
    }
    return Uri.parse('$baseUrl$path');
  }

  // ── Torres ──────────────────────────────────────────────────────────────

  Future<List<Torre>> listarTorres() async {
    final response = await _client
        .get(_uri('/torres'), headers: Sessao.instance.headers)
        .timeout(const Duration(seconds: 30));
    final body = _decodeAny(response);
    return (body as List<dynamic>)
        .map((t) => Torre.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Estado atual da torre selecionada (online, firmware, última leitura).
  Future<Torre> getTorre() async {
    final id = torreId;
    if (id == null) {
      throw const BackendException('Nenhuma torre selecionada.');
    }
    return Torre.fromJson(await _getJson('/torres/$id'));
  }

  // ── Sensores e bomba ────────────────────────────────────────────────────

  Future<SensorSnapshot> getDados() async {
    final json = await _getJson(_rota('/dados'));
    return SensorSnapshot.fromJson(json);
  }

  Future<Map<String, double>> getThresholds() async {
    final json = await _getJson(_rota('/thresholds'));
    return json.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  Future<Map<String, double>> updateThresholds(
    Map<String, double> thresholds,
  ) async {
    final json = await _postJson(_rota('/thresholds'), thresholds);
    final updated = json['thresholds'] as Map<String, dynamic>? ?? {};
    return updated.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );
  }

  Future<MotorStatus> getMotorStatus() async {
    final json = await _getJson(_rota('/motor/status'));
    return MotorStatus.fromJson(json);
  }

  Future<void> iniciarCiclo({
    required int minutosLigado,
    required int minutosDesligado,
  }) async {
    await _postJson(_rota('/motor/ciclo'), {
      'minutos_ligado': minutosLigado,
      'minutos_desligado': minutosDesligado,
    });
  }

  Future<void> desligarMotor() async {
    await _postJson(_rota('/motor/desligar'), const {});
  }

  void close() {
    _client.close();
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _client
        .get(_uri(path), headers: Sessao.instance.headers)
        .timeout(const Duration(seconds: 5));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          _uri(path),
          headers: {
            'Content-Type': 'application/json',
            ...Sessao.instance.headers,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    return _decodeAny(response) as Map<String, dynamic>;
  }

  dynamic _decodeAny(http.Response response) => decodificarResposta(response);

  static String _normalizeBaseUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
