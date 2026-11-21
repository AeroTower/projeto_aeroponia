// Apoio dos testes: servidor falso (Backend, auth e IA), dublês do Google e da
// galeria, e um jeito único de montar as telas.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:hidro_app/models/torre.dart';
import 'package:hidro_app/services/sessao.dart';
import 'package:hidro_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Faz o papel do Backend, do serviço de auth e da IA ao mesmo tempo.
///
/// As rotas são "MÉTODO /caminho" (o host não importa); cada pedido fica em
/// [pedidos] para o teste conferir o que o app mandou.
class ServidorFalso {
  final pedidos = <http.Request>[];
  final _rotas = <String, http.Response Function(http.Request)>{};

  /// Responde [corpo] (vira JSON) com o [status] na [rota].
  void quando(String rota, Object? corpo, {int status = 200}) {
    _rotas[rota] = (_) => resposta(corpo, status: status);
  }

  /// Responde com uma função (para respostas que mudam a cada chamada).
  void quandoFn(String rota, http.Response Function(http.Request) fn) {
    _rotas[rota] = fn;
  }

  /// Simula a rede caída nesta rota.
  void caiu(String rota) {
    _rotas[rota] = (_) => throw http.ClientException('rede fora do ar');
  }

  Future<http.Response> _responder(http.Request pedido) async {
    pedidos.add(pedido);
    final rota = '${pedido.method} ${pedido.url.path}';
    final fn = _rotas[rota];
    if (fn == null) return resposta({'detail': 'rota não simulada: $rota'}, status: 404);
    return fn(pedido);
  }

  http.Client get cliente => MockClient(_responder);

  /// Pedidos feitos para uma rota ("GET /torres").
  List<http.Request> para(String rota) =>
      pedidos.where((p) => '${p.method} ${p.url.path}' == rota).toList();

  /// Roda [corpo] com todo `http` do app apontando para este servidor.
  Future<T> rodar<T>(Future<T> Function() corpo) => http.runWithClient(corpo, () => cliente);
}

http.Response resposta(Object? corpo, {int status = 200}) => http.Response.bytes(
      utf8.encode(corpo is String ? corpo : jsonEncode(corpo)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

// ── Dados de exemplo ────────────────────────────────────────────────────────

const idTorre = 'AT-24DCC3A1B2C4';

Map<String, dynamic> torreJson({
  String id = idTorre,
  String kit = 'pro',
  List<String>? capacidades,
  bool? online = true,
  String? apelido = 'Varanda',
  String? ultimaLeituraEm = '2026-11-21T16:00:00',
}) =>
    {
      'id': id,
      'apelido': apelido,
      'kit': kit,
      'capacidades': capacidades ??
          {
            'basico': ['bomba'],
            'completo': ['bomba', 'nivel'],
            'pro': ['bomba', 'nivel', 'ph', 'tds', 'clima'],
          }[kit],
      'online': online,
      'firmware': '2.0.0',
      'ultimaLeituraEm': ultimaLeituraEm,
    };

Torre torre({String kit = 'pro', bool? online = true, String? ultimaLeituraEm = '2026-11-21T16:00:00'}) =>
    Torre.fromJson(torreJson(kit: kit, online: online, ultimaLeituraEm: ultimaLeituraEm));

Map<String, dynamic> dadosJson({
  Map<String, dynamic>? dados,
  List<String> alertas = const [],
}) =>
    {
      'torreId': idTorre,
      'dados': dados ??
          {'ph': 6.1, 'tds': 800, 'temperaturaAmbiente': 24.0, 'umidadeRelativa': 60, 'nivelAgua': 80},
      'alertas': alertas,
      'recebidoEm': '2026-11-21T16:05:09',
    };

const motorJson = {
  'ligado': true,
  'ciclo_ativo': true,
  'minutos_ligado': 15,
  'minutos_desligado': 45,
  'recebidoEm': '2026-11-21T16:05:00',
};

Map<String, dynamic> plantaJson(int id, String nome, {String? foto}) => {
      'id': id,
      'nome': nome,
      'tipo': 'Folhosa',
      'data_plantio': '2026-11-01',
      'foto_url': foto,
    };

/// Servidor com uma torre Pro funcionando, do jeito que o painel espera.
ServidorFalso servidorComTorre({String kit = 'pro', List<String> alertas = const []}) {
  final s = ServidorFalso()
    ..quando('GET /torres', [torreJson(kit: kit)])
    ..quando('GET /torres/$idTorre', torreJson(kit: kit))
    ..quando('GET /torres/$idTorre/dados', dadosJson(alertas: alertas))
    ..quando('GET /torres/$idTorre/motor/status', motorJson)
    ..quando('POST /torres/$idTorre/motor/ciclo', {'sucesso': true})
    ..quando('POST /torres/$idTorre/motor/desligar', {'sucesso': true})
    ..quando('GET /torres/$idTorre/plantas', [plantaJson(1, 'Alface'), plantaJson(2, 'Manjericão')]);
  return s;
}

// ── Sessão ──────────────────────────────────────────────────────────────────

/// Deixa a sessão como depois de um login, e limpa no fim do teste.
void logar({String token = 'token-de-sessao'}) {
  Sessao.instance
    ..token = token
    ..usuarioId = 'google:123'
    ..nome = 'Ana'
    ..email = 'ana@exemplo.com';
  addTearDown(Sessao.instance.sair);
}

Map<String, dynamic> loginJson({bool possuiTorre = true}) => {
      'status': 'success',
      'token': 'token-de-sessao',
      'usuario': {'id': 'google:123', 'email': 'ana@exemplo.com', 'nome': 'Ana'},
      'email': 'ana@exemplo.com',
      'possui_torre': possuiTorre,
      'torre_id': possuiTorre ? idTorre : null,
    };

// ── Dublês de plugins ───────────────────────────────────────────────────────

/// Google Sign-In sem a tela do Google.
class GoogleFalso extends GoogleSignInPlatform {
  bool cancela = false;
  String? idToken = 'id-token-do-google';
  String? accessToken;

  @override
  Future<void> initWithParams(SignInInitParameters params) async {}

  @override
  Future<GoogleSignInUserData?> signIn() async => cancela
      ? null
      : GoogleSignInUserData(email: 'ana@exemplo.com', id: '123', displayName: 'Ana');

  @override
  Future<GoogleSignInTokenData> getTokens({required String email, bool? shouldRecoverAuth}) async =>
      GoogleSignInTokenData(idToken: idToken, accessToken: accessToken);

  @override
  Future<void> signOut() async {}
}

GoogleFalso usarGoogleFalso() {
  final falso = GoogleFalso();
  GoogleSignInPlatform.instance = falso;
  return falso;
}

/// Galeria de fotos que devolve uma imagem pronta.
class GaleriaFalsa extends ImagePickerPlatform {
  XFile? foto = XFile.fromData(
    // PNG 1x1 transparente
    base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
    name: 'alface.png',
    mimeType: 'image/png',
  );

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      foto;
}

GaleriaFalsa usarGaleriaFalsa() {
  final falsa = GaleriaFalsa();
  ImagePickerPlatform.instance = falsa;
  return falsa;
}

// ── Montagem das telas ──────────────────────────────────────────────────────

/// Abre [tela] num MaterialApp com o tema do app, numa tela de [tamanho].
Future<void> montar(WidgetTester tester, Widget tela, {Size tamanho = const Size(1200, 2000)}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: tela));
  await assentar(tester);
}

/// Deixa as respostas do servidor chegarem e as animações curtas terminarem.
/// (O painel tem uma animação contínua, então não dá para usar pumpAndSettle.)
Future<void> assentar(WidgetTester tester, {int vezes = 6}) async {
  for (var i = 0; i < vezes; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Desmonta a tela (cancela timers do painel) antes de o teste acabar.
Future<void> desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}
