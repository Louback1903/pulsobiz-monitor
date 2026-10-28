// Copie este arquivo para "secrets.h" (na mesma pasta do sketch.ino) e preencha.
// "secrets.h" esta no .gitignore: NUNCA suba o token ou a senha do Wi-Fi para o git
// e nunca cole o token em chat/grupo (passe por canal privado).
//
// Sem secrets.h o firmware compila e roda, so que sem enviar para a nuvem
// (e usa a rede de simulacao "Wokwi-GUEST").

#define WIFI_SSID "nome-da-rede-wifi"
#define WIFI_PASSWORD "senha-da-rede-wifi"

// Device Token do dispositivo no TagoIO (Devices > seu device > Tokens).
#define TAGOIO_DEVICE_TOKEN "cole-aqui-o-device-token"

// Endereco da API do TagoIO da sua conta. Se nao definir, usa https://api.tago.io.
// Contas na regiao US East 1 podem precisar do endereco abaixo (descomente se for o caso).
// #define TAGOIO_API_HOST "https://api.us-e1.tago.io"

// Opcional, para a demonstracao (descomente se quiser):
// #define INTERVALO_TELEMETRIA_MS 10000UL   // envia a telemetria a cada 10 s (padrao: 60 s)
// #define HORA_FECHAMENTO 12                // expediente 8h-12h, para testar o alerta fora do horario
