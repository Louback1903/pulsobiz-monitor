/// Configuracoes do app.
///
/// O token NAO fica no codigo: ele entra na hora de compilar,
/// via `--dart-define-from-file=env.json` (arquivo ignorado pelo git).
class Config {
  static const String token = String.fromEnvironment('TAGO_TOKEN');
  static const String baseUrl =
      String.fromEnvironment('TAGO_URL', defaultValue: 'https://api.tago.io');
  static const String dashboardUrl =
      String.fromEnvironment('DASHBOARD_URL', defaultValue: '');

  // ---- Nomes das variaveis no TagoIO ----
  // AJUSTE AQUI conforme o CONTRATO-DE-DADOS.md
  static const String varTemperatura = 'temperatura';
  static const String varUmidade = 'umidade';
  static const String varMovimento = 'movimento';
  static const String varRele = 'rele';
  static const String varAlertaTemp = 'alerta_temperatura';
  static const String varAlertaHorario = 'alerta_fora_horario';

  /// Atualizacao do painel ao vivo (segundos)
  static const int refreshSeconds = 5;

  /// Janela do historico/relatorio (horas)
  static const int janelaHoras = 24;

  /// O dispositivo envia movimento=1 so quando detecta (nunca 0): cada registro
  /// conta como 1 movimento. Use true apenas se ele passar a enviar 0/1 periodico.
  static const bool movimentoContaBorda = false;

  /// "Detectado" na tela Ao vivo so se o ultimo movimento for mais novo que isso.
  static const int movimentoRecenteSegundos = 60;
}
