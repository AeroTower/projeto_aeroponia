import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'backend_service.dart';

/// Cliente do microsserviço de IA (microsservico_IA, POST /analisar-cultivo).
///
/// Antes esta chamada morava no BackendService, com o endereço escrito no
/// código. A IA é outro serviço, com outro endereço: agora cada um tem o
/// seu cliente, e o endereço vem do config (IA_BASE_URL).
class IaService {
  final http.Client _client;
  final String baseUrl;

  IaService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? AppConfig.iaBaseUrl;

  /// Sugestões da IA, uma por linha. Sem sugestões, o diagnóstico ou o
  /// status. Erro do serviço vira [BackendException] com a mensagem dele.
  Future<String> analisarCultivo({
    required String cultura,
    required double ph,
    required double temperatura,
    required double umidade,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/analisar-cultivo'),
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
        )
        .timeout(const Duration(seconds: 30));

    final body = decodificarResposta(response) as Map<String, dynamic>;
    if (body['sugestoes_acao'] is List) {
      return (body['sugestoes_acao'] as List).join('\n');
    }
    return body['diagnostico_breve']?.toString() ??
        'Status do sistema: ${body['status_sistema']}';
  }

  void close() => _client.close();
}
