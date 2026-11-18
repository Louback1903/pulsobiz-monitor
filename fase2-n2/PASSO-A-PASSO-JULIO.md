> **Documento histórico (planejamento inicial, TagoIO).** Em 18/11/2026 a plataforma passou a ser própria, no Supabase (o envio nativo de e-mail e SMS do TagoIO foi descontinuado). Veja o [`README.md`](../README.md) e [`plataforma/README.md`](plataforma/README.md) para o estado atual. O PDF correspondente também é histórico.

# Passo a passo — Júlio César (plataforma na nuvem)

**Projeto:** PulsoBiz Monitor, N2. **Piloto:** 18/11/2026. **Quem pede:** Thiago Louback.

## O que é a sua parte

O dispositivo (ESP32) manda os dados para a plataforma, e a sua parte é fazer essa plataforma **receber, mostrar e avisar**. O professor exige 3 coisas: **dashboard**, **envio de SMS** e **envio de e-mail** (alertas e avisos). O Rafael vai ler os dados da sua plataforma no app dele, então o que você montar tem que seguir os nomes do `CONTRATO-DE-DADOS`.

**Prazo urgente (item 1 a 3): 30/10. Prazo do resto: 04/11.**

## Links e acessos

Você é colaborador do repositório do projeto. Para abrir, use o GitHub logado com a conta que recebeu o convite (aceite o convite por e-mail, ou em `github.com/Louback1903/pulsobiz-monitor/invitations`).

| O quê | Link |
|---|---|
| Repositório no GitHub | [github.com/Louback1903/pulsobiz-monitor](https://github.com/Louback1903/pulsobiz-monitor) |
| Pasta do N2 (guias e ferramentas) | [fase2-n2](https://github.com/Louback1903/pulsobiz-monitor/tree/main/fase2-n2) |
| Simulador de dados (Passo 3) | [simulador_dados.py](https://github.com/Louback1903/pulsobiz-monitor/blob/main/fase2-n2/ferramentas/simulador_dados.py) |
| Contrato de dados (nomes das variáveis) | [CONTRATO-DE-DADOS.md](https://github.com/Louback1903/pulsobiz-monitor/blob/main/fase2-n2/CONTRATO-DE-DADOS.md) |
| Dispositivo rodando no Wokwi | [wokwi.com/projects/479147955272630273](https://wokwi.com/projects/479147955272630273) |
| Plataforma TagoIO (sua conta) | [admin.tago.io](https://admin.tago.io) |
| Python (para o simulador) | [python.org/downloads](https://www.python.org/downloads/) |
| GitHub Desktop (opcional) | [desktop.github.com](https://desktop.github.com/) |

**O que você precisa entregar para os outros:**

- Para o **Rafael** e o **Thiago**, no privado: o **Device Token**. No grupo: o **endereço da API** da conta e o **link público do dashboard**.
- Para o **Thiago**, no grupo: a resposta sobre **SMS no plano**.

## Antes de começar

- A sua conta do TagoIO funcionando ([admin.tago.io](https://admin.tago.io)).
- O link `admin.tago.io/template/...` que você mandou só abre dentro da sua conta, então o grupo não consegue avaliar o que você montou. Para o grupo, você vai mandar **prints** e um **link público** do dashboard (Passo 4).
- Python 3 instalado, para rodar o simulador de dados (Passo 3).
- O e-mail e o celular dos 3 integrantes, para os alertas. Cada um passa o seu para você **no privado**.

## O que o dispositivo envia

| Variável | Valor | Quando envia |
|---|---|---|
| `temperatura` | número (C) | a cada 60 s |
| `umidade` | número (%) | a cada 60 s |
| `movimentos_hora` | inteiro | a cada 60 s e a cada movimento |
| `wifi_rssi` | inteiro (dBm) | a cada 60 s |
| `movimento` | sempre 1 | quando o sensor detecta alguém |
| `pico_hora` | 0 a 23 | quando o horário de pico muda |
| `rele` | 0 ou 1 | quando o relé liga ou desliga |
| `alerta_temperatura` | 1 ou 0 | 1 ao passar de 32 C; **0 quando volta abaixo de 31 C** |
| `alerta_fora_horario` | sempre 1 | movimento fora do horário de 8h às 18h |

## Passo 1 — Descobrir o endereço da API da sua conta

A sua conta está na região `api.us-e1.tago.io`. O dispositivo e o app usam por padrão o endereço `https://api.tago.io`. Pode ser que a sua conta aceite os dois, ou pode ser que só aceite o da região. Você vai descobrir no Passo 3, testando. **Anote qual funcionou** e avise o grupo.

## Passo 2 — Criar o device e pegar o token

Os nomes dos menus podem variar um pouco, porque o TagoIO muda a tela de tempos em tempos. Se algo estiver diferente do descrito, tire um print e mande para o Thiago.

1. No TagoIO, abra **Devices** e clique para **adicionar um device** (botão de "+" ou "Add device").
2. Como tipo de conexão (connector), escolha **Custom HTTPS** (ou "Custom").
3. Dê o nome **PulsoBiz Monitor** e crie.
4. Abra o device criado e procure o **token** (aba **Tokens**, ou o campo "Device token" na página do device).
5. Copie o token e mande **no privado** para o Rafael e para o Thiago.

**Atenção:** o token é uma senha. Nunca coloque no grupo, nunca coloque em print (cubra com um retângulo) e nunca coloque no git.

## Passo 3 — Testar que os dados chegam

O Thiago deixou um programa que envia dados de teste, no mesmo formato do dispositivo.

1. Instale o Python 3 (python.org), marcando a opção **Add Python to PATH**.
2. Pegue o simulador no repositório: clone o projeto (Passo 10, item 1) ou abra o link do [simulador_dados.py](https://github.com/Louback1903/pulsobiz-monitor/blob/main/fase2-n2/ferramentas/simulador_dados.py), clique em **Raw** e salve o arquivo.
3. Abra um terminal (PowerShell) na pasta onde está o `simulador_dados.py`.
4. Informe o token (troque pelo seu):

```
$env:TAGOIO_DEVICE_TOKEN = "cole-aqui-o-token-do-device"
```

5. Envie um teste:

```
python simulador_dados.py
```

6. Tem que aparecer `HTTP 200`. Se aparecer outro número, vá para o **Passo 3b**.
7. No TagoIO, abra o device e veja a aba **Live Inspector** (ou **Data**): as variáveis `temperatura`, `umidade`, `movimentos_hora` e `wifi_rssi` devem aparecer.

**Passo 3b — Se não deu `HTTP 200`.** Informe o endereço da região e tente de novo:

```
$env:TAGOIO_API_HOST = "https://api.us-e1.tago.io"
python simulador_dados.py
```

Se funcionar com o endereço da região, **avise o grupo**, porque o app e o dispositivo vão precisar usar esse endereço.

### Criar as variáveis que faltam

Para o dashboard conseguir escolher todas as variáveis, envie um evento de cada tipo, um comando por vez:

```
python simulador_dados.py --evento movimento
python simulador_dados.py --evento pico_hora
python simulador_dados.py --evento rele_ligado
python simulador_dados.py --evento alerta_temperatura
python simulador_dados.py --evento alerta_temperatura_fim
python simulador_dados.py --evento alerta_fora_horario
```

**Atenção:** os dois comandos de alerta (`alerta_temperatura` e `alerta_fora_horario`) vão disparar os e-mails e SMS se você já tiver criado as Actions. Por isso, **faça isso antes do Passo 5**, ou avise o grupo antes de testar.

Para o dashboard ficar com dados ao longo do tempo (bom para os gráficos), deixe rodando por alguns minutos:

```
python simulador_dados.py --loop
```

Para parar, aperte `Ctrl + C`.

## Passo 4 — Montar o dashboard

1. Abra **Dashboards**, crie um novo e chame de **PulsoBiz Monitor**.
2. Adicione os widgets abaixo, um por vez. Em cada um você escolhe o device **PulsoBiz Monitor** e a variável.

| Widget | Variável | O que configurar |
|---|---|---|
| Valor atual (Display) | `temperatura` | mostrar o último valor; unidade C |
| Valor atual (Display) | `umidade` | mostrar o último valor; unidade % |
| Gráfico de linha | `temperatura` e `umidade` | período das últimas 24 horas |
| Gráfico de barras | `movimento` | período de 24 horas; **soma agrupada por hora** (mostra o movimento por hora) |
| Valor atual (Display) | `pico_hora` | título "Horário de pico (h)" |
| Valor atual (Display) | `rele` | título "Ventilador"; 1 é ligado, 0 é desligado |
| Tabela | `alerta_temperatura` e `alerta_fora_horario` | os registros mais recentes |

3. Gere o **link público**: no dashboard, procure a opção de **compartilhar** (Share ou Sharing) e ative o link público.
4. **Teste o link:** abra em uma **janela anônima** do navegador. Se mostrar os dados sem pedir login, está certo.
5. Mande o link para o Rafael (a tela de dashboard dentro do app usa esse link).

## Passo 5 — Alertas por e-mail

Crie 2 alertas (em **Actions**). Os dois seguem o mesmo roteiro.

**Alerta 1: movimento fora do horário**

1. Em **Actions**, crie uma nova Action e chame de "Alerta fora do horario".
2. Como gatilho (trigger), escolha **variável**: device **PulsoBiz Monitor**, variável `alerta_fora_horario`.
3. Condição: o valor é **igual a 1**.
4. Como ação, escolha **enviar e-mail**, com os e-mails dos 3 integrantes.
5. Assunto e mensagem: "PulsoBiz: movimento detectado fora do expediente".
6. Salve.

**Alerta 2: temperatura alta**

1. Nova Action, nome "Alerta temperatura alta".
2. Gatilho: variável `alerta_temperatura`.
3. Condição: o valor é **igual a 1**.
4. Ação: enviar e-mail para os 3, mensagem "PulsoBiz: temperatura alta no ambiente".
5. Salve.

**ATENÇÃO — o erro mais fácil de cometer:** o `alerta_temperatura` também chega com valor **0** quando a temperatura volta ao normal. Se a condição não for exatamente "igual a 1", o sistema vai mandar um alerta falso quando tudo normalizar. Confira que as duas Actions só disparam com valor 1.

## Passo 6 — Alertas por SMS

Em cada uma das duas Actions do Passo 5, adicione também uma ação de **enviar SMS** (ou crie duas Actions novas só de SMS, com o mesmo gatilho e a mesma condição).

- Coloque os celulares dos 3 integrantes com o código do país e o DDD, por exemplo `+5581999999999`.
- **Antes de tudo, descubra se o seu plano do TagoIO inclui SMS.** Em muitos planos gratuitos o SMS é limitado ou pago.
- **Não pague nada.** O projeto só pode usar o que for gratuito. Se o SMS não estiver disponível no plano gratuito, avise o Thiago com um print da tela: ele leva a dúvida ao professor.
- Responda no grupo: **o plano inclui SMS? Quantos por mês?** (prazo: 30/10).

## Passo 7 — Testar os alertas

Com as Actions criadas, rode, um por vez (espere o resultado de cada um):

```
python simulador_dados.py --evento alerta_fora_horario
python simulador_dados.py --evento alerta_temperatura
python simulador_dados.py --evento alerta_temperatura_fim
```

Confira:

- [ ] O 1º comando gera e-mail e SMS em até 1 minuto.
- [ ] O 2º comando gera e-mail e SMS em até 1 minuto.
- [ ] O 3º comando **não** gera nada.
- [ ] O dashboard mostra os alertas na tabela.

Tire print do e-mail e do SMS recebidos (cubra o número de telefone).

## Passo 8 — Prints para entregar

Tire estes prints e **cubra o token e os telefones**:

- [ ] O dashboard completo.
- [ ] A lista de Actions, e a configuração de cada uma (mostrando a condição "igual a 1").
- [ ] O e-mail recebido.
- [ ] O SMS recebido (ou a tela mostrando que o plano não inclui).
- [ ] O device com os dados chegando (Live Inspector).

## Passo 9 — Escrever o `docs/plataforma.md`

Um documento curto, com o passo a passo para refazer tudo. Tópicos:

1. Qual endereço de API a conta usa.
2. Como o device foi criado e quais variáveis ele recebe (a tabela deste documento serve).
3. Quais widgets o dashboard tem e o que cada um mostra (com os prints).
4. As Actions: gatilho, condição e a mensagem de cada uma.
5. Como testar (os comandos do simulador).
6. Limites do plano: quantos SMS e e-mails por mês.

## Passo 10 — Enviar para o repositório

Você já foi adicionado como colaborador. Se ainda não aceitou o convite, aceite pelo e-mail ou em `github.com/Louback1903/pulsobiz-monitor/invitations`. Sem isso o push é recusado.

1. Clone o repositório (GitHub Desktop: Clone repository, ou no terminal). Se já clonou antes, rode `git pull` para pegar as novidades:

```
git clone https://github.com/Louback1903/pulsobiz-monitor.git
```

2. Crie a pasta `fase2-n2/plataforma/` e coloque dentro o `docs/plataforma.md` e as imagens (prints).
3. **Antes de commitar, confira os prints:** nenhum pode mostrar o token nem telefones.
4. Envie:

```
git add fase2-n2/plataforma
git commit -m "Plataforma TagoIO: dashboard, alertas e documentacao"
git push
```

## Se der erro

| O que aparece | O que provavelmente é | O que fazer |
|---|---|---|
| `HTTP 401` | token errado, ou o endereço da região é outro | confira o token; faça o Passo 3b |
| `HTTP 404` | endereço da API errado | faça o Passo 3b |
| `python` não é reconhecido | Python não está no PATH | reinstale marcando "Add Python to PATH" |
| "Defina a variavel de ambiente..." | o token não foi informado nessa janela do terminal | repita o comando do `$env:TAGOIO_DEVICE_TOKEN` |
| `HTTP 200`, mas nada aparece no TagoIO | está olhando o device errado | confira que o token é do device "PulsoBiz Monitor" |
| Chegou alerta quando a temperatura normalizou | a condição da Action não é "igual a 1" | corrija a condição (Passo 5) |
| Não chega e-mail | o e-mail caiu em spam, ou a Action está desativada | veja o spam e confira que a Action está ativa |
| Não chega SMS | o plano gratuito não inclui SMS | não pague; avise o Thiago com print (Passo 6) |

## O que entregar ao Thiago

| O quê | Canal | Prazo |
|---|---|---|
| Qual endereço de API funcionou (e se o padrão `api.tago.io` serve) | grupo | 30/10 |
| Device Token | privado | 30/10 |
| Resposta: o plano inclui SMS? Quantos? | grupo | 30/10 |
| Link público do dashboard | grupo | 04/11 |
| Prints do dashboard, das Actions e dos alertas recebidos | grupo | 04/11 |
| `docs/plataforma.md` em `fase2-n2/plataforma/` | git | 04/11 |
| Para os slides: 3 a 5 linhas do que a plataforma faz e 2 prints bons | grupo | 11/11 |

## Regras

- **Token nunca no grupo, nunca em print e nunca no git.** Só em mensagem privada. Se vazar, troque o token no TagoIO.
- Mudou o nome de uma variável? Avise o grupo no mesmo dia.
- **Travou por mais de 1 dia?** Avise o Thiago, com print.
- **Tudo tem que ser gratuito.** Se algo pedir plano pago, não pague: avise o Thiago, que leva ao professor.
- O piloto é demonstrado no **Wokwi** (decidido), então não precisa de hardware real.
