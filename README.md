# PulsoBiz Monitor

Painel de monitoramento em tempo real, com reconhecimento de padrões, para pequenos comércios. Projeto de **Sistemas Embarcados** da Faculdade Nova Roma.

## Empresa, equipe e produto

- **Empresa:** PulsoBiz
- **Produto:** PulsoBiz Monitor
- **Equipe:** Júlio César, Rafael Luiz e Thiago Louback

### O problema (dor do cliente)

Donos de pequenos comércios (petshops, academias, salões, lojas de bairro) não sabem o que acontece no espaço da loja fora do horário em que estão presentes: não conhecem os horários de pico de movimento e não percebem variações de temperatura e umidade. Sistemas profissionais de CFTV e analytics custam caro demais para esse porte.

### A solução

Um dispositivo de baixo custo baseado em ESP32 que mede temperatura, umidade e movimento, aciona um atuador (ventilador) por um relé, mostra tudo num display OLED e descobre sozinho o **horário de pico** do estabelecimento (histograma de movimento por hora do dia).

| Componente | Função | Pino (ESP32) |
|---|---|---|
| ESP32 DevKit V1 | Microcontrolador | - |
| DHT22 | Temperatura e umidade | D4 |
| Sensor PIR | Presença e movimento | D27 |
| Módulo relé | Aciona o ventilador | D26 |
| Display OLED SSD1306 (I2C) | Leituras locais | D21 (SDA), D22 (SCL) |

## Fases do projeto

| Fase | Conteúdo | Status |
|---|---|---|
| Fase 1 | Dispositivo com sensores, relé, OLED, dashboard local e horário de pico, simulado no Wokwi | Concluída |
| N2 (2ª unidade) | Projeto de IoT completo: plataforma em nuvem (dashboard, SMS, e-mail), app mobile e dispositivo enviando dados | Em andamento (piloto em 18/11/2026) |

### Divisão do N2

| Parte | Responsável | Pasta |
|---|---|---|
| 1. Plataforma IoT em nuvem (Supabase: banco, dashboard, e-mail e SMS) | Júlio César | `fase2-n2/plataforma/` |
| 2. App mobile (Flutter) | Rafael Luiz | `fase2-n2/app-mobile/` |
| 3. Dispositivo IoT (ESP32) | Thiago Louback | `fase2-n2/dispositivo-iot/` |

Decisões do N2: o piloto é demonstrado no **simulador Wokwi** (sem hardware real) e o projeto usa **somente ferramentas gratuitas**. A plataforma começou no TagoIO, mas o envio nativo de e-mail e SMS dele foi descontinuado e exige serviços pagos; por isso a plataforma é **própria, no Supabase** (Postgres + Edge Function), com o mesmo contrato de dados.

As variáveis trocadas entre as 3 partes estão em [`fase2-n2/CONTRATO-DE-DADOS.md`](fase2-n2/CONTRATO-DE-DADOS.md). Os guias `DIVISAO-DE-TAREFAS` e `PASSO-A-PASSO-*` são do planejamento inicial (TagoIO) e ficam como histórico.

## Para ver o projeto rodando (professor)

| O que | Onde |
|---|---|
| Dashboard em tempo real (público, abre no celular) | https://frolicking-crumble-35774d.netlify.app |
| Código-fonte da plataforma | [`fase2-n2/plataforma/`](fase2-n2/plataforma/) (banco: `supabase/001_schema.sql`, função: `supabase/functions/data/index.ts`, dashboard: `dashboard/index.html`) |
| Código-fonte do dispositivo | [`fase2-n2/dispositivo-iot/sketch.ino`](fase2-n2/dispositivo-iot/sketch.ino) |
| Código-fonte do app | [`fase2-n2/app-mobile/lib/`](fase2-n2/app-mobile/lib/) |
| Simulador do dispositivo (Wokwi) | https://wokwi.com/projects/479147955272630273 |

Passo a passo para ver funcionando:
1. Abra o dashboard acima. Ele mostra temperatura, umidade, relé, movimento, horário de pico, **lotação** e **temperatura ideal**, atualizando a cada 5 s.
2. Os dados chegam do dispositivo (ESP32 simulado) ou do script de teste `fase2-n2/ferramentas/demo.ps1`, que usa o mesmo formato de dados. Ex.: `.\demo.ps1 entrada` soma uma pessoa na lotação e envia e-mail; `.\demo.ps1 alerta_temperatura` dispara e-mail e SMS.
3. O projeto do Wokwi é público e **não guarda o token** do dispositivo (segredo). Para enviar dados à nuvem pelo Wokwi, cole `#define TAGOIO_API_HOST ...` e `#define TAGOIO_DEVICE_TOKEN ...` no topo do `sketch.ino` (sem salvar). Sem isso o firmware roda localmente, com display e relé.

## Estrutura do repositório

```
fase1-wokwi/            Fase 1: sketch, circuito e bibliotecas (Wokwi)
fase2-n2/
  dispositivo-iot/      Firmware v2 do ESP32 (envia dados à plataforma na nuvem)
  plataforma/           Plataforma em nuvem: banco, Edge Function (alertas) e dashboard
  app-mobile/           App Flutter (ao vivo, relatório e alertas)
  ferramentas/          Simulador de dados e demo.ps1 para testar sem o ESP32
  CONTRATO-DE-DADOS.md  Variáveis, alertas e formato dos dados
  DIVISAO-DE-TAREFAS.md Tarefas de cada integrante
documentacao/           Documentação da Fase 1 (Word e PDF)
```

## Como rodar

**Simulação (sem hardware):** [Fase 1 no Wokwi](https://wokwi.com/projects/475972475555360769) e [N2 (firmware com envio à nuvem) no Wokwi](https://wokwi.com/projects/479147955272630273). Abra o link e clique em Play. Para gerar movimento, clique no sensor PIR e escolha "Simulate motion".

**Firmware do N2 (`fase2-n2/dispositivo-iot/`):**
1. Abra o `sketch.ino` no Arduino IDE (placa ESP32) ou no Wokwi, com as bibliotecas de `libraries.txt`.
2. Para enviar dados à nuvem, copie `secrets.example.h` para `secrets.h` e preencha a rede Wi-Fi, o `TAGOIO_API_HOST` (endereço da plataforma) e o Device Token (nomes herdados do TagoIO; valem para a plataforma atual).
3. Sem o `secrets.h` o firmware roda normalmente, só que sem enviar à nuvem.

**Simulador de dados (sem ESP32):** veja o topo de `fase2-n2/ferramentas/simulador_dados.py`.

## Segurança

- Token, senha de Wi-Fi e chaves **nunca** vão para o git: ficam em `secrets.h` ou em variável de ambiente, ambos no `.gitignore`.
- Se algum token vazar, trocar o token na plataforma (apagar do git não basta).

## Como contribuir

- Cada integrante trabalha na pasta da sua parte e faz commits pequenos, com mensagem clara.
- Atualize o `CONTRATO-DE-DADOS.md` no mesmo dia em que mudar o nome de uma variável.
