/*
 * ============================================================================
 *  PulsoBiz Monitor - Projeto N2 - PARTE 3: DISPOSITIVO IoT (firmware v2)
 * ============================================================================
 *
 *  Evolucao do firmware da Fase 1. Continua lendo DHT22 + PIR, acionando o
 *  rele, mostrando no OLED e montando o histograma de movimento por hora
 *  (reconhecimento de padrao), e agora TAMBEM envia tudo para a plataforma
 *  IoT em nuvem (TagoIO) por HTTPS + JSON.
 *
 *  O QUE O DISPOSITIVO ENVIA (contrato completo: CONTRATO-DE-DADOS.md)
 *    Periodico (a cada INTERVALO_TELEMETRIA_MS):
 *      temperatura (C), umidade (%), movimentos_hora, wifi_rssi (dBm)
 *    Por evento:
 *      movimento (1)            a cada nova deteccao do PIR
 *      pico_hora (h)            quando o horario de pico muda
 *      rele (0/1)               quando o rele liga/desliga
 *      alerta_temperatura (0/1) 1 = passou do limite de alerta, 0 = normalizou
 *      alerta_fora_horario (1)  movimento fora do expediente (com cooldown)
 *
 *  MUDANCAS EM RELACAO A FASE 1
 *    - Envio para a nuvem (HTTPS POST em <TAGOIO_API_HOST>/data; padrao
 *      https://api.tago.io, configuravel no secrets.h).
 *    - PIR lido a cada ciclo do loop (antes: a cada 5 s, podia perder pulsos).
 *    - Histerese no rele e no alerta de temperatura (evita liga/desliga
 *      repetido quando a temperatura oscila perto do limite).
 *    - Alerta de movimento fora do expediente, com cooldown anti-spam
 *      (protege a cota de SMS/e-mail).
 *    - Reconexao automatica do Wi-Fi.
 *    - Segredos (token, senha do Wi-Fi) fora do codigo: arquivo secrets.h.
 *
 *  SEGREDOS
 *    Copie secrets.example.h para secrets.h e preencha. O secrets.h esta no
 *    .gitignore: NUNCA suba o token para o git. Sem secrets.h o firmware
 *    compila e roda normalmente, so que sem enviar para a nuvem.
 *
 *  HARDWARE (mesmo da Fase 1 - ver diagram.json)
 *    ESP32 DevKit V1 | DHT22 -> D4 | PIR -> D27 | Rele -> D26
 *    OLED SSD1306 I2C -> D21 (SDA) / D22 (SCL)
 *
 *  BIBLIOTECAS (libraries.txt)
 *    DHT sensor library, Adafruit GFX Library, Adafruit SSD1306
 * ============================================================================
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <time.h>
#include <Wire.h>
#include <DHT.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#if __has_include("secrets.h")
#include "secrets.h"
#endif

#ifndef WIFI_SSID
#define WIFI_SSID "Wokwi-GUEST"
#endif
#ifndef WIFI_PASSWORD
#define WIFI_PASSWORD ""
#endif
#ifndef TAGOIO_DEVICE_TOKEN
#define TAGOIO_DEVICE_TOKEN ""
#endif
// Endereco da API do TagoIO da conta (a regiao da conta pode exigir outro, ex.:
// https://api.us-e1.tago.io). Defina TAGOIO_API_HOST no secrets.h para trocar.
#ifndef TAGOIO_API_HOST
#define TAGOIO_API_HOST "https://api.tago.io"
#endif

// ---------------------------------------------------------------------------
// Hardware
// ---------------------------------------------------------------------------
#define DHT_PIN     4
#define DHT_TYPE    DHT22
#define PIR_PIN     27
#define RELAY_PIN   26

// Muitos modulos de rele reais sao ATIVOS EM NIVEL BAIXO (IN=LOW liga).
// Se o seu ligar/desligar ao contrario, troque para false.
#define RELE_ATIVO_ALTO true

#define SCREEN_WIDTH   128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1

// ---------------------------------------------------------------------------
// Regras do negocio (ajustaveis por cliente)
// ---------------------------------------------------------------------------
const float TEMP_RELE_LIGA_C       = 28.0;  // liga o atuador (ex.: ventilador)
const float TEMP_RELE_DESLIGA_C    = 27.0;  // desliga (1 grau abaixo: histerese)
const float TEMP_ALERTA_LIGA_C     = 32.0;  // dispara alerta (SMS/e-mail)
const float TEMP_ALERTA_DESLIGA_C  = 31.0;  // normalizou

const int HORA_ABERTURA   = 8;   // expediente: [8h, 18h)
const int HORA_FECHAMENTO = 18;

const unsigned long INTERVALO_LEITURA_DHT_MS    = 5000;
const unsigned long INTERVALO_DISPLAY_MS        = 1000;
const unsigned long INTERVALO_TELEMETRIA_MS     = 60000;   // demo ao vivo: 10000
const unsigned long COOLDOWN_ALERTA_HORARIO_MS  = 300000;  // 5 min entre alertas
const unsigned long INTERVALO_RECONEXAO_WIFI_MS = 15000;

// Fuso de Recife/PE: UTC-3, sem horario de verao.
const long GMT_OFFSET_SEC = -3 * 3600;
const int DAYLIGHT_OFFSET_SEC = 0;

// ---------------------------------------------------------------------------
// Objetos e estado
// ---------------------------------------------------------------------------
DHT dht(DHT_PIN, DHT_TYPE);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
WebServer server(80);

float temperaturaAtual = 0;
float umidadeAtual = 0;
bool leituraValida = false;

bool movimentoAtual = false;
bool movimentoAnterior = false;
bool releLigado = false;
bool alertaTemperaturaAtivo = false;

// Histograma de movimento por hora (0h-23h): reconhecimento do horario de pico.
unsigned int historicoMovimentoPorHora[24] = {0};
unsigned int totalMovimentos = 0;
int picoEnviado = -1;

bool alertaHorarioJaEnviado = false;
unsigned long ultimoAlertaHorarioMs = 0;

bool primeiraTelemetriaPendente = true;
unsigned long ultimaLeituraDhtMs = 0;
unsigned long ultimoDisplayMs = 0;
unsigned long ultimaTelemetriaMs = 0;
unsigned long ultimaTentativaWifiMs = 0;

// Texto curto para o OLED: "OFF" (sem token), "OK", "ERRO", "S/WIFI".
const char* statusNuvem = "OFF";

// ---------------------------------------------------------------------------
// Utilitarios
// ---------------------------------------------------------------------------
bool nuvemHabilitada() {
  return strlen(TAGOIO_DEVICE_TOKEN) > 0;
}

void escreverRele(bool ligado) {
  digitalWrite(RELAY_PIN, (ligado == RELE_ATIVO_ALTO) ? HIGH : LOW);
}

// Hora atual (0-23) pelo relogio sincronizado via NTP; -1 se ainda nao sincronizou.
int horaAtual() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo, 100)) {
    return -1;
  }
  return timeinfo.tm_hour;
}

// Hora do dia com mais deteccoes de movimento ate agora.
int horarioDePico() {
  int pico = 0;
  for (int h = 1; h < 24; h++) {
    if (historicoMovimentoPorHora[h] > historicoMovimentoPorHora[pico]) {
      pico = h;
    }
  }
  return pico;
}

// ---------------------------------------------------------------------------
// Nuvem (TagoIO)
// ---------------------------------------------------------------------------

// Acrescenta {"variable":..., "value":..., "unit":...} ao array JSON em montagem.
// O array comeca com "[" (json.length() == 1 significa "ainda vazio").
void adicionarVariavel(String& json, const char* variavel, float valor,
                       const char* unidade = nullptr, int casas = 2) {
  if (json.length() > 1) json += ",";
  json += "{\"variable\":\"";
  json += variavel;
  json += "\",\"value\":";
  String numero = String(valor, casas);
  numero.trim();  // String(x, 0) vem com espaco a esquerda (ex.: " 1")
  json += numero;
  if (unidade != nullptr) {
    json += ",\"unit\":\"";
    json += unidade;
    json += "\"";
  }
  json += "}";
}

// Envia o array JSON para o TagoIO. O horario de cada dado e carimbado pelo
// servidor ao receber (nao depende do relogio do ESP32).
bool enviarParaNuvem(const String& payload) {
  if (!nuvemHabilitada()) {
    statusNuvem = "OFF";
    return false;
  }
  if (WiFi.status() != WL_CONNECTED) {
    statusNuvem = "S/WIFI";
    return false;
  }

  // setInsecure(): nao valida o certificado do servidor. Aceitavel para o
  // piloto; em producao, trocar por client.setCACert(<certificado raiz>).
  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.setTimeout(5000);
  String urlNuvem = String(TAGOIO_API_HOST) + "/data";
  if (!http.begin(client, urlNuvem)) {
    statusNuvem = "ERRO";
    return false;
  }
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Device-Token", TAGOIO_DEVICE_TOKEN);

  int codigo = http.POST(payload);
  http.end();

  bool ok = (codigo >= 200 && codigo < 300);
  statusNuvem = ok ? "OK" : "ERRO";
  // O token nunca e impresso no log.
  Serial.printf("[NUVEM] HTTP %d %s\n", codigo, payload.c_str());
  return ok;
}

// Telemetria periodica: estado "de rotina" do ambiente.
void enviarTelemetria() {
  String json = "[";
  if (leituraValida) {
    adicionarVariavel(json, "temperatura", temperaturaAtual, "C", 1);
    adicionarVariavel(json, "umidade", umidadeAtual, "%", 1);
  }
  int hora = horaAtual();
  if (hora >= 0) {
    adicionarVariavel(json, "movimentos_hora", historicoMovimentoPorHora[hora], nullptr, 0);
  }
  if (WiFi.status() == WL_CONNECTED) {
    adicionarVariavel(json, "wifi_rssi", WiFi.RSSI(), "dBm", 0);
  }
  if (json.length() > 1) {
    json += "]";
    enviarParaNuvem(json);
  }
}

// ---------------------------------------------------------------------------
// Sensores e regras
// ---------------------------------------------------------------------------

// Chamada a cada nova deteccao do PIR (borda de subida).
void registrarMovimento(unsigned long agora) {
  int hora = horaAtual();
  if (hora >= 0) {
    historicoMovimentoPorHora[hora]++;
    totalMovimentos++;
  }
  Serial.printf("[EVENTO] Movimento (hora=%d, acumulado na hora=%u)\n",
                hora, hora >= 0 ? historicoMovimentoPorHora[hora] : 0U);

  String json = "[";
  adicionarVariavel(json, "movimento", 1, nullptr, 0);
  if (hora >= 0) {
    adicionarVariavel(json, "movimentos_hora", historicoMovimentoPorHora[hora], nullptr, 0);
  }

  int pico = horarioDePico();
  if (totalMovimentos > 0 && pico != picoEnviado) {
    adicionarVariavel(json, "pico_hora", pico, "h", 0);
    picoEnviado = pico;
  }

  bool foraDoExpediente = (hora >= 0) && (hora < HORA_ABERTURA || hora >= HORA_FECHAMENTO);
  bool cooldownOk = !alertaHorarioJaEnviado ||
                    (agora - ultimoAlertaHorarioMs >= COOLDOWN_ALERTA_HORARIO_MS);
  if (foraDoExpediente && cooldownOk) {
    adicionarVariavel(json, "alerta_fora_horario", 1, nullptr, 0);
    alertaHorarioJaEnviado = true;
    ultimoAlertaHorarioMs = agora;
    Serial.println("[ALERTA] Movimento fora do expediente");
  }

  json += "]";
  enviarParaNuvem(json);
}

// Le o PIR a cada ciclo do loop para nao perder pulsos curtos.
void verificarPIR(unsigned long agora) {
  movimentoAtual = (digitalRead(PIR_PIN) == HIGH);
  if (movimentoAtual && !movimentoAnterior) {
    registrarMovimento(agora);
  }
  movimentoAnterior = movimentoAtual;
}

// Le o DHT22, controla o rele e o alerta de temperatura (ambos com histerese).
void lerDhtEControlar() {
  float t = dht.readTemperature();
  float u = dht.readHumidity();
  if (isnan(t) || isnan(u)) {
    Serial.println("[DHT] leitura invalida");
    return;
  }
  temperaturaAtual = t;
  umidadeAtual = u;
  leituraValida = true;

  String json = "[";

  bool releAntes = releLigado;
  if (!releLigado && t > TEMP_RELE_LIGA_C) {
    releLigado = true;
  } else if (releLigado && t < TEMP_RELE_DESLIGA_C) {
    releLigado = false;
  }
  escreverRele(releLigado);
  if (releLigado != releAntes) {
    Serial.printf("[RELE] %s (temperatura %.1f C)\n", releLigado ? "LIGADO" : "DESLIGADO", t);
    adicionarVariavel(json, "rele", releLigado ? 1 : 0, nullptr, 0);
  }

  bool alertaAntes = alertaTemperaturaAtivo;
  if (!alertaTemperaturaAtivo && t > TEMP_ALERTA_LIGA_C) {
    alertaTemperaturaAtivo = true;
  } else if (alertaTemperaturaAtivo && t < TEMP_ALERTA_DESLIGA_C) {
    alertaTemperaturaAtivo = false;
  }
  if (alertaTemperaturaAtivo != alertaAntes) {
    Serial.printf("[ALERTA] Temperatura %s (%.1f C)\n",
                  alertaTemperaturaAtivo ? "ALTA" : "normalizada", t);
    adicionarVariavel(json, "alerta_temperatura", alertaTemperaturaAtivo ? 1 : 0, nullptr, 0);
  }

  if (json.length() > 1) {
    json += "]";
    enviarParaNuvem(json);
  }
}

// ---------------------------------------------------------------------------
// Wi-Fi
// ---------------------------------------------------------------------------
void conectarWiFi() {
  Serial.printf("[WIFI] Conectando em \"%s\"...\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long inicio = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - inicio < 15000) {
    delay(250);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Conectado. IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\n[WIFI] Sem conexao agora; vou continuar tentando.");
  }
  // Configura o NTP mesmo sem rede: sincroniza sozinho quando a rede voltar.
  configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, "pool.ntp.org", "time.nist.gov");
}

void garantirWiFi(unsigned long agora) {
  if (WiFi.status() == WL_CONNECTED) return;
  if (agora - ultimaTentativaWifiMs < INTERVALO_RECONEXAO_WIFI_MS) return;
  ultimaTentativaWifiMs = agora;
  Serial.println("[WIFI] Reconectando...");
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

// ---------------------------------------------------------------------------
// OLED
// ---------------------------------------------------------------------------
void atualizarDisplay() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 0);
  display.println("PulsoBiz Monitor");
  display.drawLine(0, 10, SCREEN_WIDTH, 10, SSD1306_WHITE);

  display.setCursor(0, 15);
  display.printf("Temp %.1fC  Umid %.0f%%", temperaturaAtual, umidadeAtual);

  display.setCursor(0, 25);
  display.printf("Mov:%s  Rele:%s", movimentoAtual ? "SIM" : "nao", releLigado ? "ON" : "off");

  display.setCursor(0, 35);
  if (totalMovimentos > 0) {
    display.printf("Pico ate agora: %02dh", horarioDePico());
  } else {
    display.print("Pico ate agora: --");
  }

  display.setCursor(0, 45);
  display.printf("Nuvem:%s Wifi:%s", statusNuvem, WiFi.status() == WL_CONNECTED ? "OK" : "--");

  display.setCursor(0, 55);
  if (alertaTemperaturaAtivo) {
    display.print("ALERTA: TEMP ALTA");
  } else {
    display.print("Alertas: nenhum");
  }

  display.display();
}

// ---------------------------------------------------------------------------
// Dashboard local (hospedado no proprio ESP32): / (HTML) e /dados (JSON)
// ---------------------------------------------------------------------------
void handleRaiz() {
  String html = "<html><head><meta charset='utf-8'>";
  html += "<meta http-equiv='refresh' content='5'>";
  html += "<title>PulsoBiz Monitor</title>";
  html += "<style>body{font-family:sans-serif;background:#111;color:#eee;padding:20px}";
  html += "h1{color:#4caf50} .barra{background:#4caf50;height:14px;margin:2px 0}</style>";
  html += "</head><body>";
  html += "<h1>PulsoBiz Monitor - Painel local</h1>";
  html += "<p>Temperatura: " + String(temperaturaAtual, 1) + " &deg;C</p>";
  html += "<p>Umidade: " + String(umidadeAtual, 1) + " %</p>";
  html += "<p>Movimento agora: " + String(movimentoAtual ? "SIM" : "nao") + "</p>";
  html += "<p>Rele: " + String(releLigado ? "LIGADO" : "desligado") + "</p>";
  html += "<p>Nuvem: " + String(statusNuvem) + "</p>";
  if (totalMovimentos > 0) {
    html += "<p><b>Horario de pico: " + String(horarioDePico()) + "h</b></p>";
  }
  html += "<h3>Movimento por hora</h3>";
  for (int h = 0; h < 24; h++) {
    html += "<div>" + String(h) + "h <div class='barra' style='width:" +
            String(historicoMovimentoPorHora[h] * 20) + "px'></div></div>";
  }
  html += "</body></html>";
  server.send(200, "text/html", html);
}

void handleDados() {
  String json = "{";
  json += "\"temperatura\":" + String(temperaturaAtual, 1) + ",";
  json += "\"umidade\":" + String(umidadeAtual, 1) + ",";
  json += "\"movimento\":" + String(movimentoAtual ? "true" : "false") + ",";
  json += "\"rele\":" + String(releLigado ? "true" : "false") + ",";
  json += "\"nuvem\":\"" + String(statusNuvem) + "\",";
  json += "\"historico\":[";
  for (int h = 0; h < 24; h++) {
    json += String(historicoMovimentoPorHora[h]);
    if (h < 23) json += ",";
  }
  json += "]}";
  server.send(200, "application/json", json);
}

// ---------------------------------------------------------------------------
// setup() / loop()
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);

  pinMode(PIR_PIN, INPUT);
  pinMode(RELAY_PIN, OUTPUT);
  escreverRele(false);

  dht.begin();

  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("[OLED] Falha ao iniciar o display.");
  }
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("PulsoBiz Monitor");
  display.println("Iniciando...");
  display.display();

  conectarWiFi();

  server.on("/", handleRaiz);
  server.on("/dados", handleDados);
  server.begin();

  if (nuvemHabilitada()) {
    statusNuvem = "AGUARD";
    Serial.println("[NUVEM] Token configurado: envio para o TagoIO ativo.");
  } else {
    Serial.println("[NUVEM] Sem token (secrets.h): envio desativado, so painel local.");
  }
}

void loop() {
  unsigned long agora = millis();

  garantirWiFi(agora);
  verificarPIR(agora);

  if (agora - ultimaLeituraDhtMs >= INTERVALO_LEITURA_DHT_MS) {
    ultimaLeituraDhtMs = agora;
    lerDhtEControlar();
  }

  bool telemetriaVenceu = (agora - ultimaTelemetriaMs >= INTERVALO_TELEMETRIA_MS);
  if ((primeiraTelemetriaPendente && leituraValida) || telemetriaVenceu) {
    primeiraTelemetriaPendente = false;
    ultimaTelemetriaMs = agora;
    enviarTelemetria();
  }

  if (agora - ultimoDisplayMs >= INTERVALO_DISPLAY_MS) {
    ultimoDisplayMs = agora;
    atualizarDisplay();
  }

  server.handleClient();
  delay(10);
}
