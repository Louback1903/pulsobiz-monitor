# Contrato de dados — PulsoBiz Monitor (N2)

Este arquivo é o "acordo" entre as 3 partes do projeto. **Não renomear variáveis sem avisar o grupo**: o firmware, o dashboard/alertas e o app dependem destes nomes.

```
[ESP32]  --HTTPS/JSON-->  [TagoIO: dashboard + e-mail + SMS]  --API REST-->  [App mobile]
```

## Como o dispositivo envia

- **Endpoint:** `POST https://api.tago.io/data`
- **Cabeçalhos:** `Content-Type: application/json` e `Device-Token: <token do device>`
- **Corpo:** array JSON, um objeto por variável. O horário de cada dado é carimbado pelo TagoIO ao receber.

```json
[
  {"variable": "temperatura", "value": 27.4, "unit": "C"},
  {"variable": "umidade", "value": 58.0, "unit": "%"}
]
```

## Variáveis

Nomes em minúsculas, sem acento, com `_` (padrão do TagoIO).

| Variável | Valor | Unidade | Quando é enviada | Uso na plataforma/app |
|---|---|---|---|---|
| `temperatura` | número | C | a cada 60 s | gráfico de linha + valor atual |
| `umidade` | número | % | a cada 60 s | gráfico de linha + valor atual |
| `movimentos_hora` | inteiro | - | a cada 60 s e a cada movimento | contador da hora atual |
| `wifi_rssi` | inteiro | dBm | a cada 60 s | diagnóstico do sinal |
| `movimento` | sempre `1` | - | a cada nova detecção do PIR | gráfico de barras: soma por hora (horário de pico) |
| `pico_hora` | inteiro 0-23 | h | quando o horário de pico muda | valor "Horário de pico" |
| `rele` | `0` ou `1` | - | quando o relé liga/desliga | indicador do ventilador |
| `alerta_temperatura` | `1` ou `0` | - | `1` ao passar de 32 C, `0` ao voltar abaixo de 31 C | **gatilho de alerta** (e-mail + SMS) |
| `alerta_fora_horario` | sempre `1` | - | movimento fora de 8h-18h, no máximo 1 a cada 5 min | **gatilho de alerta** (e-mail + SMS) |

Regras do dispositivo que o resto do grupo precisa conhecer:

- O relé liga acima de **28 C** e desliga abaixo de **27 C** (histerese).
- O expediente é **8h às 18h** (constantes `HORA_ABERTURA`/`HORA_FECHAMENTO` no firmware).
- `alerta_fora_horario` tem **cooldown de 5 minutos** no dispositivo para não estourar a cota de SMS/e-mail. Cada `1` recebido é uma ocorrência.
- `movimento` com valor `1` é um **evento**: para o gráfico por hora, use a soma agrupada por hora no dashboard.

## Alertas (gatilhos sugeridos para as Actions do TagoIO)

| Condição | Mensagem sugerida | Canais |
|---|---|---|
| `alerta_temperatura` = 1 | "Temperatura alta no ambiente: {{value}}" | e-mail + SMS |
| `alerta_fora_horario` = 1 | "Movimento detectado fora do expediente" | e-mail + SMS |

## Leitura pelo app (API REST)

- `GET https://api.tago.io/data?variable=temperatura&qty=1` com o cabeçalho `Device-Token` devolve a leitura mais recente.
- Parâmetros de consulta (`qty`, datas, ordenação): conferir na documentação oficial do TagoIO (seção Data, operação Get).
- **Segurança:** o token que o app usar fica dentro do APK e pode ser extraído. Para o piloto, usar um token separado do que o ESP32 usa quando o TagoIO permitir, nunca commitar no git e trocar o token depois da apresentação.

## Dimensionamento (estimativa para 1 dispositivo)

- Telemetria: 4 variáveis por minuto = **5.760 registros/dia**, mais os eventos.
- Alertas: no máximo **12 alertas de "fora do horário" por hora** (cooldown de 5 min) no pior caso. Conferir os limites do plano gratuito do TagoIO (registros/dia, e-mails e SMS) antes da demonstração.
- Para a demonstração ao vivo dá para baixar `INTERVALO_TELEMETRIA_MS` para 10 s no firmware.
