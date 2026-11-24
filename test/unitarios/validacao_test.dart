// Tradução dos erros 422 do FastAPI (CT-FUNC-03): a tela não mostra mais a
// lista técnica em inglês.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/services/backend_service.dart';
import 'package:http/http.dart' as http;

void main() {
  test('cada tipo de erro vira uma frase em português', () {
    final msg = mensagemDeValidacao([
      {'type': 'less_than_equal', 'loc': ['body', 'minutos_ligado'], 'ctx': {'le': 1440}},
      {'type': 'greater_than_equal', 'loc': ['body', 'minutos_desligado'], 'ctx': {'ge': 1}},
      {'type': 'string_too_long', 'loc': ['body', 'cultura'], 'ctx': {'max_length': 100}},
      {'type': 'missing', 'loc': ['body', 'nome']},
      {'type': 'outro', 'loc': []},
      'lixo',
    ]);
    expect(msg, 'Dados inválidos: minutos_ligado deve ser no máximo 1440; '
        'minutos_desligado deve ser no mínimo 1; cultura pode ter no máximo 100 caracteres; '
        'nome é obrigatório; campo com valor inválido.');
    expect(mensagemDeValidacao(const []), 'Dados inválidos.');
  });

  test('resposta 422 com lista vira BackendException legível', () {
    final r = http.Response(
        '{"detail":[{"type":"less_than_equal","loc":["body","minutos_ligado"],"ctx":{"le":1440}}]}', 422);
    expect(
      () => decodificarResposta(r),
      throwsA(isA<BackendException>()
          .having((e) => e.message, 'message', contains('no máximo 1440'))
          .having((e) => e.statusCode, 'statusCode', 422)),
    );
  });
}
