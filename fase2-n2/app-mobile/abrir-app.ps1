# Abre o app (versao web do Flutter) no navegador, ja conectado a nuvem.
# Primeira vez (ou depois de mudar o codigo), gere a versao web:
#   $env:Path += ";D:\Pasta do ClaudeCode\tools\flutter\bin"
#   flutter build web --dart-define-from-file=env.json
# Depois, para abrir (esta janela precisa ficar aberta):
#   .\abrir-app.ps1
$pasta = Join-Path $PSScriptRoot "build\web"
if (-not (Test-Path (Join-Path $pasta "index.html"))) { Write-Host "Rode antes: flutter build web --dart-define-from-file=env.json"; exit 1 }
Start-Process "http://127.0.0.1:8090/"
Set-Location $pasta
python -m http.server 8090 --bind 127.0.0.1
