# Contrato de dados — PulsoBiz Monitor (N2)

Este arquivo é o "acordo" entre as 3 partes do projeto. **Não renomear variáveis sem avisar o grupo**: o firmware, o dashboard/alertas e o app dependem destes nomes.

```
[ESP32]  --HTTPS/JSON-->  [Plataforma Supabase: banco + dashboard + e-mail + SMS]  --API REST-->  [App mobile]
```

> **Atualização (18/11/2026):** a plataforma passou do TagoIO para uma plataforma própria no Supabase (o envio nativo de e-mail e SMS do TagoIO foi descontinuado). O formato abaixo foi mantido igual, então firmware, simulador e app só mudam o endereço base. Os nomes `TAGOIO_API_HOST`, `TAGOIO_DEVICE_TOKEN` e `TAGO_URL` continuam por herança. Detalhes em [`plataforma/README.md`](plataforma/README.md).

## Como o dispositivo envia

- **Endpoint:** `POST <host>/data`. Host atual: `https://mhkaowtdlwbtrnqbftcr.supabase.co/functions/v1` (configurável: `TAGOIO_API_HOST` no firmware e no simulador, `TAGO_URL` no app)
- **Cabeçalhos:** `Content-Type: application/json` e `Device-Token: <token do device>`
- **Corpo:** array JSON, um objeto por variável. O horário de cada dado é carimbado pelo servidor ao receber.

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

Variáveis de lotação (tratadas pela plataforma; hoje enviadas pelo script de teste, num produto real viriam de dois sensores, porta de entrada e de saída):

| Variável | Valor | Efeito na plataforma |
|---|---|---|
| `entrada` | sempre `1` | lotação +1, e-mail "Lotação N" |
| `saida` | sempre `1` | lotação -1 (nunca abaixo de 0), e-mail "Lotação N" |
| `lotacao_reset` | `1` | zera a lotação |

Temperatura ideal = `25 °C - 0,5 °C × pessoas`, com piso de 21 °C. Quando a meta muda, a plataforma espera 3 leituras seguidas de `temperatura` a ±0,5 °C da meta e envia o e-mail "Temperatura estabilizada". O dashboard mostra lotação, meta e se está "estabilizada" ou "ajustando".

Regras do dispositivo que o resto do grupo precisa conhecer:

- O relé liga acima de **28 C** e desliga abaixo de **27 C** (histerese).
- O expediente é **8h às 18h** (constantes `HORA_ABERTURA`/`HORA_FECHAMENTO` no firmware).
- `alerta_fora_horario` tem **cooldown de 5 minutos** no dispositivo para não estourar a cota de SMS/e-mail. Cada `1` recebido é uma ocorrência.
- `movimento` com valor `1` é um **evento**: para o gráfico por hora, use a soma agrupada por hora no dashboard.

## Alertas (disparados pela Edge Function da plataforma)

| Condição | Mensagem | Canais |
|---|---|---|
| `alerta_temperatura` = 1 | "Temperatura alta no ambiente (XX.X C)" | e-mail + SMS |
| `alerta_fora_horario` = 1 | "Movimento detectado fora do expediente" | e-mail + SMS |
| `entrada` / `saida` | "Lotação N, temperatura ideal X °C" | e-mail |
| 3 leituras na meta | "Temperatura estabilizada em X °C" | e-mail |

O mesmo alerta de temperatura ou fora do horário só dispara de novo depois de 60 s. O SMS usa o Twilio; na conta de teste só são aceitos modelos de mensagem prontos, então o texto do SMS é o modelo de alerta do Twilio (o e-mail leva o texto completo).

## Leitura pelo app (API REST)

- `GET <host>/data?variable=temperatura&qty=1` com o cabeçalho `Device-Token` devolve `{"status":true,"result":[{"variable","value","unit","time"}]}`, da mais recente para a mais antiga. Parâmetros: `variable`, `qty` (até 10000) e `start_date`.
- `GET <host>/data?view=dashboard` (público, só leitura) devolve os dados prontos do dashboard.
- **Segurança:** o token que o app usar fica dentro do APK e pode ser extraído. Nunca commitar no git e trocar o token depois da apresentação.

## Dimensionamento (estimativa para 1 dispositivo)

- Telemetria: 4 variáveis por minuto = **5.760 registros/dia**, mais os eventos.
- Alertas: no máximo **12 alertas de "fora do horário" por hora** (cooldown de 5 min) no pior caso. Conferir os limites do plano gratuito do TagoIO (registros/dia, e-mails e SMS) antes da demonstração.
- Para a demonstração ao vivo dá para baixar `INTERVALO_TELEMETRIA_MS` para 10 s no firmware.
