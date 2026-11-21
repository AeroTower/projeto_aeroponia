// Testes de integração: telas + Sessao + BackendService conversando com o
// servidor falso (auth, Backend). Confere as interfaces entre as partes.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/config/app_config.dart';
import 'package:hidro_app/main.dart';
import 'package:hidro_app/screens/dashboard_screen.dart';
import 'package:hidro_app/screens/login_screen.dart';
import 'package:hidro_app/screens/torres_screen.dart';
import 'package:hidro_app/screens/vincular_torre_screen.dart';
import 'package:hidro_app/services/sessao.dart';

import '../apoio.dart';

void main() {
  tearDown(Sessao.instance.sair);

  testWidgets('login com Google abre direto o painel da única torre', (tester) async {
    usarGoogleFalso();
    final servidor = servidorComTorre()..quando('POST /auth/google', loginJson());
    await servidor.rodar(() async {
      await montar(tester, const MyApp());
      await tester.tap(find.text('Continuar com o Google'));
      await assentar(tester, vezes: 10);
    });
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Varanda'), findsOneWidget);
    expect(jsonDecode(servidor.para('POST /auth/google').single.body), {'token': 'id-token-do-google'});
    expect(servidor.para('GET /torres').single.headers['Authorization'], 'Bearer token-de-sessao');
    expect(servidor.para('GET /torres/$idTorre/dados'), isNotEmpty);
    await desmontar(tester);
  });

  testWidgets('login na web usa o access token quando não há id token', (tester) async {
    final google = usarGoogleFalso()
      ..idToken = null
      ..accessToken = 'ya29.access';
    final servidor = ServidorFalso()
      ..quando('POST /auth/google', loginJson(possuiTorre: false))
      ..quando('GET /torres', []);
    await servidor.rodar(() async {
      await montar(tester, const LoginScreen());
      await tester.tap(find.text('Continuar com o Google'));
      await assentar(tester, vezes: 10);
    });
    expect(google.accessToken, 'ya29.access');
    expect(jsonDecode(servidor.para('POST /auth/google').single.body), {'token': 'ya29.access'});
    expect(find.byType(VincularTorreScreen), findsOneWidget, reason: 'sem torre vai para o vínculo');
  });

  testWidgets('Google sem nenhum token mostra erro', (tester) async {
    usarGoogleFalso().idToken = null;
    await montar(tester, const LoginScreen());
    await tester.tap(find.text('Continuar com o Google'));
    await assentar(tester);
    expect(find.textContaining('token de autenticação do Google'), findsOneWidget);
  });

  testWidgets('cancelar a janela do Google volta ao botão', (tester) async {
    usarGoogleFalso().cancela = true;
    await montar(tester, const LoginScreen());
    await tester.tap(find.text('Continuar com o Google'));
    await assentar(tester);
    expect(find.text('Continuar com o Google'), findsOneWidget);
    expect(Sessao.instance.logado, isFalse);
  });

  testWidgets('auth recusando o login mostra a mensagem dele', (tester) async {
    usarGoogleFalso();
    final servidor = ServidorFalso()..quando('POST /auth/google', {'detail': 'Token do Google inválido'}, status: 401);
    await servidor.rodar(() async {
      await montar(tester, const LoginScreen());
      await tester.tap(find.text('Continuar com o Google'));
      await assentar(tester);
    });
    expect(find.text('Token do Google inválido'), findsOneWidget);
  });

  testWidgets('auth fora do ar', (tester) async {
    usarGoogleFalso();
    final servidor = ServidorFalso()..caiu('POST /auth/google');
    await servidor.rodar(() async {
      await montar(tester, const LoginScreen());
      await tester.tap(find.text('Continuar com o Google'));
      await assentar(tester);
    });
    expect(find.textContaining('Erro ao conectar com o Google'), findsOneWidget);
  });

  testWidgets('login sem Google (modo de teste)', (tester) async {
    final servidor = ServidorFalso()
      ..quando('POST /auth/dev', loginJson(possuiTorre: false))
      ..quando('GET /torres', []);
    await servidor.rodar(() async {
      await montar(tester, const LoginScreen());
      await tester.tap(find.text('Entrar sem Google (modo de teste)'));
      await assentar(tester, vezes: 10);
    });
    expect(jsonDecode(servidor.para('POST /auth/dev').single.body), {'id': 'demo'});
    expect(find.byType(VincularTorreScreen), findsOneWidget);
  }, skip: !AppConfig.loginDev);

  testWidgets('login sem Google com o auth recusando ou fora do ar', (tester) async {
    final servidor = ServidorFalso()..quando('POST /auth/dev', {'detail': 'Não encontrado.'}, status: 404);
    await servidor.rodar(() async {
      await montar(tester, const LoginScreen());
      await tester.tap(find.text('Entrar sem Google (modo de teste)'));
      await assentar(tester);
      expect(find.text('Não encontrado.'), findsOneWidget);
      servidor.caiu('POST /auth/dev');
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Entrar sem Google (modo de teste)'));
      await assentar(tester);
    });
    expect(find.textContaining('Sem resposta do servidor'), findsOneWidget);
  }, skip: !AppConfig.loginDev);

  testWidgets('vincular: código certo espera a torre chegar ao Backend e abre o painel', (tester) async {
    logar();
    var listagens = 0;
    final servidor = servidorComTorre()
      ..quando('POST /torre/vincular', {'status': 'success', 'torre_id': idTorre})
      // O Backend só fica sabendo pelo RabbitMQ: a torre aparece na 3ª consulta.
      ..quandoFn('GET /torres', (_) => resposta(++listagens < 3 ? [] : [torreJson()]));
    await servidor.rodar(() async {
      await montar(tester, const VincularTorreScreen());
      await tester.enterText(find.byType(TextField), ' k9x2-7qhm ');
      await tester.tap(find.text('Conectar Torre'));
      await assentar(tester);
      expect(find.text('Preparando sua torre…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await assentar(tester, vezes: 10);
    });
    final pedido = servidor.para('POST /torre/vincular').single;
    expect(jsonDecode(pedido.body), {'codigo': 'k9x2-7qhm'});
    expect(pedido.headers['Authorization'], 'Bearer token-de-sessao');
    expect(find.byType(DashboardScreen), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('vincular: torre que não chega ao Backend avisa e deixa tentar de novo', (tester) async {
    logar();
    final servidor = ServidorFalso()..quando('GET /torres', []);
    await servidor.rodar(() async {
      await montar(tester, const TorresScreen(aguardarTorreId: idTorre));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await assentar(tester);
    });
    expect(find.textContaining('ainda não apareceu'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('vincular: erros do auth e da rede', (tester) async {
    logar();
    final servidor = ServidorFalso()
      ..quando('POST /torre/vincular', {'detail': 'Esta AeroTower já está associada a outro usuário.'}, status: 409);
    await servidor.rodar(() async {
      await montar(tester, const VincularTorreScreen());
      await tester.tap(find.text('Conectar Torre'));          // vazio
      await tester.pump();
      expect(find.textContaining('insira o código'), findsOneWidget);
      await esperarAvisoSumir(tester);

      await tester.enterText(find.byType(TextField), 'K9X2-7QHM');
      await tester.tap(find.text('Conectar Torre'));
      await assentar(tester);
      expect(find.textContaining('associada a outro usuário'), findsOneWidget);
      await esperarAvisoSumir(tester);

      servidor.caiu('POST /torre/vincular');
      await tester.tap(find.text('Conectar Torre'));
      await assentar(tester);
    });
    expect(find.textContaining('Erro de conexão'), findsOneWidget);
  });

  testWidgets('vincular: sair da conta volta ao login', (tester) async {
    logar();
    await montar(tester, const VincularTorreScreen());
    await tester.tap(find.text('Sair da conta'));
    await assentar(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(Sessao.instance.logado, isFalse);
  });
}
