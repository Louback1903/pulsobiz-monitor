# Demonstracao sem Wokwi: envia dados de teste para a plataforma, no mesmo formato do dispositivo.
# Le o token e o endereco do arquivo ../dispositivo-iot/secrets.h (que nao vai para o git).
#
# Uso (PowerShell, dentro da pasta ferramentas):
#   .\demo.ps1                       telemetria a cada 10 s (Ctrl+C para parar)
#   .\demo.ps1 movimento             1 movimento
#   .\demo.ps1 alerta_temperatura    alerta de temperatura (dispara e-mail e SMS)
#   .\demo.ps1 alerta_fora_horario   alerta de movimento fora do expediente (e-mail e SMS)
#   .\demo.ps1 alerta_temperatura_fim  temperatura normalizada
#   .\demo.ps1 entrada               alguem entrou: lotacao +1 (e-mail, nova temperatura ideal)
#   .\demo.ps1 saida                 alguem saiu: lotacao -1 (e-mail, nova temperatura ideal)
#   .\demo.ps1 estabilizar           temperatura chega na meta: e-mail de "estabilizada"
#   .\demo.ps1 zerar_lotacao         zera a lotacao
param([string]$Evento = "")

$segredos = Get-Content (Join-Path $PSScriptRoot "..\dispositivo-iot\secrets.h") -Raw
$env:TAGOIO_DEVICE_TOKEN = [regex]::Match($segredos, 'TAGOIO_DEVICE_TOKEN\s+"([^"]+)"').Groups[1].Value
$env:TAGOIO_API_HOST = [regex]::Match($segredos, 'TAGOIO_API_HOST\s+"([^"]+)"').Groups[1].Value
if (-not $env:TAGOIO_DEVICE_TOKEN -or -not $env:TAGOIO_API_HOST) { Write-Host "secrets.h sem token ou endereco"; exit 1 }

$py = Join-Path $PSScriptRoot "simulador_dados.py"
if ($Evento -eq "") { python $py --loop } else { python $py --evento $Evento }
