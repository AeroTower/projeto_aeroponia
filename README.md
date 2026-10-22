# AeroTower — App

## Rodar

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=config/desenvolvimento.json
```

`config/desenvolvimento.json` aponta para o serviço de auth (porta 8000) e o
Backend (porta 8001) na sua máquina e mostra o botão "Entrar sem Google"
(o serviço de auth precisa de `AUTH_MODO_DEV=true`). Para produção, preencha
`config/producao.json`; o GitHub Actions usa esse arquivo no build.

Nada nesses arquivos é segredo: são endereços públicos e o client ID do
Google. Segredo (JWT, chaves) fica só nos servidores.

## Fluxo

Login (Google) → serviço de auth devolve o token → **Minhas torres**:
sem torre abre a tela de vínculo (código do adesivo), com torre abre o
painel. O painel mostra só os cards dos sensores do kit da torre.

## Google Sign-In

- **Web:** `GOOGLE_WEB_CLIENT_ID` = client ID do tipo "Aplicativo da Web".
  Adicione a URL do GitHub Pages (e `http://localhost:porta` para testar)
  em "Origens JavaScript autorizadas" no Google Cloud.
- **Android:** crie também um client ID "Android" com o SHA-1 da chave de
  assinatura. O app usa o client ID web como `serverClientId`.
- **iOS:** client ID "iOS" no `Info.plist` (ver documentação do `google_sign_in`).

O serviço de auth precisa ter todos esses client IDs em `GOOGLE_CLIENT_IDS`.

---

# hidro_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
