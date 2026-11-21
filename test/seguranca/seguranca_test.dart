// Testes de segurança do app: para onde vai o token e o que fica guardado.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/chat_bot.dart';
import 'package:hidro_app/screens/dashboard_screen.dart';
import 'package:hidro_app/screens/login_screen.dart';
import 'package:hidro_app/screens/torres_screen.dart';
import 'package:hidro_app/screens/vincular_torre_screen.dart';
import 'package:hidro_app/services/backend_service.dart';
import 'package:hidro_app/services/sessao.dart';

import '../apoio.dart';

void main() {
  tearDown(Sessao.instance.sair);

  testWidgets('o token de sessão não vai para o serviço de IA (terceiro)', (tester) async {
    logar(token: 'token-secreto');
    final servidor = servidorComTorre()..quando('POST /analisar-cultivo', {'sugestoes_acao': []});
    await servidor.rodar(() async {
      await montar(tester, const ChatbotScreen(torreId: idTorre, phAtual: 6, tempAtual: 22, umidadeAtual: 60));
      await tester.tap(find.text('Gerar orientação'));
      await assentar(tester);
    });
    final ia = servidor.para('POST /analisar-cultivo').single;
    expect(ia.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
    expect(ia.body, isNot(contains('token-secreto')));
    // ...mas vai para o Backend, que precisa dele
    expect(servidor.para('GET /torres/$idTorre/plantas').single.headers['Authorization'], 'Bearer token-secreto');
  });

  testWidgets('vincular manda só o código: o dono é quem está logado', (tester) async {
    logar();
    final servidor = ServidorFalso()
      ..quando('POST /torre/vincular', {'detail': 'Código de ativação inválido.'}, status: 400);
    await servidor.rodar(() async {
      await montar(tester, const VincularTorreScreen());
      await tester.enterText(find.byType(TextField), 'K9X2-7QHM');
      await tester.tap(find.text('Conectar Torre'));
      await assentar(tester);
    });
    final corpo = jsonDecode(servidor.para('POST /torre/vincular').single.body) as Map;
    expect(corpo.keys, ['codigo'], reason: 'antes ia o e-mail no corpo e qualquer um vinculava em nome de outro');
  });

  testWidgets('sessão expirada no meio do uso apaga o token e volta ao login', (tester) async {
    logar();
    await (ServidorFalso()..quando('GET /torres', {'detail': 'Sessão expirada.'}, status: 401))
        .rodar(() => montar(tester, const TorresScreen()));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(Sessao.instance.token, isNull);
    expect(Sessao.instance.headers, isEmpty);
  });

  test('sem login, nenhum pedido leva cabeçalho de autorização', () async {
    final servidor = servidorComTorre();
    await BackendService(client: servidor.cliente, baseUrl: 'https://backend.teste', torreId: idTorre).getDados();
    expect(servidor.pedidos.single.headers.containsKey('Authorization'), isFalse);
  });

  testWidgets('erro do servidor não mostra a resposta crua (HTML, pilha) na tela', (tester) async {
    logar();
    final servidor = servidorComTorre()
      ..quandoFn('GET /torres/$idTorre/dados',
          (_) => resposta('<html>Traceback: File "/home/site/app.py"</html>', status: 500));
    await servidor.rodar(() => montar(tester, DashboardScreen(torre: torre())));
    expect(find.textContaining('Traceback'), findsNothing);
    expect(find.textContaining('app.py'), findsNothing);
    expect(find.textContaining('Sem resposta do backend'), findsWidgets);
    await desmontar(tester);
  });

  test('os arquivos de configuração do app não têm segredo', () {
    for (final arquivo in ['config/desenvolvimento.json', 'config/producao.json']) {
      final config = jsonDecode(File(arquivo).readAsStringSync()) as Map<String, dynamic>;
      for (final chave in config.keys) {
        expect(chave, isNot(matches(RegExp('SEGREDO|SECRET|PASS|SENHA|API_KEY|TOKEN', caseSensitive: false))),
            reason: '$arquivo vai junto no app publicado: qualquer um lê');
      }
      expect(config['AUTH_BASE_URL'], startsWith(arquivo.contains('producao') ? 'https://' : 'http'));
    }
  });
}
