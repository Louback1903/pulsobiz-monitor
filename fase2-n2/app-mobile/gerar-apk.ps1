# Gera o APK do app PulsoBiz (Android) usando o Android Studio ja instalado.
#
# O build precisa de memoria: este computador tem ~6 GB. ANTES de rodar, feche o Chrome, o Canva,
# o WhatsApp e outros programas pesados (ou reinicie o computador). O script tambem encerra
# processos "daemon" do Gradle/Kotlin que sobraram de builds anteriores.
#
# Uso (PowerShell):
#   cd "D:\Pasta do ClaudeCode\PulsoBiz\fase2-n2\app-mobile"
#   .\gerar-apk.ps1
# O arquivo sai em build\app\outputs\flutter-apk\app-release.apk (copiado tambem para PulsoBiz.apk nesta pasta).

$ErrorActionPreference = "Stop"
$androidStudioJbr = "D:\Android Studio New\jbr"
if (-not (Test-Path $androidStudioJbr)) { $androidStudioJbr = "C:\Program Files\Android\Android Studio\jbr" }
$env:JAVA_HOME = $androidStudioJbr
$env:ANDROID_HOME = "D:\Android\Sdk"
$env:ANDROID_SDK_ROOT = "D:\Android\Sdk"
$env:Path += ";D:\Pasta do ClaudeCode\tools\flutter\bin"

Write-Host "1/4 Encerrando daemons antigos do Gradle/Kotlin..."
& "$PSScriptRoot\android\gradlew.bat" --stop 2>$null | Out-Null
Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
  Where-Object { $_.CommandLine -match "kotlin-build-tools|KotlinCompileDaemon|GradleDaemon" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$o = Get-CimInstance Win32_OperatingSystem
Write-Host ("2/4 Memoria virtual livre: {0:N1} GB (ideal: mais de 4 GB)" -f ($o.FreeVirtualMemory / 1MB))
if ($o.FreeVirtualMemory / 1MB -lt 3) { Write-Host "   Pouca memoria livre. Feche o Chrome, o Canva e outros programas e rode de novo." }

Set-Location $PSScriptRoot
Write-Host "3/4 Gerando o APK (a primeira vez pode levar varios minutos)..."
flutter pub get
flutter build apk --release
if ($LASTEXITCODE -ne 0) { Write-Host "O build falhou. Se a mensagem fala de memoria, feche programas e tente de novo."; exit 1 }

$apk = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-release.apk"
Copy-Item $apk (Join-Path $PSScriptRoot "PulsoBiz.apk") -Force
Write-Host "4/4 Pronto: $PSScriptRoot\PulsoBiz.apk"
Write-Host "Para instalar: copie o PulsoBiz.apk para o celular e abra (permita instalar de fontes desconhecidas) ou use: adb install -r PulsoBiz.apk"
