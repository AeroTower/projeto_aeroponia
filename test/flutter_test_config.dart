// Roda antes de cada arquivo de teste (convenção do flutter_test).
//
// Carrega as fontes de verdade do app. Sem isso, o Flutter desenha todo
// texto com a fonte de teste (cada letra é um quadrado largo) e acusa
// estouros de layout que não existem no celular.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _carregar('Figtree', ['400', '500', '600', '700']);
  await _carregar('Fraunces', ['700', '900']);
  await testMain();
}

Future<void> _carregar(String familia, List<String> pesos) async {
  final carregador = FontLoader(familia);
  for (final peso in pesos) {
    carregador.addFont(rootBundle.load('assets/fonts/$familia-$peso.ttf'));
  }
  await carregador.load();
}
