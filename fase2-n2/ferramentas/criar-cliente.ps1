# Ferramenta da PulsoBiz: cria um cliente (loja + login) e mostra o token do dispositivo dele.
# Precisa do segredo de administrador em admin.local.txt (nao vai para o git) e do mesmo valor
# cadastrado em Supabase > Edge Functions > Secrets com o nome ADMIN_TOKEN.
#
# Uso (PowerShell, nesta pasta):
#   .\criar-cliente.ps1 -Nome "Padaria Sol" -Email "dono@padariasol.com" -Senha "SenhaForte123"
#   .\criar-cliente.ps1 -Acao redefinir_senha -Email "dono@padariasol.com" -Senha "NovaSenha456"
#   .\criar-cliente.ps1 -Acao listar
param(
  [ValidateSet("criar_cliente", "redefinir_senha", "listar")][string]$Acao = "criar_cliente",
  [string]$Nome = "", [string]$Email = "", [string]$Senha = "",
  [string]$AlertEmails = "", [string]$AlertSms = ""
)
$host_api = "https://mhkaowtdlwbtrnqbftcr.supabase.co/functions/v1/data"
$arquivo = Join-Path $PSScriptRoot "admin.local.txt"
if (-not (Test-Path $arquivo)) { Write-Host "Falta o arquivo admin.local.txt"; exit 1 }
$segredo = (Get-Content $arquivo -Raw).Trim()
$corpo = @{ nome = $Nome; email = $Email; senha = $Senha; alert_emails = $AlertEmails; alert_sms = $AlertSms } | ConvertTo-Json
try {
  $r = Invoke-RestMethod -Method Post -Uri "$host_api`?admin=$Acao" -Headers @{ "X-Admin-Token" = $segredo } `
        -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($corpo))
  $r | ConvertTo-Json -Depth 5
  if ($Acao -eq "criar_cliente") { Write-Host "`nPasse ao cliente: e-mail e senha do login. O device_token acima vai no dispositivo dele (secrets.h) e NAO deve ser divulgado." }
} catch { Write-Host "Erro:" $_.ErrorDetails.Message }
