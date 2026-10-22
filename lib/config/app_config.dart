/// Endereços e IDs do app, definidos na hora do build:
///
///   flutter run --dart-define-from-file=config/desenvolvimento.json
///   flutter build web --dart-define-from-file=config/producao.json
///
/// Por que não um .env: o arquivo .env entra no pacote do app (qualquer um
/// lê na versão web) e, como fica fora do Git, quebra o build do GitHub
/// Pages. Nada aqui é segredo: são endereços públicos e o client ID do
/// Google, que também é público.
class AppConfig {
  AppConfig._();

  /// Serviço de autenticação (auth-aerotower): login e vínculo da torre.
  static const authBaseUrl = String.fromEnvironment(
    'AUTH_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Client ID OAuth do tipo "Aplicativo da Web" no Google Cloud.
  /// Na web é o clientId; no Android vai como serverClientId (é ele que
  /// aparece no token que o servidor confere).
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Mostra o botão "Entrar sem Google" (servidor com AUTH_MODO_DEV=true).
  static const loginDev = bool.fromEnvironment('LOGIN_DEV');
}
