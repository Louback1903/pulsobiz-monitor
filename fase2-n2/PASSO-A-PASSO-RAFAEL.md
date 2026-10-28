# Passo a passo — Rafael Luiz (app mobile)

**Projeto:** PulsoBiz Monitor, N2. **Piloto:** 18/11/2026. **Quem pede:** Thiago Louback.

## O que é a sua parte

O dispositivo (ESP32) manda os dados para o TagoIO, e o seu app lê esses dados e mostra em telas e relatórios. O seu app já está bem adiantado: tem as 3 telas, o plano B com o dashboard, o token fora do código e testes. Falta ajustar **2 coisas que impedem o app de funcionar com o dispositivo de verdade** e fazer alguns ajustes pequenos.

**Prazo das correções: 02/11. Prazo do APK e dos prints: 04/11.**

## Links e acessos

Você é colaborador do repositório do projeto. Para abrir, use o GitHub logado com a conta que recebeu o convite (aceite o convite por e-mail, ou em `github.com/Louback1903/pulsobiz-monitor/invitations`).

| O quê | Link |
|---|---|
| Repositório no GitHub | [github.com/Louback1903/pulsobiz-monitor](https://github.com/Louback1903/pulsobiz-monitor) |
| Pasta do N2 (guias e ferramentas) | [fase2-n2](https://github.com/Louback1903/pulsobiz-monitor/tree/main/fase2-n2) |
| Simulador de dados (Passo 8) | [simulador_dados.py](https://github.com/Louback1903/pulsobiz-monitor/blob/main/fase2-n2/ferramentas/simulador_dados.py) |
| Contrato de dados (nomes das variáveis) | [CONTRATO-DE-DADOS.md](https://github.com/Louback1903/pulsobiz-monitor/blob/main/fase2-n2/CONTRATO-DE-DADOS.md) |
| Dispositivo rodando no Wokwi | [wokwi.com/projects/479147955272630273](https://wokwi.com/projects/479147955272630273) |
| Plataforma TagoIO (conta do Júlio) | [admin.tago.io](https://admin.tago.io) |
| Instalar o Flutter | [docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install) |
| Python (para o simulador) | [python.org/downloads](https://www.python.org/downloads/) |
| GitHub Desktop (opcional) | [desktop.github.com](https://desktop.github.com/) |

**O que você precisa receber de outras pessoas:**

- Do **Júlio**, no privado: o **Device Token** do TagoIO. Do Júlio, no grupo: o **endereço da API** da conta dele (a conta está em `api.us-e1.tago.io`, e o endereço padrão do app é `https://api.tago.io`, então pode ser que precise trocar) e o **link público do dashboard**.
- Do **Thiago**: nada pendente. Se o repositório não abrir para você, avise.

## Antes de começar

- O Flutter instalado e o projeto `app-mobile` abrindo normalmente.
- Acesso ao repositório (tabela acima).
- O Device Token e o endereço da API (veja acima).

## O que o dispositivo envia (o que importa para o app)

| Variável | Valor | Observação |
|---|---|---|
| `temperatura` | número (C) | a cada 60 s |
| `umidade` | número (%) | a cada 60 s |
| `movimento` | sempre 1 | só quando detecta; **nunca envia 0** |
| `rele` | 0 ou 1 | só quando o relé muda |
| `alerta_temperatura` | 1 ou 0 | 1 = temperatura alta, 0 = voltou ao normal |
| `alerta_fora_horario` | sempre 1 | movimento fora do expediente |

## As 2 correções obrigatórias

1. **Alertas nunca aparecem.** O app busca uma variável chamada `alerta`, que o dispositivo não envia. As variáveis reais são `alerta_temperatura` e `alerta_fora_horario`.
2. **O movimento fica "Detectado" para sempre.** O dispositivo só avisa quando detecta (valor 1) e nunca manda 0. Como a tela Ao vivo mostra o último valor, depois do primeiro movimento ela nunca mais volta para "Sem movimento".

## Passo 1 — Corrigir o `config.dart`

Abra `lib/config.dart`. Procure esta linha:

```
static const String varAlerta = 'alerta';
```

Apague e coloque no lugar estas duas:

```
static const String varAlertaTemp = 'alerta_temperatura';
static const String varAlertaHorario = 'alerta_fora_horario';
```

Salve. O Flutter vai marcar erro em outros arquivos que ainda usam `varAlerta`: é normal, os próximos passos resolvem.

## Passo 2 — Criar a busca de alertas no `tago_service.dart`

Abra `lib/tago_service.dart`. Logo **depois** do método `latest` (antes da `}` final da classe), cole:

```
  /// Alertas ativos (valor 1) das duas variaveis, do mais recente para o mais antigo.
  Future<List<Reading>> fetchAlertas({int qty = 30, DateTime? start}) async {
    final r = await Future.wait([
      fetch(Config.varAlertaTemp, qty: qty, start: start),
      fetch(Config.varAlertaHorario, qty: qty, start: start),
    ]);
    final todos = [...r[0], ...r[1]].where((a) => toBool(a.value)).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    return todos.length > qty ? todos.sublist(0, qty) : todos;
  }
```

**Por que assim:** o filtro `toBool(a.value)` descarta os alertas com valor 0 (o `alerta_temperatura` manda 0 quando a temperatura normaliza, e isso não é alerta).

## Passo 3 — Tela de alertas (`alerts_screen.dart`)

Faça 3 trocas no arquivo `lib/screens/alerts_screen.dart`.

**3a.** No `initState`, troque:

```
_future = _svc.fetch(Config.varAlerta, qty: 30);
```

por:

```
_future = _svc.fetchAlertas(qty: 30);
```

**3b.** No `_refresh`, troque:

```
final f = _svc.fetch(Config.varAlerta, qty: 30);
```

por:

```
final f = _svc.fetchAlertas(qty: 30);
```

**3c.** Troque o método `_mensagem` inteiro por:

```
  String _mensagem(Reading r) => r.variable == Config.varAlertaTemp
      ? 'Temperatura alta no ambiente'
      : 'Movimento fora do expediente';
```

## Passo 4 — Tela de relatório (`history_screen.dart`)

No método `_load` de `lib/screens/history_screen.dart`, troque a **terceira** linha da lista do `Future.wait`:

```
_svc.fetch(Config.varAlerta, qty: 1000, start: start),
```

por:

```
_svc.fetchAlertas(qty: 1000, start: start),
```

Assim o contador de alertas do relatório conta só os alertas de verdade.

## Passo 5 — Tela Ao vivo (`live_screen.dart`)

Abra `lib/screens/live_screen.dart`, no método `build`.

**5a.** Apague esta linha:

```
final mov = _mov == null ? null : toBool(_mov!.value);
```

e no lugar dela escreva:

```
final movRecente = _mov != null &&
    DateTime.now().difference(_mov!.time) < const Duration(seconds: 60);
```

**5b.** No bloco do `_Tile` de **Movimento**, troque as linhas `value:` e `color:` por:

```
value: _mov == null
    ? 'Nenhum registro'
    : (movRecente
        ? 'Detectado'
        : 'Ultimo: ${DateFormat('HH:mm').format(_mov!.time)}'),
color: movRecente ? Colors.red : Colors.grey,
```

Resultado: aparece "Detectado" por 60 segundos depois de um movimento. Depois disso mostra "Ultimo: 14:32" (a hora do último movimento).

## Passo 6 — Atualizar o teste (`test/report_test.dart`)

**6a.** No topo do arquivo, junto com os outros `import`, acrescente:

```
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_iot/tago_service.dart';
```

**6b.** Dentro do `main()`, antes da chave final `}`, acrescente este teste novo:

```
  test('fetchAlertas junta as duas variaveis e ignora valor 0', () async {
    final client = MockClient((req) async {
      final v = req.url.queryParameters['variable'];
      final itens = v == 'alerta_temperatura'
          ? [
              {'variable': v, 'value': 1, 'time': '2025-11-10T12:00:00.000Z'},
              {'variable': v, 'value': 0, 'time': '2025-11-10T13:00:00.000Z'},
            ]
          : [
              {'variable': v, 'value': 1, 'time': '2025-11-10T14:00:00.000Z'},
            ];
      return http.Response(jsonEncode({'status': true, 'result': itens}), 200);
    });
    final lista = await TagoService(client).fetchAlertas();
    expect(lista.length, 2);
    expect(lista.first.variable, 'alerta_fora_horario');
  });
```

**6c.** Rode os testes no terminal, dentro de `app-mobile/`:

```
flutter test
```

Tem que aparecer `All tests passed!`. Se aparecer erro de compilação, copie a mensagem **inteira** e mande para o Thiago.

## Passo 7 — Configurar o `env.json`

1. Se ainda não existir, copie `env.example.json` para `env.json`.
2. Abra o `env.json` e preencha:

```
{
  "TAGO_TOKEN": "o-token-que-o-julio-mandou",
  "TAGO_URL": "https://api.tago.io",
  "DASHBOARD_URL": "https://link-publico-do-dashboard"
}
```

3. Se o Júlio confirmar que a conta usa a outra região, troque `TAGO_URL` para `https://api.us-e1.tago.io`.
4. O `DASHBOARD_URL` pode ficar vazio até o Júlio mandar o link. A aba do dashboard só aparece quando ele estiver preenchido.
5. **O `env.json` nunca vai para o git.** Ele já está no `.gitignore`, mas confira antes de cada commit.

## Passo 8 — Testar com dados de mentira (sem o ESP32)

O Thiago deixou um programa que envia dados de teste ao TagoIO, no mesmo formato do dispositivo.

1. Instale o Python 3 (python.org), marcando a opção **Add Python to PATH**.
2. Pegue o simulador no repositório: clone o projeto (Passo 13, item 1) ou abra o link do [simulador_dados.py](https://github.com/Louback1903/pulsobiz-monitor/blob/main/fase2-n2/ferramentas/simulador_dados.py), clique em **Raw** e salve o arquivo. Abra um terminal (PowerShell) na pasta onde está o `simulador_dados.py`.
3. Informe o token (PowerShell):

```
$env:TAGOIO_DEVICE_TOKEN = "o-token-que-o-julio-mandou"
```

4. Se a conta do Júlio for da outra região, informe também:

```
$env:TAGOIO_API_HOST = "https://api.us-e1.tago.io"
```

5. Envie os testes, um de cada vez:

```
python simulador_dados.py
python simulador_dados.py --evento movimento
python simulador_dados.py --evento alerta_temperatura
python simulador_dados.py --evento alerta_fora_horario
python simulador_dados.py --evento alerta_temperatura_fim
python simulador_dados.py --evento rele_ligado
python simulador_dados.py --evento rele_desligado
```

6. Cada comando deve mostrar `HTTP 200`. Se mostrar outro número, veja a tabela de erros no fim deste documento.

**Aviso:** os eventos de alerta podem disparar e-mail e SMS no celular do grupo, se o Júlio já tiver criado os alertas. Avise o Júlio antes de testar.

## Passo 9 — Rodar o app e conferir

Na pasta `app-mobile/`:

```
flutter run --dart-define-from-file=env.json
```

Confira, nesta ordem:

- [ ] Depois do `python simulador_dados.py`, a tela **Ao vivo** mostra temperatura e umidade.
- [ ] Depois do `--evento movimento`, o card de movimento mostra **Detectado**, e depois de 60 s mostra **Ultimo: HH:MM**.
- [ ] Depois do `--evento rele_ligado`, o card do relé mostra **Ligado**, e depois do `--evento rele_desligado` mostra **Desligado**.
- [ ] Depois do `--evento alerta_temperatura`, a tela **Alertas** mostra "Temperatura alta no ambiente".
- [ ] Depois do `--evento alerta_fora_horario`, aparece "Movimento fora do expediente".
- [ ] Depois do `--evento alerta_temperatura_fim`, **não** aparece alerta novo.
- [ ] A tela **Relatório** mostra o número certo de alertas e movimentos.

## Passo 10 — Conferir o cabeçalho do token

O app envia o token no cabeçalho `Authorization`. O contrato do projeto usa `Device-Token`. Provavelmente o TagoIO aceita os dois, mas ninguém testou ainda.

- Se o Passo 9 funcionou, **não mude nada**.
- Se aparecer "Token invalido ou expirado (401)" mesmo com o token certo e o endereço certo, abra `lib/tago_service.dart` e troque:

```
'Authorization': Config.token,
```

por:

```
'Device-Token': Config.token,
```

- Avise o Thiago qual dos dois funcionou.

## Passo 11 — Corrigir o `docs/app.md`

Na documentação, faça estas 3 mudanças:

- Apague o trecho que diz que o dispositivo envia movimento periodicamente (0/1). Ele envia só `movimento = 1` quando detecta.
- Na seção de configuração, cite as duas variáveis de alerta: `alerta_temperatura` e `alerta_fora_horario`.
- Acrescente esta nota: "O horário de pico do app é calculado nas últimas 24 horas. O `pico_hora` enviado pelo dispositivo é acumulado desde que ele foi ligado, então os dois podem ser diferentes."

## Passo 12 — Gerar o APK

```
flutter build apk --release --dart-define-from-file=env.json
```

O arquivo fica em `build/app/outputs/flutter-apk/app-release.apk`. Instale em um celular e confira que abre e mostra os dados.

## Passo 13 — Enviar o app para o repositório

Você já foi adicionado como colaborador. Se ainda não aceitou o convite, aceite pelo e-mail ou em `github.com/Louback1903/pulsobiz-monitor/invitations`. Sem isso o push é recusado.

1. Clone o repositório (GitHub Desktop: Clone repository, ou no terminal). Se já clonou antes, rode `git pull` para pegar as novidades:

```
git clone https://github.com/Louback1903/pulsobiz-monitor.git
```

2. Copie a pasta do seu app para `fase2-n2/app-mobile/` e o `app.md` para `fase2-n2/app-mobile/docs/app.md`.
3. **Antes de commitar, confira:** rode `git status`. O arquivo `env.json` **não pode aparecer** na lista. Se aparecer, pare e avise o Thiago.
4. Envie:

```
git add fase2-n2/app-mobile
git commit -m "App mobile: telas, relatorio e correcoes de alertas"
git push
```

## Se der erro

| O que aparece | O que provavelmente é | O que fazer |
|---|---|---|
| `HTTP 401` ou "Token invalido" | token errado, ou endereço da região errado | confira o token com o Júlio; troque `TAGO_URL`; faça o Passo 10 |
| `HTTP 404` | endereço da API errado | confira `TAGO_URL` |
| App mostra "Token nao configurado" | o app foi aberto sem o `env.json` | rode com `--dart-define-from-file=env.json` |
| Telas vazias, sem erro | ainda não existem dados no TagoIO | rode `python simulador_dados.py` e espere 5 segundos |
| Erro de compilação depois dos passos | trecho colado no lugar errado | mande o erro inteiro para o Thiago |
| `python` não é reconhecido | Python não está no PATH | reinstale marcando "Add Python to PATH" |

## O que entregar ao Thiago

| O quê | Canal | Prazo |
|---|---|---|
| Confirmação de que os Passos 1 a 6 foram feitos e `flutter test` passou | grupo | 02/11 |
| Qual cabeçalho funcionou (`Authorization` ou `Device-Token`) | grupo | 02/11 |
| App no repositório, em `fase2-n2/app-mobile/`, com o `docs/app.md` corrigido | git | 02/11 |
| APK instalável | grupo | 04/11 |
| Prints das telas Ao vivo, Relatório e Alertas com dados | grupo | 04/11 |
| Para os slides: 3 a 5 linhas do que o app faz e 2 prints bons | grupo | 11/11 |

## Regras

- **Token nunca no grupo e nunca no git.** Só em mensagem privada.
- Mudou o nome de uma variável? Avise o grupo no mesmo dia.
- **Travou por mais de 1 dia?** Avise o Thiago, com o print do erro.
- **Tudo tem que ser gratuito.** Se algo pedir plano pago, não pague: avise o Thiago, que leva ao professor.
- O piloto é demonstrado no **Wokwi** (decidido), então não precisa de hardware real.
