/// Uma torre ligada à conta. O que o painel mostra depende de [capacidades]:
/// `bomba` (todas), `nivel` (Completo e Pro), `ph`, `tds` e `clima` (Pro).
class Torre {
  final String id;
  final String? apelido;
  final String kit;
  final List<String> capacidades;
  final bool? online;
  final String? firmware;

  const Torre({
    required this.id,
    required this.kit,
    required this.capacidades,
    this.apelido,
    this.online,
    this.firmware,
  });

  factory Torre.fromJson(Map<String, dynamic> json) {
    return Torre(
      id: json['id'] as String,
      apelido: json['apelido'] as String?,
      kit: json['kit'] as String? ?? 'pro',
      capacidades: (json['capacidades'] as List<dynamic>? ?? const [])
          .map((c) => c.toString())
          .toList(),
      online: json['online'] as bool?,
      firmware: json['firmware'] as String?,
    );
  }

  bool tem(String capacidade) => capacidades.contains(capacidade);

  String get nome => (apelido != null && apelido!.isNotEmpty) ? apelido! : id;

  String get kitNome {
    switch (kit) {
      case 'basico':
        return 'Kit Básico';
      case 'completo':
        return 'Kit Completo';
      default:
        return 'Kit Pro';
    }
  }
}
