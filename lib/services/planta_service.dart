import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/planta.dart';
import 'backend_service.dart';
import 'sessao.dart';

export '../models/planta.dart';

/// Plantas de quem está logado, na torre [torreId] (/torres/{id}/plantas).
/// Se a torre passar para outra pessoa, ela não vê as plantas de quem saiu.
class PlantaService {
  /// Endereço completo da foto. Mesmo servidor do BackendService
  /// (BACKEND_BASE_URL do config/*.json): um lugar só para trocar.
  static String? urlDaFoto(Plant planta) =>
      planta.fotoUrl == null ? null : '${BackendService.uriRaiz('')}${planta.fotoUrl}';

  static Uri _uri(String torreId, [String resto = '']) =>
      BackendService.uriRaiz('/torres/$torreId/plantas$resto');

  static Future<List<Plant>> listar(String torreId) async {
    final response = await http.get(_uri(torreId), headers: Sessao.instance.headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Plant.fromJson(e)).toList();
    }
    throw Exception('Erro ao carregar plantas');
  }

  // Usa XFile para compatibilidade com Web e Mobile
  static Future<Plant> criar({
    required String torreId,
    required String nome,
    required String tipo,
    required String dataPlantio,
    XFile? fotoXFile,
  }) async {
    final request = http.MultipartRequest('POST', _uri(torreId))
      ..headers.addAll(Sessao.instance.headers);
    request.fields['nome']         = nome;
    request.fields['tipo']         = tipo;
    request.fields['data_plantio'] = dataPlantio;

    if (fotoXFile != null) {
      final bytes = await fotoXFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto',
          bytes,
          filename: fotoXFile.name,
        ),
      );
    }

    final response = await request.send();
    final body     = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return Plant.fromJson(jsonDecode(body));
    }
    throw Exception('Erro ao cadastrar planta');
  }

  static Future<void> deletar(String torreId, int id) async {
    final response = await http.delete(
      _uri(torreId, '/$id'),
      headers: Sessao.instance.headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao remover planta');
    }
  }
}
