"""Simulador do dispositivo PulsoBiz: envia dados de teste ao TagoIO sem precisar do ESP32.

Serve para a plataforma (dashboard/alertas) e o app serem desenvolvidos em paralelo,
sem esperar o hardware. Usa o MESMO formato do firmware (ver CONTRATO-DE-DADOS.md).

O token vem da variavel de ambiente TAGOIO_DEVICE_TOKEN (nunca escreva no codigo/git).

  PowerShell:  $env:TAGOIO_DEVICE_TOKEN = "seu-token"
  Bash:        export TAGOIO_DEVICE_TOKEN="seu-token"

Uso:
  python simulador_dados.py                         1 rodada de telemetria
  python simulador_dados.py --loop                  telemetria a cada 10 s (Ctrl+C para parar)
  python simulador_dados.py --evento movimento
  python simulador_dados.py --evento alerta_temperatura
  python simulador_dados.py --evento alerta_temperatura_fim
  python simulador_dados.py --evento alerta_fora_horario
"""
import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request

URL = "https://api.tago.io/data"


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
}


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
    parser.add_argument("--evento", choices=sorted(EVENTOS))
    parser.add_argument("--loop", action="store_true")
    args = parser.parse_args()

    token = os.environ.get("TAGOIO_DEVICE_TOKEN", "")
    if not token:
        sys.exit("Defina a variavel de ambiente TAGOIO_DEVICE_TOKEN (veja o topo do arquivo).")

    if args.evento:
        enviar(token, EVENTOS[args.evento]())
    elif args.loop:
        while True:
            enviar(token, telemetria())
            time.sleep(10)
    else:
        enviar(token, telemetria())


if __name__ == "__main__":
    main()
