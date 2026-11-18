> **Documento histórico (planejamento inicial, TagoIO).** Em 18/11/2026 a plataforma passou a ser própria, no Supabase (o envio nativo de e-mail e SMS do TagoIO foi descontinuado). Veja o [`README.md`](../README.md) e [`plataforma/README.md`](plataforma/README.md) para o estado atual. O PDF correspondente também é histórico.

# PulsoBiz Monitor — Projeto N2: divisão de tarefas

**Entrega:** piloto funcionando + apresentação em **18/11/2026** (2ª Unidade / N2).
**Equipe:** Júlio César, Rafael Luiz e Thiago Louback.

O professor pede um projeto completo de IoT com 3 peças que conversam entre si:

```
[Dispositivo IoT]  --HTTPS/JSON-->  [Plataforma em nuvem]  --API REST-->  [App mobile]
  ESP32 + sensores                  dashboard + SMS + e-mail             telas e relatórios
```

## Quem faz o quê

| Parte | Exigência do professor | Responsável |
|---|---|---|
| 1. Plataforma IoT em nuvem | Dashboard, envio de SMS e envio de e-mail (alertas e avisos) | **Júlio César** |
| 2. App mobile | App de monitoramento que recebe os dados da plataforma e gera telas e relatórios | **Rafael Luiz** |
| 3. Dispositivo IoT | Aplicativo que envia os dados do ESP32 para a plataforma | **Thiago Louback** |

Se alguém preferir trocar de parte, é só combinar no grupo antes de começar. O que não muda são os nomes das variáveis do `CONTRATO-DE-DADOS.md`.

## Links e acessos

O repositório é do Thiago (conta `Louback1903`) e o Júlio e o Rafael são colaboradores: para abrir, é preciso estar logado no GitHub com a conta que recebeu o convite (aceite o convite por e-mail, ou em `github.com/Louback1903/pulsobiz-monitor/invitations`).

| O quê | Link |
|---|---|
| Repositório no GitHub | [github.com/Louback1903/pulsobiz-monitor](https://github.com/Louback1903/pulsobiz-monitor) |
| Simulador de dados (para testar sem o ESP32) | [simulador_dados.py](https://github.com/Louback1903/pulsobiz-monitor/blob/main/fase2-n2/ferramentas/simulador_dados.py) |
| Contrato de dados (nomes das variáveis) | [CONTRATO-DE-DADOS.md](https://github.com/Louback1903/pulsobiz-monitor/blob/main/fase2-n2/CONTRATO-DE-DADOS.md) |
| Passo a passo do Júlio e do Rafael | [pasta fase2-n2](https://github.com/Louback1903/pulsobiz-monitor/tree/main/fase2-n2) |
| Dispositivo rodando no Wokwi | [wokwi.com/projects/479147955272630273](https://wokwi.com/projects/479147955272630273) |
| Plataforma TagoIO | [admin.tago.io](https://admin.tago.io) |
| Python (para o simulador) | [python.org/downloads](https://www.python.org/downloads/) |

## Decisões já tomadas

- **Plataforma: TagoIO (confirmado).** É o exemplo que o professor mostrou, tem dashboard e alertas por e-mail/SMS embutidos e é o caminho mais rápido. O professor também aceita AWS e ThingSpeak.
- **Piloto no Wokwi (confirmado).** O dispositivo será demonstrado no simulador Wokwi, sem hardware real.
- **Só ferramentas gratuitas.** Se algo exigir pagamento (por exemplo, SMS no TagoIO), **não pague**: avise o Thiago, que leva ao professor.
- **Google Cloud (material do professor):** o Cloud IoT Core foi descontinuado em 16/08/2023. Hoje o Google recomenda 3 arquiteturas (MQTT Broker, IoT Platform, Device para Pub/Sub). Dá muito mais trabalho de configuração, então fica como **referência para citar na apresentação** como caminho de evolução.
- **Contrato de dados:** `fase2-n2/CONTRATO-DE-DADOS.md` define as variáveis, os alertas e o formato. É ele que permite as 3 partes serem feitas em paralelo.
- **Ninguém espera o hardware:** existe o simulador `fase2-n2/ferramentas/simulador_dados.py`, que envia dados de teste no mesmo formato do ESP32.

## Parte 1 — Plataforma IoT em nuvem (Júlio César)

**Objetivo:** receber os dados do dispositivo, mostrar num dashboard e avisar por e-mail e SMS quando algo sai do normal.

**Entregáveis**
1. Conta no TagoIO e um device "PulsoBiz Monitor" com o **Device Token**. Passe o token para o Thiago (firmware) e para o Rafael (app) por **mensagem privada**, nunca no grupo e nunca no git.
2. **Dashboard** com: valor atual de temperatura e umidade; gráfico de linha de temperatura e umidade nas últimas 24 h; gráfico de barras de movimentos por hora (soma de `movimento` agrupada por hora); valor do horário de pico (`pico_hora`); indicador do relé (`rele`); lista dos últimos alertas.
3. **Alertas por e-mail** (Actions do TagoIO): `alerta_temperatura` = 1 e `alerta_fora_horario` = 1, enviando para os 3 integrantes.
4. **Alertas por SMS**: mesmas condições. Confirmar no plano gratuito se SMS está incluído e quantos podem ser enviados. Se não estiver (e exigir plano pago), **não pague**: avisar o Thiago, que leva a dúvida ao professor.
5. **Link público do dashboard** para o Rafael usar no app (plano B rápido via WebView).
6. **Documento curto** `docs/plataforma.md` com prints e o passo a passo para refazer tudo (vai para o git).

**Pronto quando:** rodando `python simulador_dados.py --evento alerta_temperatura`, o dashboard atualiza e o e-mail e o SMS chegam em até 1 minuto.

## Parte 2 — App mobile (Rafael Luiz)

**Objetivo:** app que lê os dados da plataforma e mostra telas e relatórios.

**Telas mínimas**
1. **Painel ao vivo:** temperatura, umidade, movimento e relé, atualizando sozinho a cada poucos segundos.
2. **Histórico e relatório:** últimas 24 h, movimentos por hora e horário de pico, e um resumo do dia (média de temperatura, nº de movimentos, nº de alertas) com botão de compartilhar.
3. **Alertas:** lista dos últimos alertas recebidos.

**Como fazer**
- **Ferramenta:** App Inventor (no navegador, o mais rápido) ou Flutter, o que o grupo preferir. Se nunca fez app, comece pelo App Inventor.
- **Fonte dos dados:** API REST do TagoIO, descrita no `CONTRATO-DE-DADOS.md` (componente Web no App Inventor, pacote `http` no Flutter).
- **Plano B se travar:** uma tela com WebView mostrando o dashboard público do Júlio. Garante algo funcionando para a demonstração.
- **Segurança:** o token dentro do app pode ser extraído do APK. Nunca commitar o token no git e trocar o token depois do dia 18/11.

**Entregáveis:** projeto do app (arquivo `.aia` ou pasta Flutter) na pasta `app-mobile/` do repositório, APK instalável, prints das telas e um `docs/app.md` curto.

**Pronto quando:** com o simulador rodando, o app mostra os valores atualizando e o relatório do dia bate com o dashboard.

## Parte 3 — Dispositivo IoT (Thiago Louback)

**Já está pronto** (em `fase2-n2/dispositivo-iot/`): firmware v2 do ESP32 que mantém tudo da Fase 1 e agora envia telemetria e eventos ao TagoIO por HTTPS, com alertas de temperatura e de movimento fora do expediente, anti-spam de 5 minutos e reconexão do Wi-Fi.

**Falta fazer**
1. Receber o Device Token do Júlio e conferir os dados chegando no TagoIO (no Wokwi, colando o token só durante o teste: veja `fase2-n2/dispositivo-iot/DEMO-NO-WOKWI.md`).
2. Preparar a demonstração no Wokwi (decidido: o piloto é no simulador).
3. Ajustar o expediente e o intervalo de envio para a demonstração (`HORA_FECHAMENTO`, `INTERVALO_TELEMETRIA_MS`, no `secrets.h`).
4. Organizar o repositório no git e atualizar os slides do Canva e os documentos para o N2.

**Opcional, só se o grupo quiser mostrar hardware real:** ESP32 DevKit V1, sensor DHT22, sensor PIR (HC-SR501), módulo relé 5 V, display OLED SSD1306 I2C 0,96", protoboard e jumpers.

## Cronograma (alinhado à Jornada do professor)

| Período | Etapa da Jornada | O que deve estar pronto |
|---|---|---|
| até 30/10 | Desenho da solução e dimensionamento | Júlio: endereço da API, Device Token (privado) e resposta sobre SMS no plano gratuito |
| 31/10 a 02/11 | Experimento | Rafael: correções do app entregues e testadas com o simulador |
| 03/11 a 04/11 | Instalação, configuração e dashboards | Júlio: dashboard, alertas por e-mail e SMS e link público. Rafael: APK e prints |
| 05/11 | Teste integrado | Dispositivo (Wokwi), plataforma e app juntos, com dado real |
| 06/11 a 11/11 | Estabilização | Correção de falhas e conteúdo de cada um para os slides (até 11/11) |
| 12/11 a 17/11 | Ajustes e evoluções | Documentação no git, slides, ensaio (3 minutos por pessoa) e vídeo de reserva da demonstração |
| **18/11** | Apresentação do piloto | Cada um apresenta a sua parte e o grupo faz a demonstração completa |

## Regra de custo

Tudo que o projeto usar tem que ser **gratuito**. Se algo exigir pagamento ou plano pago (por exemplo, SMS no TagoIO), **não pague e não assine nada**: avise o Thiago com um print da tela, e ele leva a dúvida ao professor.

## Regras do grupo

- **Um repositório no git**, cada pessoa na sua pasta (`dispositivo-iot/`, `plataforma/`, `app-mobile/`), com commits pequenos e mensagens claras.
- **Nenhum segredo no git:** token, senha de Wi-Fi e chaves ficam em `secrets.h` ou variável de ambiente, que estão no `.gitignore`. Se um token vazar, trocar o token no TagoIO (apagar do git não basta).
- **Mudou um nome de variável?** Avise o grupo e atualize o `CONTRATO-DE-DADOS.md` no mesmo dia.
- **Travou por mais de 1 dia?** Avise no grupo. Melhor pedir ajuda cedo do que descobrir no dia 11/11.
