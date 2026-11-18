# App PulsoBiz (Flutter / Android)

App do **cliente** da PulsoBiz: cada comércio entra com o e-mail e a senha fornecidos pela PulsoBiz e vê só os dados da sua loja.

| Tela | O que mostra |
|---|---|
| Login | E-mail e senha (fornecidos pela PulsoBiz). A sessão fica salva e se renova sozinha |
| Painel | Temperatura, umidade, lotação, temperatura ideal, movimento, ventilador, status do dispositivo e gráfico de 24 h. Atualiza a cada 5 s |
| Relatório | Últimas 24 h: média de temperatura, movimentos, alertas, movimentos por hora, horário de pico e compartilhar |
| Alertas | Histórico dos últimos 30 alertas (temperatura alta e movimento fora do expediente) |
| Conta | Loja, e-mail, trocar senha e sair |

## Segurança

- O app guarda **só o login do cliente** (sessão do Supabase Auth). O token do dispositivo fica só no ESP32.
- A chave que aparece em `lib/config.dart` é a chave **pública** do Supabase (feita para ficar no app). O acesso aos dados depende do login.
- O servidor devolve só os dados da loja ligada ao login.

## Como rodar e gerar o APK

Pré-requisitos: Flutter e Android Studio (SDK em `D:\Android\Sdk`).

```powershell
$env:Path += ";D:\Pasta do ClaudeCode\tools\flutter\bin"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
cd "D:\Pasta do ClaudeCode\PulsoBiz\fase2-n2\app-mobile"
flutter pub get
flutter run                      # em um celular ou emulador conectado
flutter build apk --release      # gera build\app\outputs\flutter-apk\app-release.apk
```

Versão no navegador (sem Android): `flutter build web` e depois `.\abrir-app.ps1`.

O ícone do app é gerado a partir de `assets/brand/` com `dart run flutter_launcher_icons`.
A identidade visual (logo, ícones) está em `../identidade-visual/`.

## Observações

- O APK de teste é assinado com a chave de depuração. Para publicar na Play Store é preciso criar uma chave de assinatura própria (keystore).
- O pico mostrado no relatório é calculado nas últimas 24 h.
