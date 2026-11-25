// Testes unitários dos modelos: como o app lê o JSON do Backend.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/models/backend_models.dart';
import 'package:hidro_app/models/torre.dart';
import 'package:hidro_app/models/planta.dart';

void main() {
  group('SensorSnapshot', () {
    test('lê os nomes novos dos sensores', () {
      final s = SensorSnapshot.fromJson({
        'dados': {'ph': 6.2, 'ec': 1.4, 'tds': 700, 'temperaturaAgua': 21, 'temperaturaAmbiente': 25,
                  'umidadeRelativa': 61, 'nivelAgua': 55},
        'alertas': ['pH acima'],
        'recebidoEm': '2026-11-21T16:00:00',
      });
      expect(s.ph, 6.2);
      expect(s.ec, 1.4);
      expect(s.tds, 700);
      expect(s.temperaturaAgua, 21);
      expect(s.temperaturaAmbiente, 25);
      expect(s.umidadeRelativa, 61);
      expect(s.nivelAgua, 55);
      expect(s.alertas, ['pH acima']);
      expect(s.recebidoEm, DateTime(2026, 11, 21, 16));
    });

    test('aceita os nomes do firmware antigo e números em texto', () {
      final s = SensorSnapshot.fromJson({
        'dados': {'ph': '6.5', 'tds': 900, 'temperatura': 23, 'umidade': 70},
      });
      expect(s.ph, 6.5);
      expect(s.ec, 900, reason: 'sem "ec", usa o "tds"');
      expect(s.temperaturaAgua, 23);
      expect(s.temperaturaAmbiente, 23);
      expect(s.umidadeRelativa, 70);
      expect(s.nivelAgua, isNull, reason: 'umidade do ar não vira nível do tanque');
      expect(s.alertas, isEmpty);
      expect(s.recebidoEm, isNull);
    });

    test('sem o campo dados não quebra', () {
      final s = SensorSnapshot.fromJson({});
      expect(s.ph, isNull);
      expect(s.ec, isNull);
    });
  });

  group('MotorStatus.resumo', () {
    test('ligado e desligado', () {
      expect(MotorStatus.fromJson({'ligado': true}).resumo, 'Ligado');
      expect(MotorStatus.fromJson({'motorLigado': false}).resumo, 'Desligado');
    });

    test('usa a ação quando não há campo booleano', () {
      expect(MotorStatus.fromJson({'acao': 'ciclo'}).resumo, 'ciclo');
    });

    test('mostra os campos crus como último recurso', () {
      final status = MotorStatus.fromJson({'rpm': 1200, 'recebidoEm': '2026-11-21T16:00:00'});
      expect(status.resumo, 'rpm: 1200');
      expect(status.recebidoEm, DateTime(2026, 11, 21, 16));
    });

    test('sem nada recebido', () {
      expect(const MotorStatus(raw: {}, recebidoEm: null).resumo, 'Sem status recebido');
    });
  });

  group('Torre', () {
    test('lê o JSON e decide pelas capacidades do kit', () {
      final t = Torre.fromJson({
        'id': 'AT-24DCC3A1B2C4', 'apelido': 'Varanda', 'kit': 'completo',
        'capacidades': ['bomba', 'nivel'], 'online': true, 'firmware': '2.0.0',
        'ultimaLeituraEm': '2026-11-21T16:00:00',
      });
      expect(t.nome, 'Varanda');
      expect(t.kitNome, 'Kit Completo');
      expect(t.tem('nivel'), isTrue);
      expect(t.tem('ph'), isFalse);
      expect(t.online, isTrue);
      expect(t.firmware, '2.0.0');
      expect(t.ultimaLeituraEm, isNotNull);
      expect(t.redeConfiguracao, 'AeroTower-B2C4');
    });

    test('sem apelido o nome é o id; kit desconhecido vira Pro', () {
      final t = Torre.fromJson({'id': 'AT-1A2B', 'apelido': ''});
      expect(t.nome, 'AT-1A2B');
      expect(t.kit, 'pro');
      expect(t.kitNome, 'Kit Pro');
      expect(t.capacidades, isEmpty);
      expect(t.ultimaLeituraEm, isNull);
      expect(Torre.fromJson({'id': 'AT-1', 'kit': 'basico'}).kitNome, 'Kit Básico');
    });

    test('rede de configuração de id curto', () {
      expect(const Torre(id: 'AT', kit: 'pro', capacidades: []).redeConfiguracao, 'AeroTower-AT');
    });
  });

  test('Plant lê a planta do Backend', () {
    final p = Plant.fromJson({'id': 3, 'nome': 'Rúcula', 'tipo': 'Folhosa', 'data_plantio': '2026-11-01',
                              'foto_url': '/static/fotos/x.jpg'});
    expect([p.id, p.nome, p.tipo, p.dataPlantio, p.fotoUrl],
        [3, 'Rúcula', 'Folhosa', '2026-11-01', '/static/fotos/x.jpg']);
  });
}
