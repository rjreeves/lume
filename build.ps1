param(
  [string]$Certo = 'C:\Users\robert\Desktop\Certo\target\release\certo.exe'
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null

# Bakes a hash of this file's own (unmodified) source into the built binary,
# so every .lbc it writes carries a real compiler-build identity alongside
# the program's own source hash - see compilerBuildHash()'s own doc comment
# in src/lume.cto for why this exists (a source-only cache key can't tell
# "same program, but a lume.exe upgrade changed compiler behavior" apart
# from a genuine cache hit). certo has no build-time templating of its own,
# so this is done here: substitute the placeholder in a copy, build that.
$sourcePath = Join-Path $root 'src\lume.cto'
$buildHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
$placeholder = 'UNBUILT_' * 8
$templatedPath = Join-Path $dist 'lume.build.cto'
(Get-Content -LiteralPath $sourcePath -Raw) -replace [regex]::Escape($placeholder), $buildHash |
  Set-Content -LiteralPath $templatedPath -NoNewline -Encoding utf8

& $Certo check $templatedPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $Certo $templatedPath -o (Join-Path $dist 'lume.exe')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $dist 'lume.exe') api | Set-Content -LiteralPath (Join-Path $root 'ai\lume-api.json') -Encoding utf8
exit $LASTEXITCODE
