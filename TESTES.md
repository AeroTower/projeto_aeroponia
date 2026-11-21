# Testes do app (painel)

**Responsável pelos casos formais:** Caio · **Cobertura:** 97,6% (meta da disciplina: 90%) · **108 testes**

Os testes não usam rede: um `ServidorFalso` (em `test/apoio.dart`) faz o papel do Backend, do serviço de auth e da IA ao mesmo tempo, com o `MockClient` do pacote `http`. O login Google e a galeria de fotos também são dublês. As fontes reais do app (Figtree e Fraunces) são carregadas em `test/flutter_test_config.dart`; sem isso, o Flutter desenha o texto com quadrados largos e acusa estouros de layout que não existem no celular.

| Tipo | Pasta | Testes | O que confere |
|---|---|---:|---|
| Unitário | `test/unitarios/` | 45 | modelos (leitura, motor, torre, planta), `BackendService`, `Sessao`, `PlantaService` e componentes visuais |
| Integração | `test/integracao/` | 12 | login (Google e modo de teste) → serviço de auth → lista de torres → painel; vínculo pelo código com espera do RabbitMQ |
| Funcional | `test/funcionais/` | 38 | painel (kits, alertas, bomba, Wi-Fi, erros, remover torre), plantas (com foto e data), HydroBot e "Minhas torres" |
| Aceitação | `test/aceitacao/` | 4 | histórias de usuário em BDD (Dado / Quando / Então) |
| Desempenho | `test/desempenho/` | 3 | 50.000 leituras convertidas; painel aberto 5 min (100 atualizações); horta com 200 plantas |
| Segurança | `test/seguranca/` | 6 | token não vai à IA; vínculo só com o código; 401 apaga a sessão; erro cru não aparece; config sem segredo |

## Como rodar

```bash
flutter pub get
flutter test --dart-define-from-file=config/desenvolvimento.json             # todos
flutter test --coverage --dart-define-from-file=config/desenvolvimento.json  # com cobertura (coverage/lcov.info)
flutter test test/seguranca --dart-define-from-file=config/desenvolvimento.json   # só um tipo (pela pasta)
```

O `--dart-define-from-file` liga o botão "Entrar sem Google", que dois testes usam. Sem ele, esses dois aparecem como *skipped* e o resto roda igual.

**Android Studio / IntelliJ / VS Code:** botão direito na pasta `test` › **Run 'tests in test'** (ou **Run with Coverage**). Coloque `--dart-define-from-file=config/desenvolvimento.json` em *Edit Configurations › Additional run args*.

**GitHub:** o workflow `.github/workflows/testes.yml` roda em todo pull request. Falha se um teste falhar ou se a cobertura ficar abaixo de 90%. A aba *Actions* mostra a tabela por tipo e a cobertura por arquivo, e *Artifacts › evidencias-testes* traz o relatório HTML.

## Achados durante os testes

| # | Achado | Risco | Situação |
|---|---|---|---|
| 1 | `config/producao.json` tem `LOGIN_DEV: true`: o botão "Entrar sem Google" aparece no app publicado | Alto se o servidor também estiver com `AUTH_MODO_DEV=true` (qualquer um entra) | Pendente, junto com a issue #4 do auth |
| 2 | O HydroBot manda à IA valores inventados quando falta leitura (pH 7,5, 28,5 °C, 45%), e a IA diagnostica dado que não existe | Médio (diagnóstico errado) | Sugestão: não chamar a IA sem leitura, ou avisar na tela |
| 3 | `widgets/plant_card.dart` e `widgets/sensor_card.dart` não são usados por nenhuma tela | Baixo (código morto) | Pode apagar |

## Casos de teste formais (1 de cada tipo)

Plataforma de todos: Flutter estável, `flutter_test`, Ubuntu (GitHub Actions); tela simulada de 1200 × 2000 (e 400 × 2400 no teste de celular).

### AP-UNI-01 · Unitário · Leitura com os nomes do firmware antigo
| Campo | Valor |
|---|---|
| Cenário | O Backend repassa uma leitura de torre ainda não regravada (nomes antigos, número em texto) |
| Pré-requisitos | Nenhum (classe isolada) |
| Passos | `SensorSnapshot.fromJson({...})` |
| Dados | `{"ph": "6.5", "tds": 900, "temperatura": 23, "umidade": 70}` |
| Esperado | pH 6,5; EC = TDS (900); temperatura e umidade lidas; **nível nulo** (a umidade do ar não vira nível do tanque) |
| Obtido | Conforme esperado |
| Status | ✅ Sucesso |
| Teste | `test/unitarios/modelos_test.dart` › "aceita os nomes do firmware antigo e números em texto" |

### AP-INT-01 · Integração · Login com Google até o painel
| Campo | Valor |
|---|---|
| Cenário | A pessoa entra com o Google e tem uma torre |
| Pré-requisitos | Google Sign-In e servidores (auth e Backend) substituídos por dublês |
| Passos | 1. Abrir o app. 2. Tocar "Continuar com o Google". 3. Esperar a navegação |
| Dados | ID token `id-token-do-google`; torre `AT-24DCC3A1B2C4` (Varanda, kit Pro) |
| Esperado | `POST /auth/google` com o token do Google; `GET /torres` com `Bearer` da sessão; painel da torre aberto direto |
| Obtido | Conforme esperado |
| Status | ✅ Sucesso |
| Teste | `test/integracao/login_ate_o_painel_test.dart` › "login com Google abre direto o painel da única torre" |

### AP-FUN-01 · Funcional · Programar o ciclo da bomba
| Campo | Valor |
|---|---|
| Cenário | No painel, a pessoa digita os minutos e inicia o ciclo |
| Pré-requisitos | Sessão ativa; torre Pro com leitura |
| Passos | 1. Digitar 10 em "Ligado" e 50 em "Desligado". 2. Tocar "Iniciar ciclo" |
| Dados | 10 / 50 minutos |
| Esperado | `POST /torres/{id}/motor/ciclo` com `{"minutos_ligado": 10, "minutos_desligado": 50}` e a confirmação na tela |
| Obtido | Conforme esperado |
| Status | ✅ Sucesso |
| Teste | `test/funcionais/painel_test.dart` › "inicia o ciclo com os minutos digitados" |

### AP-ACE-01 · Aceitação (BDD) · Alerta de reservatório baixo
| Campo | Valor |
|---|---|
| Cenário | *Dado* uma torre Pro com o reservatório em 20%, *quando* abro o painel, *então* vejo o alerta de nível baixo e a ampola pedindo para reabastecer |
| Pré-requisitos | História "acompanhar a torre pelo celular" |
| Passos | Abrir o painel com o Backend devolvendo a leitura e o alerta |
| Dados | pH 6,0 · nível 20% · alerta "Nível de água baixo: 20%" |
| Esperado | "1 alerta ativo", o texto do alerta e o rótulo "reabastecer" |
| Obtido | Conforme esperado (as outras 3 histórias também passaram) |
| Status | ✅ Sucesso |
| Teste | `test/aceitacao/historias_test.dart` |

### AP-DES-01 · Desempenho (resistência) · Painel aberto por 5 minutos
| Campo | Valor |
|---|---|
| Cenário | O painel fica aberto atualizando a cada 3 s |
| Pré-requisitos | Torre Pro respondendo |
| Passos | Avançar o relógio 100 × 3 s, medindo o tempo real gasto |
| Dados | Leitura padrão de sensores e motor |
| Esperado | Uma consulta por ciclo (100 a 102), sem erro e em menos de 30 s de tempo real |
| Obtido | Conforme esperado |
| Status | ✅ Sucesso |
| Teste | `test/desempenho/desempenho_test.dart` › "resistência: painel atualizando a cada 3 s por 5 minutos" |

### AP-SEG-01 · Segurança · Token de sessão não vai para a IA
| Campo | Valor |
|---|---|
| Cenário | A pessoa pede orientação ao HydroBot, que chama um serviço externo (hidroponia-ia) |
| Pré-requisitos | Sessão ativa com o token `token-secreto` |
| Passos | Abrir o HydroBot e tocar "Gerar orientação" |
| Dados | Planta "Alface", pH 6, 22 °C, 60% |
| Esperado | O pedido à IA vai **sem** `Authorization` e sem o token no corpo; o pedido de plantas ao Backend vai **com** o token |
| Obtido | Conforme esperado |
| Status | ✅ Sucesso |
| Teste | `test/seguranca/seguranca_test.dart` › "o token de sessão não vai para o serviço de IA (terceiro)" |
