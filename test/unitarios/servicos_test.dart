// Testes unitários dos serviços HTTP, com o servidor trocado por um dublê.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/plants_screen.dart';
import 'package:hidro_app/services/backend_service.dart';
import 'package:hidro_app/services/sessao.dart';
import 'package:image_picker/image_picker.dart';

import '../apoio.dart';

void main() {
  tearDown(Sessao.instance.sair);

  group('BackendService', () {
    late ServidorFalso servidor;
    BackendService backend({String? torreId = idTorre, String baseUrl = 'https://backend.teste/'}) =>
        BackendService(client: servidor.cliente, baseUrl: baseUrl, torreId: torreId);

    setUp(() => servidor = servidorComTorre());

    test('com torre, usa as rotas /torres/{id}/... e manda o token', () async {
      logar();
      final dados = await backend().getDados();
      expect(dados.ph, 6.1);
      final pedido = servidor.para('GET /torres/$idTorre/dados').single;
      expect(pedido.url.host, 'backend.teste');
      expect(pedido.headers['Authorization'], 'Bearer token-de-sessao');
    });

    test('sem torre, usa as rotas antigas e a base terminada em /dados', () async {
      servidor.quando('GET /dados', dadosJson());
      servidor.quando('GET /motor/status', {'ligado': false});
      final legado = backend(torreId: null, baseUrl: 'https://backend.teste/dados');
      expect((await legado.getDados()).ph, 6.1);
      expect((await legado.getMotorStatus()).resumo, 'Desligado');
      expect(servidor.pedidos.map((p) => p.url.toString()),
          ['https://backend.teste/dados', 'https://backend.teste/motor/status']);
    });

    test('lista as torres e lê o estado da torre', () async {
      final b = backend();
      expect((await b.listarTorres()).single.kit, 'pro');
      expect((await b.getTorre()).online, isTrue);
    });

    test('sem torre selecionada não pede o estado', () async {
      await expectLater(backend(torreId: null).getTorre(), throwsA(isA<BackendException>()));
    });

    test('thresholds: lê e atualiza', () async {
      servidor.quando('GET /torres/$idTorre/thresholds', {'phMin': 5.5, 'phMax': 6});
      servidor.quando('POST /torres/$idTorre/thresholds', {'thresholds': {'phMin': 5.0, 'phMax': 7}});
      final b = backend();
      expect(await b.getThresholds(), {'phMin': 5.5, 'phMax': 6.0});
      expect(await b.updateThresholds({'phMin': 5.0}), {'phMin': 5.0, 'phMax': 7.0});
      expect(jsonDecode(servidor.para('POST /torres/$idTorre/thresholds').single.body), {'phMin': 5.0});
    });

    test('comandos da bomba mandam o corpo que o Backend espera', () async {
      final b = backend();
      await b.iniciarCiclo(minutosLigado: 10, minutosDesligado: 50);
      await b.desligarMotor();
      expect(jsonDecode(servidor.para('POST /torres/$idTorre/motor/ciclo').single.body),
          {'minutos_ligado': 10, 'minutos_desligado': 50});
      expect(servidor.para('POST /torres/$idTorre/motor/desligar'), hasLength(1));
      b.close();
    });

    test('erro do Backend vira BackendException com a mensagem dele', () async {
      servidor.quando('GET /torres/$idTorre/dados', {'detail': 'Torre não encontrada.'}, status: 404);
      await expectLater(
        backend().getDados(),
        throwsA(isA<BackendException>()
            .having((e) => e.statusCode, 'status', 404)
            .having((e) => e.toString(), 'mensagem', 'Torre não encontrada.')),
      );
    });

    test('erro sem detalhe usa uma mensagem genérica', () async {
      servidor.quandoFn('GET /torres/$idTorre/dados', (_) => resposta('', status: 502));
      await expectLater(backend().getDados(),
          throwsA(isA<BackendException>().having((e) => e.message, 'm', contains('502'))));
    });

    group('IA', () {
      test('devolve as sugestões, uma por linha', () async {
        servidor.quando('POST /analisar-cultivo', {'sugestoes_acao': ['Baixe o pH', 'Troque a água']});
        final r = await backend().analisarCultivoIA(cultura: 'Alface', ph: 7.5, temperatura: 22, umidade: 60);
        expect(r, 'Baixe o pH\nTroque a água');
        final pedido = servidor.para('POST /analisar-cultivo').single;
        expect(pedido.url.host, 'hidroponia-ia.azurewebsites.net');
        expect(jsonDecode(pedido.body), {'cultura': 'Alface', 'ph': 7.5, 'temperatura': 22, 'umidade': 60});
      });

      test('sem sugestões, mostra o diagnóstico ou o status', () async {
        servidor.quando('POST /analisar-cultivo', {'diagnostico_breve': 'Tudo certo.'});
        expect(await backend().analisarCultivoIA(cultura: 'A', ph: 6, temperatura: 22, umidade: 60), 'Tudo certo.');
        servidor.quando('POST /analisar-cultivo', {'status_sistema': 'Normal'});
        expect(await backend().analisarCultivoIA(cultura: 'A', ph: 6, temperatura: 22, umidade: 60),
            'Status do sistema: Normal');
      });
    });

    test('uriRaiz monta o endereço na raiz do Backend', () {
      expect(BackendService.uriRaiz('/torres').path, endsWith('/torres'));
      expect(BackendService.uriRaiz('/torres').path, isNot(contains('/dados')));
    });
  });

  group('Sessao', () {
    test('login de desenvolvimento guarda o token e o que o auth respondeu', () async {
      final servidor = ServidorFalso()..quando('POST /auth/dev', loginJson());
      await servidor.rodar(() => Sessao.instance.entrarDev('demo'));
      final s = Sessao.instance;
      expect(s.logado, isTrue);
      expect(s.headers, {'Authorization': 'Bearer token-de-sessao'});
      expect([s.usuarioId, s.nome, s.email, s.possuiTorre, s.torreId],
          ['google:123', 'Ana', 'ana@exemplo.com', true, idTorre]);
      expect(jsonDecode(servidor.para('POST /auth/dev').single.body), {'id': 'demo'});
    });

    test('login com Google manda o token do Google ao serviço de auth', () async {
      final servidor = ServidorFalso()..quando('POST /auth/google', loginJson(possuiTorre: false));
      await servidor.rodar(() => Sessao.instance.entrarComGoogle('id-token'));
      expect(jsonDecode(servidor.para('POST /auth/google').single.body), {'token': 'id-token'});
      expect(Sessao.instance.possuiTorre, isFalse);
    });

    test('login recusado mostra a mensagem do servidor', () async {
      final servidor = ServidorFalso()..quando('POST /auth/google', {'detail': 'Token do Google inválido'}, status: 401);
      await expectLater(servidor.rodar(() => Sessao.instance.entrarComGoogle('x')),
          throwsA(isA<BackendException>().having((e) => e.message, 'm', 'Token do Google inválido')));
      expect(Sessao.instance.logado, isFalse);
    });

    test('login recusado sem corpo', () async {
      final servidor = ServidorFalso()..quandoFn('POST /auth/dev', (_) => resposta('', status: 500));
      await expectLater(servidor.rodar(() => Sessao.instance.entrarDev('x')),
          throwsA(isA<BackendException>().having((e) => e.message, 'm', contains('500'))));
    });

    test('desvincular tira a torre da sessão', () async {
      logar();
      Sessao.instance
        ..possuiTorre = true
        ..torreId = idTorre;
      final servidor = ServidorFalso()..quando('DELETE /torre/$idTorre/vinculo', {'status': 'success'});
      await servidor.rodar(() => Sessao.instance.desvincularTorre(idTorre));
      expect(Sessao.instance.torreId, isNull);
      expect(Sessao.instance.possuiTorre, isFalse);
    });

    test('desvincular outra torre não mexe na torre da sessão', () async {
      logar();
      Sessao.instance.torreId = idTorre;
      final servidor = ServidorFalso()..quando('DELETE /torre/AT-OUTRA0001/vinculo', {'status': 'success'});
      await servidor.rodar(() => Sessao.instance.desvincularTorre('AT-OUTRA0001'));
      expect(Sessao.instance.torreId, idTorre);
    });

    test('desvincular com erro, com e sem detalhe', () async {
      logar();
      final servidor = ServidorFalso()
        ..quando('DELETE /torre/$idTorre/vinculo', {'detail': 'Torre não encontrada.'}, status: 404)
        ..quandoFn('DELETE /torre/AT-OUTRA0001/vinculo', (_) => resposta('<html>', status: 502));
      await expectLater(servidor.rodar(() => Sessao.instance.desvincularTorre(idTorre)),
          throwsA(isA<BackendException>().having((e) => e.message, 'm', 'Torre não encontrada.')));
      await expectLater(servidor.rodar(() => Sessao.instance.desvincularTorre('AT-OUTRA0001')),
          throwsA(isA<BackendException>().having((e) => e.statusCode, 's', 502)));
    });

    test('sair apaga tudo', () {
      logar();
      Sessao.instance.sair();
      expect(Sessao.instance.logado, isFalse);
      expect(Sessao.instance.headers, isEmpty);
    });
  });

  group('PlantaService', () {
    test('lista, cria (com e sem foto) e apaga', () async {
      logar();
      final servidor = servidorComTorre()
        ..quando('POST /torres/$idTorre/plantas', plantaJson(9, 'Rúcula'), status: 201)
        ..quando('DELETE /torres/$idTorre/plantas/9', {'sucesso': true});
      await servidor.rodar(() async {
        expect((await PlantaService.listar(idTorre)).map((p) => p.nome), ['Alface', 'Manjericão']);
        final criada = await PlantaService.criar(
            torreId: idTorre, nome: 'Rúcula', tipo: 'Folhosa', dataPlantio: '2026-11-21');
        expect(criada.id, 9);
        await PlantaService.criar(
          torreId: idTorre, nome: 'Rúcula', tipo: 'Folhosa', dataPlantio: '2026-11-21',
          fotoXFile: XFile.fromData(utf8.encode('img'), name: 'rucula.jpg', path: 'rucula.jpg'),
        );
        await PlantaService.deletar(idTorre, 9);
      });
      final envios = servidor.para('POST /torres/$idTorre/plantas');
      expect(envios.first.headers['Authorization'], 'Bearer token-de-sessao');
      expect(envios.first.body, contains('name="nome"'));
      expect(envios.last.body, contains('filename="rucula.jpg"'));
    });

    test('erros do Backend viram exceção', () async {
      final servidor = ServidorFalso()
        ..quando('GET /torres/$idTorre/plantas', {'detail': 'x'}, status: 404)
        ..quando('POST /torres/$idTorre/plantas', {'detail': 'x'}, status: 400)
        ..quando('DELETE /torres/$idTorre/plantas/1', {'detail': 'x'}, status: 404);
      await servidor.rodar(() async {
        await expectLater(PlantaService.listar(idTorre), throwsException);
        await expectLater(
            PlantaService.criar(torreId: idTorre, nome: 'a', tipo: 'b', dataPlantio: 'c'), throwsException);
        await expectLater(PlantaService.deletar(idTorre, 1), throwsException);
      });
    });
  });
}
