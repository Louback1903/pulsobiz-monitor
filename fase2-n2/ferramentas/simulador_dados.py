"""Simulador do dispositivo PulsoBiz: envia dados de teste ao TagoIO sem precisar do ESP32.

Serve para a plataforma (dashboard/alertas) e o app serem desenvolvidos em paralelo,
sem esperar o hardware. Usa o MESMO formato do firmware (ver CONTRATO-DE-DADOS.md).

O token vem da variavel de ambiente TAGOIO_DEVICE_TOKEN (nunca escreva no codigo/git).

  PowerShell:  $env:TAGOIO_DEVICE_TOKEN = "seu-token"
  Bash:        export TAGOIO_DEVICE_TOKEN="seu-token"

Endereco da API (opcional). Padrao: https://api.tago.io. Se a sua conta do TagoIO
estiver em outra regiao, defina TAGOIO_API_HOST da mesma forma, por exemplo:

  PowerShell:  $env:TAGOIO_API_HOST = "https://api.us-e1.tago.io"
  Bash:        export TAGOIO_API_HOST="https://api.us-e1.tago.io"

Uso:
  python simulador_dados.py                         1 rodada de telemetria
  python simulador_dados.py --loop                  telemetria a cada 10 s (Ctrl+C para parar)
  python simulador_dados.py --evento movimento
  python simulador_dados.py --evento alerta_temperatura
  python simulador_dados.py --evento alerta_temperatura_fim
  python simulador_dados.py --evento alerta_fora_horario
  python simulador_dados.py --evento pico_hora
  python simulador_dados.py --evento rele_ligado
  python simulador_dados.py --evento rele_desligado
"""
import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request

URL = os.environ.get("TAGOIO_API_HOST", "https://api.tago.io").rstrip("/") + "/data"


def var(nome, valor, unidade=None):
    item = {"variable": nome, "value": valor}
    if unidade:
        item["unit"] = unidade
    return item


def telemetria():
    return [
        var("temperatura", round(random.uniform(24.0, 30.0), 1), "C"),
        var("umidade", round(random.uniform(45.0, 70.0), 1), "%"),
        var("movimentos_hora", random.randint(0, 12)),
        var("wifi_rssi", random.randint(-75, -45), "dBm"),
    ]


EVENTOS = {
    "movimento": lambda: [var("movimento", 1), var("movimentos_hora", random.randint(1, 12))],
    "alerta_temperatura": lambda: [var("temperatura", 33.5, "C"), var("alerta_temperatura", 1)],
    "alerta_temperatura_fim": lambda: [var("temperatura", 29.0, "C"), var("alerta_temperatura", 0)],
    "alerta_fora_horario": lambda: [var("movimento", 1), var("alerta_fora_horario", 1)],
    "pico_hora": lambda: [var("pico_hora", random.randint(8, 18), "h")],
    "rele_ligado": lambda: [var("rele", 1)],
    "rele_desligado": lambda: [var("rele", 0)],
    # Lotacao: entrada soma 1, saida subtrai 1 (a plataforma calcula a temperatura ideal).
    "entrada": lambda: [var("entrada", 1), var("movimento", 1)],
    "saida": lambda: [var("saida", 1)],
    "zerar_lotacao": lambda: [var("lotacao_reset", 1)],
}


def estabilizar(token):
    """Simula o ambiente chegando na temperatura ideal: 3 leituras iguais a meta."""
    req = urllib.request.Request(URL + "?view=dashboard")
    with urllib.request.urlopen(req, timeout=10) as resp:
        meta = json.loads(resp.read().decode("utf-8")).get("meta") or {}
    alvo = meta.get("ideal")
    if alvo is None:
        sys.exit("A plataforma ainda nao informou a temperatura ideal.")
    print(f"Temperatura ideal atual: {alvo} C (lotacao {meta.get('lotacao')})")
    for _ in range(3):
        enviar(token, [var("temperatura", alvo, "C")])
        time.sleep(1)


def enviar(token, payload):
    req = urllib.request.Request(
        URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Device-Token": token},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            print(f"HTTP {resp.status} <- {json.dumps(payload)}")
            print(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')}")
    except urllib.error.URLError as e:
        print(f"Falha de rede: {e.reason}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--evento", choices=sorted(EVENTOS) + ["estabilizar"])
    parser.add_argument("--loop", action="store_true")
    args = parser.parse_args()

    token = os.environ.get("TAGOIO_DEVICE_TOKEN", "")
    if not token:
        sys.exit("Defina a variavel de ambiente TAGOIO_DEVICE_TOKEN (veja o topo do arquivo).")

    if args.evento == "estabilizar":
        estabilizar(token)
    elif args.evento:
        enviar(token, EVENTOS[args.evento]())
    elif args.loop:
        while True:
            enviar(token, telemetria())
            time.sleep(10)
    else:
        enviar(token, telemetria())


if __name__ == "__main__":
    main()
