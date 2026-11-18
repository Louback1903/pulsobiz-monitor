# Plataforma em nuvem (Supabase)

Recebe os dados do dispositivo, guarda no banco, mostra no dashboard e envia os alertas por e-mail e SMS.
Dashboard público: https://frolicking-crumble-35774d.netlify.app

```
ESP32 / simulador --POST /data (Device-Token)--> Edge Function "data" --> Postgres (readings)
                                                        |--> e-mail (Gmail SMTP) e SMS (Twilio)
Dashboard (HTML)  --GET /data?view=dashboard--> Edge Function
App               --GET /data?variable=...  --> Edge Function (Device-Token)
```

## Multi-loja (cada cliente com o seu painel)

A plataforma atende várias lojas. Cada loja tem o seu **device token** (usado só pelo ESP32 para enviar dados) e um ou mais **logins** (e-mail e senha, Supabase Auth) ligados a ela. O cliente só enxerga a própria loja. A PulsoBiz cria os clientes com `ferramentas/criar-cliente.ps1`; veja [`ONBOARDING-CLIENTE.md`](ONBOARDING-CLIENTE.md).

| Quem chama | Credencial | Pode |
|---|---|---|
| Dispositivo (ESP32) | `Device-Token` da loja | enviar dados (`POST /data`) e ler |
| Cliente (app/dashboard) | login (JWT) | ler os dados da própria loja |
| Visitante sem login | nenhuma | ver só o dashboard da **loja de demonstração** (`?view=dashboard`) |
| PulsoBiz | `X-Admin-Token` | criar clientes, redefinir senha, listar (`?admin=`) |

## Arquivos

| Arquivo | O que é |
|---|---|
| `supabase/001_schema.sql` | Tabelas `readings`, `config`, `alert_log`. Segurança por linha (RLS) ligada e **sem políticas**: o público não acessa o banco direto, só a função (service role). |
| `supabase/002_multi_loja.sql` | Tabelas `lojas` e `membros`, `loja_id` nos dados e consultas por loja. |
| `supabase/functions/data/index.ts` | Edge Function (Deno): identifica a loja pela credencial, recebe dados, dispara alertas, calcula lotação e temperatura ideal por loja, serve o dashboard/leitura e a administração. Publicada com `verify_jwt = false` e verificação própria. |
| `dashboard/index.html` | Dashboard web em um arquivo só (HTML, CSS e JS), com tela de login e a marca PulsoBiz. Atualiza a cada 5 s. Hospedado no Netlify. |

## Segredos (nunca no git)

O token do dispositivo fica na tabela `config` (gerado no banco). Os segredos de envio ficam em **Supabase > Edge Functions > Secrets**:
`SMTP_USER`, `SMTP_PASS` (senha de app do Gmail), `MAIL_TO`, `TWILIO_SID`, `TWILIO_TOKEN`, `TWILIO_FROM`, `SMS_TO` (os dois últimos valem para a loja de demonstração; as outras lojas usam os destinatários cadastrados nelas) e `ADMIN_TOKEN` (liga a criação de clientes).

## Regras da plataforma

- **Alertas:** `alerta_temperatura` = 1 e `alerta_fora_horario` = 1 enviam e-mail e SMS; o mesmo tipo não repete em 60 s.
- **Lotação:** `entrada` soma 1, `saida` subtrai 1 (nunca abaixo de 0), `lotacao_reset` zera. Cada mudança envia e-mail (máximo 20 em 10 minutos).
- **Temperatura ideal:** `25 °C - 0,5 °C por pessoa`, piso 21 °C. Quando a meta muda, 3 leituras seguidas a ±0,5 °C dela geram o e-mail "Temperatura estabilizada".
- **SMS na conta de teste do Twilio:** só aceita modelos prontos. Se o texto livre for recusado (erro 572006), a função usa o modelo `sms_internal_alerts`. Com plano pago, o texto personalizado é enviado automaticamente.

## Como publicar de novo

1. Rodar `supabase/001_schema.sql` e depois `supabase/002_multi_loja.sql` no SQL Editor do projeto.
2. Publicar `supabase/functions/data/index.ts` como função `data` com a verificação de JWT desligada.
3. Cadastrar os segredos acima.
4. Colocar o endereço da função em `dashboard/index.html` (`const API`) e publicar a pasta `dashboard/`.

## Testar sem o dispositivo

Veja `../ferramentas/demo.ps1` (envia dados de teste no mesmo formato do ESP32).
