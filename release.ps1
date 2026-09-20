param(
  [string]$Certo = 'C:\Users\robert\Desktop\Certo\target\release\certo.exe'
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'

# The archive half of ROADMAP.md's "release archives and installers for
# major desktop platforms" - Windows-only, matching every other build/
# distribution item in this project (this dev environment has no
# cross-platform build infrastructure). Installers (MSI, code signing,
# macOS/Linux packages) remain a separate, unstarted item.
#
# Reuses the exact same reproducible build every other workflow here
# already uses - no separate release-only build path - so the archive
# always reflects the real, already-verified build.ps1 output, byte for
# byte (see rjreeves/Certo#2's -Brepro fix).
& (Join-Path $root 'build.ps1') -Certo $Certo
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# The version string's single existing source of truth: src/lume.cto's
# own `println("lume X.Y.Z")` line in the `help` command (the same
# string the `api` command's JSON manifest also embeds) - read directly
# rather than tracking a second, divergence-prone copy.
$sourceText = Get-Content -LiteralPath (Join-Path $root 'src\lume.cto') -Raw
$versionMatch = [regex]::Match($sourceText, 'println\("lume ([^"]+)"\)')
if (-not $versionMatch.Success) { throw 'could not find the lume version string in src/lume.cto' }
$version = $versionMatch.Groups[1].Value

$archiveName = "lume-$version-windows-x64"
$stageDir = Join-Path $dist $archiveName
if (Test-Path -LiteralPath $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force }
New-Item -ItemType Directory -Path $stageDir | Out-Null

# A self-contained "download and go" bundle: the binary, the practical
# guide, the full spec, and the machine-readable API reference
# build.ps1 itself just (re)generated as part of the build above.
Copy-Item -LiteralPath (Join-Path $dist 'lume.exe') -Destination $stageDir
Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination $stageDir
Copy-Item -LiteralPath (Join-Path $root 'SPEC.md') -Destination $stageDir
New-Item -ItemType Directory -Path (Join-Path $stageDir 'docs') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'docs\using-lume-the-fast-one.md') -Destination (Join-Path $stageDir 'docs')
Copy-Item -LiteralPath (Join-Path $root 'docs\builtins.md') -Destination (Join-Path $stageDir 'docs')
New-Item -ItemType Directory -Path (Join-Path $stageDir 'ai') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'ai\lume-api.json') -Destination (Join-Path $stageDir 'ai')

$zipPath = Join-Path $dist "$archiveName.zip"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $stageDir '*') -DestinationPath $zipPath

# The same Get-FileHash pattern build.ps1 already uses for its own
# build-hash step - a downloader's way to verify the archive, not a new
# hashing convention.
$checksumPath = "$zipPath.sha256"
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
"$hash  $(Split-Path -Leaf $zipPath)" | Set-Content -LiteralPath $checksumPath -NoNewline -Encoding utf8

# Verify the archive is actually runnable standalone, not just present -
# extract it to a scratch directory the way a real downloader would,
# and confirm the extracted binary works on its own with no other file
# from this repo on disk nearby.
$verifyDir = Join-Path $dist "$archiveName-verify"
if (Test-Path -LiteralPath $verifyDir) { Remove-Item -LiteralPath $verifyDir -Recurse -Force }
Expand-Archive -LiteralPath $zipPath -DestinationPath $verifyDir

$extractedExe = Join-Path $verifyDir 'lume.exe'
if (-not (Test-Path -LiteralPath $extractedExe)) { throw 'extracted archive is missing lume.exe' }

& $extractedExe --help | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'extracted lume.exe --help failed' }

$smokeFile = Join-Path $verifyDir 'smoke.lume'
@'
fn main(args: [str]) -> int {
  print("release archive smoke test ok")
  return 0
}
'@ | Set-Content -LiteralPath $smokeFile -NoNewline -Encoding utf8
& $extractedExe check $smokeFile | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'extracted lume.exe check failed on a real .lume file' }

Remove-Item -LiteralPath $verifyDir -Recurse -Force
Remove-Item -LiteralPath $stageDir -Recurse -Force

[pscustomobject]@{
  Version      = $version
  ArchivePath  = $zipPath
  ChecksumPath = $checksumPath
  Sha256       = $hash
}
