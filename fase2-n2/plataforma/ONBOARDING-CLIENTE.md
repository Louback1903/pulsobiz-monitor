# Como entregar a PulsoBiz a um novo cliente

Cada cliente é uma **loja**: tem o seu dispositivo (token próprio), o seu login (e-mail e senha) e só enxerga os próprios dados.
A PulsoBiz cria o acesso; o cliente não se cadastra sozinho.

## 1. Criar o cliente (equipe PulsoBiz)

Pré-requisito (uma vez): segredo `ADMIN_TOKEN` cadastrado em **Supabase > Edge Functions > Secrets**, com o mesmo valor do arquivo local `fase2-n2/ferramentas/admin.local.txt` (esse arquivo nunca vai para o git).

No PowerShell, na pasta `fase2-n2/ferramentas`:

```powershell
.\criar-cliente.ps1 -Nome "Padaria Sol" -Email "dono@padariasol.com" -Senha "SenhaForte123"
```

Opcional: `-AlertEmails "a@x.com,b@x.com"` (quem recebe os alertas por e-mail; padrão: o e-mail do login) e `-AlertSms "+5581999999999"`.

O comando mostra o `device_token` da loja. Guarde-o: ele vai no dispositivo do cliente e **não deve ser divulgado**.

Outras ações:

```powershell
.\criar-cliente.ps1 -Acao redefinir_senha -Email "dono@padariasol.com" -Senha "NovaSenha456"
.\criar-cliente.ps1 -Acao listar
```

## 2. Configurar o dispositivo do cliente

No `secrets.h` do firmware (ESP32 do cliente):

```c
#define WIFI_SSID "rede-do-cliente"
#define WIFI_PASSWORD "senha-da-rede"
#define TAGOIO_API_HOST "https://mhkaowtdlwbtrnqbftcr.supabase.co/functions/v1"
#define TAGOIO_DEVICE_TOKEN "<device_token da loja>"
```

## 3. Entregar o acesso ao cliente

- **App Android:** instalar o APK `PulsoBiz.apk` (ou publicar na loja de aplicativos).
- **Dashboard web:** https://frolicking-crumble-35774d.netlify.app
- Passar ao cliente o **e-mail e a senha** do login. Ele pode trocar a senha no app (aba Conta).

## 4. O que o cliente recebe

- Painel ao vivo (temperatura, umidade, movimento, ventilador, lotação e temperatura ideal), relatório de 24 h e histórico de alertas.
- Alertas por e-mail (e SMS, se configurado) com o nome da loja.

## Segurança (resumo)

- O login do cliente só abre a loja dele: o servidor filtra todos os dados pela loja ligada ao login.
- O app guarda só o login do cliente; o token do dispositivo fica só no ESP32.
- Ninguém consegue criar conta sozinho (desligar "Allow new users to sign up" em Authentication > Sign In / Providers > Email) e só quem tem o `ADMIN_TOKEN` cria clientes.
- Para trocar o token de uma loja (se vazar), é preciso gerar outro no banco e atualizar o dispositivo.
