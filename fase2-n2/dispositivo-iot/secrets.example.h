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
