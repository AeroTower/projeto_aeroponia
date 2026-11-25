// Carrega todos os arquivos de lib/: assim a cobertura conta também o que
// nenhum outro teste abre (sem isso, o lcov ignora o arquivo e o número infla).
// ignore_for_file: unused_import
import 'package:flutter_test/flutter_test.dart';

import 'package:hidro_app/config/app_config.dart';
import 'package:hidro_app/main.dart';
import 'package:hidro_app/models/backend_models.dart';
import 'package:hidro_app/models/planta.dart';
import 'package:hidro_app/models/torre.dart';
import 'package:hidro_app/screens/chat_bot.dart';
import 'package:hidro_app/screens/dashboard_screen.dart';
import 'package:hidro_app/screens/login_screen.dart';
import 'package:hidro_app/screens/painel/aviso_conexao.dart';
import 'package:hidro_app/screens/painel/barra_status.dart';
import 'package:hidro_app/screens/painel/cabecalho_painel.dart';
import 'package:hidro_app/screens/painel/cartao_wifi.dart';
import 'package:hidro_app/screens/painel/componentes.dart';
import 'package:hidro_app/screens/painel/faixa_alertas.dart';
import 'package:hidro_app/screens/painel/grade_sensores.dart';
import 'package:hidro_app/screens/painel/painel_motor.dart';
import 'package:hidro_app/screens/plants_screen.dart';
import 'package:hidro_app/screens/torres_screen.dart';
import 'package:hidro_app/screens/vincular_torre_screen.dart';
import 'package:hidro_app/services/backend_service.dart';
import 'package:hidro_app/services/ia_service.dart';
import 'package:hidro_app/services/planta_service.dart';
import 'package:hidro_app/services/sessao.dart';
import 'package:hidro_app/theme/app_theme.dart';
import 'package:hidro_app/widgets/aero_logo.dart';
import 'package:hidro_app/widgets/gauge_card.dart';
import 'package:hidro_app/widgets/nivel_agua_card.dart';

void main() {
  test('todos os arquivos de lib/ compilam', () => expect(true, isTrue));
}
