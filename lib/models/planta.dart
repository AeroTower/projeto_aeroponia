/// Planta cadastrada numa torre (vem do Backend, /torres/{id}/plantas).
class Plant {
  final int     id;
  final String  nome;
  final String  tipo;
  final String  dataPlantio;
  final String? fotoUrl;

  const Plant({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.dataPlantio,
    this.fotoUrl,
  });

  factory Plant.fromJson(Map<String, dynamic> json) => Plant(
    id:          json['id'],
    nome:        json['nome'],
    tipo:        json['tipo'],
    dataPlantio: json['data_plantio'],
    fotoUrl:     json['foto_url'],
  );
}
