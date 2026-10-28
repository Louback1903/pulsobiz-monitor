# Demonstração do dispositivo no Wokwi

O piloto do N2 é demonstrado no simulador Wokwi. O projeto está em [wokwi.com/projects/479147955272630273](https://wokwi.com/projects/479147955272630273).

## Regra de ouro: o token nunca pode ficar salvo no Wokwi

O projeto do Wokwi é **público** (o plano gratuito não permite projeto privado). Se o Device Token for salvo lá, qualquer pessoa pode ler e usar. Por isso:

- Cole o token só **durante a demonstração** e **não clique em SAVE**.
- Ao terminar, feche a aba sem salvar (se o Wokwi perguntar se quer descartar as mudanças, descarte).
- Depois da apresentação (18/11), peça ao Júlio para **trocar o token** no TagoIO.

## Antes da apresentação (faça um ensaio)

1. Abra o projeto do Wokwi, logado na conta do Thiago.
2. Confira que o código é o mesmo de `fase2-n2/dispositivo-iot/sketch.ino` (o do repositório).
3. No começo do `sketch.ino` (perto da linha 60 a 90) existem linhas `#define` com valores padrão. **Troque o valor** das linhas abaixo, direto no editor do Wokwi (sem salvar). Primeiro, o token:

```
#define TAGOIO_DEVICE_TOKEN "cole-aqui-o-token"
```

4. Se a conta do Júlio precisar do endereço da região, troque também o valor desta linha:

```
#define TAGOIO_API_HOST "https://api.us-e1.tago.io"
```

5. Para a demonstração, troque o valor destas duas linhas (opcional):

```
#define INTERVALO_TELEMETRIA_MS 10000UL
#define HORA_FECHAMENTO 12
```

   - A primeira envia a telemetria a cada 10 segundos (o padrão é 60).
   - A segunda muda o expediente para 8h às 12h. Se a apresentação for depois das 12h, o movimento já conta como "fora do horário" e dispara o alerta.
   - Ajuste `HORA_ABERTURA` e `HORA_FECHAMENTO` conforme a hora da apresentação.

6. Clique em Play (▶). A fila de compilação gratuita pode demorar alguns minutos: **dê o Play 10 minutos antes** da apresentação.
7. No Serial do Wokwi tem que aparecer `[NUVEM] HTTP 200`. Se aparecer `HTTP 401`, o token ou o endereço estão errados.

## Roteiro da demonstração

1. Mostre o circuito: ESP32, DHT22, PIR, relé e display OLED.
2. **Temperatura:** clique no DHT22 e mova o controle de temperatura.
   - Acima de 28 C o relé liga (ventilador). Abaixo de 27 C desliga.
   - Acima de 32 C dispara o **alerta de temperatura** (e-mail e SMS). Abaixo de 31 C o alerta normaliza e **não** manda nada.
3. **Movimento:** clique no sensor PIR e em "Simulate motion". O display mostra o movimento e o horário de pico.
4. **Plataforma:** abra o dashboard do TagoIO e mostre os valores chegando.
5. **App:** abra o app do Rafael e mostre os mesmos valores.
6. **Alertas:** mostre o e-mail e o SMS recebidos.

## Se algo der errado na hora

- **Compilação demorando:** mostre o vídeo de reserva da demonstração (gravar no ensaio, de 12/11 a 17/11).
- **`HTTP 401` ou `HTTP 404`:** confira o token e o endereço da API (`TAGOIO_API_HOST`).
- **Sem Wi-Fi no simulador:** o Wokwi usa a rede virtual `Wokwi-GUEST`; reinicie a simulação.
- **Sem token:** o firmware roda normalmente e mostra o painel local, só não envia para a nuvem.
