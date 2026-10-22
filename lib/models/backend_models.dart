class SensorSnapshot {
  final double? ph;
  final double? ec;
  final double? tds;
  final double? temperaturaAgua;
  final double? temperaturaAmbiente;
  final double? umidadeRelativa;
  final double? nivelAgua;
  final List<String> alertas;
  final DateTime? recebidoEm;

  const SensorSnapshot({
    required this.ph,
    required this.ec,
    this.tds,
    required this.temperaturaAgua,
    required this.temperaturaAmbiente,
    required this.umidadeRelativa,
    required this.nivelAgua,
    required this.alertas,
    required this.recebidoEm,
  });

  factory SensorSnapshot.fromJson(Map<String, dynamic> json) {
    final dados = json['dados'] as Map<String, dynamic>? ?? {};
    final alertas = json['alertas'] as List<dynamic>? ?? const [];

    return SensorSnapshot(
      ph: _toDouble(dados['ph']),
      ec: _firstDouble(dados, const ['ec', 'tds']),
      tds: _toDouble(dados['tds']),
      temperaturaAgua: _firstDouble(dados, const [
        'temperaturaAgua',
        'temperatura',
      ]),
      temperaturaAmbiente: _firstDouble(dados, const [
        'temperaturaAmbiente',
        'temperatura',
      ]),
      umidadeRelativa: _firstDouble(dados, const [
        'umidadeRelativa',
        'umidade',
      ]),
      // So 'nivelAgua': o fallback antigo para 'umidade' mostrava a umidade
      // do ar como se fosse o nivel do tanque.
      nivelAgua: _toDouble(dados['nivelAgua']),
      alertas: alertas.map((alerta) => alerta.toString()).toList(),
      recebidoEm: DateTime.tryParse(json['recebidoEm']?.toString() ?? ''),
    );
  }

  static double? _firstDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = _toDouble(json[key]);
      if (value != null) return value;
    }
    return null;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class MotorStatus {
  final Map<String, dynamic> raw;
  final DateTime? recebidoEm;

  const MotorStatus({required this.raw, required this.recebidoEm});

  factory MotorStatus.fromJson(Map<String, dynamic> json) {
    return MotorStatus(
      raw: json,
      recebidoEm: DateTime.tryParse(json['recebidoEm']?.toString() ?? ''),
    );
  }

  String get resumo {
    if (raw.isEmpty) return 'Sem status recebido';

    final ligado = raw['ligado'] ?? raw['motorLigado'] ?? raw['ativo'];
    final acao = raw['acao'] ?? raw['estado'] ?? raw['status'];

    if (ligado is bool) return ligado ? 'Ligado' : 'Desligado';
    if (acao != null) return acao.toString();
    return raw.entries
        .where((entry) => entry.key != 'recebidoEm')
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ');
  }
}
