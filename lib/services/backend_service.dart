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

  Future<Torre> ativarTorre(String codigo, {String? apelido}) async {
    final json = await _postJson('/torres/ativar', {
      'codigo': codigo,
      if (apelido != null && apelido.trim().isNotEmpty) 'apelido': apelido.trim(),
    });
    return Torre.fromJson(json);
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

  dynamic _decodeAny(http.Response response) {
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

  static String _normalizeBaseUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

Future<String> analisarCultivoIA({
    required String cultura,
    required double ph,
    required double temperatura,
    required double umidade,
  }) async {
    // URL específica do seu microserviço de IA
    final uri = Uri.parse('https://hidroponia-ia.azurewebsites.net/analisar-cultivo');

    final response = await _client.post(
      uri,
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'cultura': cultura,
        'ph': ph,
        'temperatura': temperatura,
        'umidade': umidade,
      }),
    ).timeout(const Duration(seconds: 30));

    // Reaproveita o seu tratamento de erro nativo (lança BackendException se falhar)
    final body = _decodeResponse(response);

    // Retorna a lista de sugestões formatada, ou o diagnóstico/status como fallback
    if (body['sugestoes_acao'] is List) {
      return (body['sugestoes_acao'] as List).join('\n');
    }
    
    return body['diagnostico_breve']?.toString() ?? 'Status do sistema: ${body['status_sistema']}';
  }
}
