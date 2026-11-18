/// Configuracoes do app PulsoBiz.
///
/// A chave abaixo e a chave PUBLICA do Supabase (feita para ficar no app/navegador).
/// O acesso aos dados e protegido pelo login do cliente, nao por essa chave.
/// Nenhum segredo (token de dispositivo, senha de administrador) fica no app.
class Config {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://mhkaowtdlwbtrnqbftcr.supabase.co');
  static const String publicKey = String.fromEnvironment('SUPABASE_KEY',
      defaultValue: 'sb_publishable_fmLZEiu8o7i0qN3xoAE6_w_6AmsHzl1');

  /// Endereco da funcao de dados (login do cliente vai no cabecalho Authorization).
  static String get apiUrl => '$supabaseUrl/functions/v1/data';

  /// Endereco do login (Supabase Auth).
  static String get authUrl => '$supabaseUrl/auth/v1';

  // ---- Nomes das variaveis (CONTRATO-DE-DADOS.md) ----
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
  /// conta como 1 movimento.
  static const bool movimentoContaBorda = false;

  /// "Detectado" na tela Ao vivo so se o ultimo movimento for mais novo que isso.
  static const int movimentoRecenteSegundos = 60;

  /// Sem dados do dispositivo ha mais que isso (minutos) = "offline".
  static const int offlineMinutos = 3;

  static const String versao = '1.0.0';
}
