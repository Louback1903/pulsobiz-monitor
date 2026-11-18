# App mobile (Flutter)

App que le os dados do TagoIO pela API REST e mostra tres telas
(mais uma opcional com o dashboard publico, como plano B).

| Tela | O que mostra |
|---|---|
| Ao vivo | Temperatura, umidade, movimento e rele; atualiza a cada 5 s |
| Relatorio | Ultimas 24 h: media de temperatura, movimentos, alertas, movimentos por hora, horario de pico e botao de compartilhar |
| Alertas | Ultimos 30 alertas recebidos (temperatura alta e movimento fora do expediente) |
| Dashboard | WebView com o dashboard publico (aparece so se `DASHBOARD_URL` estiver preenchido) |

## Como rodar

1. Instale o Flutter e rode `./setup.sh` dentro de `app-mobile/` (uma vez).
2. Copie `env.example.json` para `env.json` e preencha o token do device.
   O `env.json` esta no `.gitignore`: **nunca commitar o token**.
   Se a conta do TagoIO estiver em outra regiao, preencha tambem `TAGO_URL`
   (ex.: `https://api.us-e1.tago.io`).
3. Rode no celular/emulador:
   `flutter run --dart-define-from-file=env.json`
4. Gere o APK:
   `flutter build apk --release --dart-define-from-file=env.json`
   O arquivo sai em `build/app/outputs/flutter-apk/app-release.apk`.

## Configuracao dos dados

Os nomes das variaveis ficam em `lib/config.dart` e seguem o `CONTRATO-DE-DADOS.md`:
`temperatura`, `umidade`, `movimento`, `rele`, `alerta_temperatura` e
`alerta_fora_horario`.

O dispositivo envia `movimento = 1` somente quando detecta (nunca envia 0).
Por isso a tela Ao vivo mostra "Detectado" por 60 s apos o ultimo movimento e,
depois disso, "Ultimo: HH:mm". Os alertas contam so registros com valor 1: o
`alerta_temperatura` tambem chega com 0 quando a temperatura normaliza, e isso
nao e alerta.

## Como o relatorio e calculado

Janela das ultimas 24 h, em 24 blocos de 1 hora (o ultimo e a hora atual):
- temperatura media = media dos registros da janela;
- movimentos = registros de movimento verdadeiro;
- alertas = alertas ativos (valor 1) das duas variaveis na janela;
- pico = hora com mais movimentos.

O pico do app e calculado nas ultimas 24 h. O `pico_hora` enviado pelo
dispositivo e acumulado desde que ele foi ligado, entao os dois podem diferir.
Para conferir com o dashboard, compare usando o mesmo periodo.

## Seguranca

O token fica dentro do APK e pode ser extraido. Trocar o token no TagoIO
depois do dia 18/11.
