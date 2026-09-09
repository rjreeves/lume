param(
  [string]$Certo = 'C:\Users\robert\Desktop\Certo\target\release\certo.exe'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null

& $Certo check (Join-Path $root 'src\lume.cto')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $Certo (Join-Path $root 'src\lume.cto') -o (Join-Path $dist 'lume.exe')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $dist 'lume.exe') api | Set-Content -LiteralPath (Join-Path $root 'ai\lume-api.json') -Encoding utf8
exit $LASTEXITCODE
