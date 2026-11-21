// Testes funcionais do painel: o que a pessoa vê e faz, pela interface.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidro_app/screens/chat_bot.dart';
import 'package:hidro_app/screens/dashboard_screen.dart';
import 'package:hidro_app/screens/login_screen.dart';
import 'package:hidro_app/screens/plants_screen.dart';
import 'package:hidro_app/screens/vincular_torre_screen.dart';
import 'package:hidro_app/services/sessao.dart';

import '../apoio.dart';

void main() {
  setUp(logar);

  testWidgets('kit Pro: mostra os 4 sensores, alertas e o status da bomba', (tester) async {
    final servidor = servidorComTorre(alertas: ['pH acima do limite: 7.4', 'Nível de água baixo: 20%']);
    await servidor.rodar(() => montar(tester, DashboardScreen(torre: torre())));
    expect(find.text('pH'), findsOneWidget);
    expect(find.text('TDS'), findsOneWidget);
    expect(find.text('Temperatura'), findsOneWidget);
    expect(find.text('Nível da água'), findsOneWidget);
    expect(find.text('2 alertas ativos'), findsOneWidget);
    expect(find.textContaining('pH acima do limite'), findsOneWidget);
    expect(find.textContaining('Status: Ligado'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.textContaining('16:05:09'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('tudo dentro da faixa: "Todos os sistemas operacionais"', (tester) async {
    await servidorComTorre().rodar(() => montar(tester, DashboardScreen(torre: torre())));
    expect(find.text('Todos os sistemas operacionais'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('um alerta só, no singular', (tester) async {
    await servidorComTorre(alertas: ['pH acima']).rodar(() => montar(tester, DashboardScreen(torre: torre())));
    expect(find.text('1 alerta ativo'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('kit Básico: sem sensores, sem botão da IA', (tester) async {
    await servidorComTorre(kit: 'basico').rodar(() => montar(tester, DashboardScreen(torre: torre(kit: 'basico'))));
    expect(find.textContaining('Sua torre rega sozinha'), findsOneWidget);
    expect(find.text('pH'), findsNothing);
    expect(find.text('IA'), findsNothing);
    expect(find.text('Plantas'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('kit Completo: só o nível da água', (tester) async {
    await servidorComTorre(kit: 'completo')
        .rodar(() => montar(tester, DashboardScreen(torre: torre(kit: 'completo'))));
    expect(find.text('Nível da água'), findsOneWidget);
    expect(find.text('TDS'), findsNothing);
    await desmontar(tester);
  });

  testWidgets('inicia o ciclo com os minutos digitados', (tester) async {
    final servidor = servidorComTorre();
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre()));
      await tester.enterText(find.byType(TextField).at(0), '10');
      await tester.enterText(find.byType(TextField).at(1), '50');
      await tester.tap(find.text('Iniciar ciclo'));
      await assentar(tester);
    });
    expect(jsonDecode(servidor.para('POST /torres/$idTorre/motor/ciclo').single.body),
        {'minutos_ligado': 10, 'minutos_desligado': 50});
    expect(find.textContaining('Ciclo iniciado: 10 min ligado / 50 min desligado'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('minutos inválidos não mandam comando', (tester) async {
    final servidor = servidorComTorre();
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre()));
      await tester.enterText(find.byType(TextField).at(0), '0');
      await tester.tap(find.text('Iniciar ciclo'));
      await assentar(tester);
    });
    expect(find.textContaining('maiores que zero'), findsOneWidget);
    expect(servidor.para('POST /torres/$idTorre/motor/ciclo'), isEmpty);
    await desmontar(tester);
  });

  testWidgets('desligar a bomba e atualizar o status', (tester) async {
    final servidor = servidorComTorre();
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre()));
      servidor.quando('GET /torres/$idTorre/motor/status', {'ligado': false});
      await tester.tap(find.text('Desligar'));
      await assentar(tester);
      expect(find.text('Comando para desligar enviado.'), findsOneWidget);
      expect(find.textContaining('Status: Desligado'), findsOneWidget);
      await tester.tap(find.byTooltip('Atualizar status'));
      await assentar(tester);
    });
    expect(servidor.para('POST /torres/$idTorre/motor/desligar'), hasLength(1));
    await desmontar(tester);
  });

  testWidgets('comando recusado ou sem rede mostra o erro no painel da bomba', (tester) async {
    final servidor = servidorComTorre()
      ..quando('POST /torres/$idTorre/motor/desligar', {'detail': 'Falha ao publicar no MQTT.'}, status: 502);
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre()));
      await tester.tap(find.text('Desligar'));
      await assentar(tester);
      expect(find.text('Falha ao publicar no MQTT.'), findsOneWidget);
      servidor.caiu('POST /torres/$idTorre/motor/ciclo');
      await tester.tap(find.text('Iniciar ciclo'));
      await assentar(tester);
    });
    expect(find.text('Nao foi possivel enviar o comando.'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('status da bomba indisponível', (tester) async {
    final servidor = servidorComTorre()
      ..quando('GET /torres/$idTorre/motor/status', {'detail': 'Nenhum status do motor recebido ainda.'}, status: 503);
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre()));
      expect(find.textContaining('Nenhum status do motor'), findsOneWidget);
      servidor.caiu('GET /torres/$idTorre/motor/status');
      await tester.tap(find.byTooltip('Atualizar status'));
      await assentar(tester);
    });
    expect(find.text('Status do motor indisponivel.'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('torre que nunca conectou mostra o passo a passo do Wi-Fi', (tester) async {
    final servidor = servidorComTorre()
      ..quando('GET /torres/$idTorre/dados', {'detail': 'Nenhum dado recebido ainda desta torre.'}, status: 503);
    await servidor.rodar(() => montar(tester, DashboardScreen(torre: torre(online: null, ultimaLeituraEm: null))));
    expect(find.text('Conecte sua torre ao Wi-Fi'), findsOneWidget);
    expect(find.textContaining('AeroTower-B2C4'), findsOneWidget);
    expect(find.text('Torre sem conexão'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('torre que caiu: cartão de reconexão e presença atualizada a cada 15 s', (tester) async {
    final servidor = servidorComTorre()..quando('GET /torres/$idTorre', torreJson(online: false));
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre(online: false)));
      expect(find.text('Sua torre está sem conexão'), findsOneWidget);
      expect(find.textContaining('Segure o botão BOOT'), findsOneWidget);
      servidor.quando('GET /torres/$idTorre', torreJson(online: true));
      await tester.pump(const Duration(seconds: 15));
      await assentar(tester);
      expect(find.text('Sua torre está sem conexão'), findsNothing);
      servidor.caiu('GET /torres/$idTorre');
      await tester.pump(const Duration(seconds: 15));
      await assentar(tester);
    });
    expect(servidor.para('GET /torres/$idTorre').length, greaterThanOrEqualTo(2));
    await desmontar(tester);
  });

  testWidgets('Backend fora do ar: aviso, "Offline" e botão de tentar de novo', (tester) async {
    final servidor = servidorComTorre()..caiu('GET /torres/$idTorre/dados');
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre()));
      expect(find.text('Offline'), findsOneWidget);
      expect(find.textContaining('Sem resposta do backend'), findsWidgets);
      servidor.quando('GET /torres/$idTorre/dados', {'detail': 'Erro interno'}, status: 500);
      await tester.tap(find.text('Tentar novamente'));
      await assentar(tester);
      expect(find.text('Erro interno'), findsWidgets);
      servidor.quando('GET /torres/$idTorre/dados', dadosJson());
      await tester.pump(const Duration(seconds: 3));    // próxima atualização automática
      await assentar(tester);
    });
    expect(find.text('Online'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('modo antigo (sem torre): rotas legadas e logo no lugar da seta', (tester) async {
    final servidor = ServidorFalso()
      ..quando('GET /dados', dadosJson())
      ..quando('GET /motor/status', motorJson);
    await servidor.rodar(() => montar(tester, const DashboardScreen()));
    expect(find.text('AeroTower'), findsOneWidget);
    expect(find.text('Sistema de Monitoramento'), findsOneWidget);
    expect(find.byTooltip('Minhas torres'), findsNothing);
    await desmontar(tester);
  });

  testWidgets('tela estreita de celular', (tester) async {
    await servidorComTorre()
        .rodar(() => montar(tester, DashboardScreen(torre: torre()), tamanho: const Size(400, 2400)));
    expect(find.text('Iniciar ciclo'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('botões Plantas e IA abrem as telas', (tester) async {
    final servidor = servidorComTorre();
    await servidor.rodar(() async {
      await montar(tester, DashboardScreen(torre: torre()));
      await tester.tap(find.text('Plantas'));
      await assentar(tester);
      expect(find.byType(PlantsScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await assentar(tester);
      await tester.tap(find.text('IA'));
      await assentar(tester);
      expect(find.byType(ChatbotScreen), findsOneWidget);
    });
    await desmontar(tester);
  });

  group('remover torre da conta', () {
    Future<void> abrirMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Mais opções'));
      await assentar(tester);
      await tester.tap(find.text('Remover torre da minha conta'));
      await assentar(tester);
    }

    testWidgets('confirmar desvincula e vai para o vínculo', (tester) async {
      final servidor = servidorComTorre()..quando('DELETE /torre/$idTorre/vinculo', {'status': 'success'});
      await servidor.rodar(() async {
        await montar(tester, DashboardScreen(torre: torre()));
        await abrirMenu(tester);
        expect(find.text('Remover torre da sua conta?'), findsOneWidget);
        await tester.tap(find.text('Remover'));
        await assentar(tester);
      });
      expect(servidor.para('DELETE /torre/$idTorre/vinculo'), hasLength(1));
      expect(find.byType(VincularTorreScreen), findsOneWidget);
    });

    testWidgets('cancelar não faz nada', (tester) async {
      final servidor = servidorComTorre();
      await servidor.rodar(() async {
        await montar(tester, DashboardScreen(torre: torre()));
        await abrirMenu(tester);
        await tester.tap(find.text('Cancelar'));
        await assentar(tester);
      });
      expect(servidor.para('DELETE /torre/$idTorre/vinculo'), isEmpty);
      await desmontar(tester);
    });

    testWidgets('sessão expirada volta ao login', (tester) async {
      final servidor = servidorComTorre()
        ..quando('DELETE /torre/$idTorre/vinculo', {'detail': 'Sessão expirada.'}, status: 401);
      await servidor.rodar(() async {
        await montar(tester, DashboardScreen(torre: torre()));
        await abrirMenu(tester);
        await tester.tap(find.text('Remover'));
        await assentar(tester);
      });
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(Sessao.instance.logado, isFalse);
    });

    testWidgets('erro do servidor ou rede fora mostram aviso', (tester) async {
      final servidor = servidorComTorre()
        ..quando('DELETE /torre/$idTorre/vinculo', {'detail': 'Serviço indisponível.'}, status: 503);
      await servidor.rodar(() async {
        await montar(tester, DashboardScreen(torre: torre()));
        await abrirMenu(tester);
        await tester.tap(find.text('Remover'));
        await assentar(tester);
        expect(find.text('Serviço indisponível.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        servidor.caiu('DELETE /torre/$idTorre/vinculo');
        await abrirMenu(tester);
        await tester.tap(find.text('Remover'));
        await assentar(tester);
      });
      expect(find.textContaining('Sem resposta do servidor'), findsOneWidget);
      await desmontar(tester);
    });
  });
}
