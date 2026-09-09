param(
  [string]$Source = (Join-Path $PSScriptRoot 'examples\functions.lume'),
  [int]$Iterations = 100,
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe')
)

$ErrorActionPreference = 'Stop'
$artifact = Join-Path $PSScriptRoot 'dist\benchmark.lbc'
& $Lume build $Source $artifact | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to build benchmark artifact' }

function Measure-Runs([scriptblock]$Action) {
  $watch = [Diagnostics.Stopwatch]::StartNew()
  1..$Iterations | ForEach-Object { & $Action }
  $watch.Stop()
  [Math]::Round($watch.Elapsed.TotalMilliseconds, 3)
}

$checkMs = Measure-Runs { & $Lume check $Source | Out-Null }
$cachedRunMs = Measure-Runs { & $Lume run $Source | Out-Null }
$artifactRunMs = Measure-Runs { & $Lume exec $artifact | Out-Null }

[pscustomobject]@{
  Iterations = $Iterations
  CheckTotalMs = $checkMs
  CheckMeanMs = [Math]::Round($checkMs / $Iterations, 3)
  CachedRunTotalMs = $cachedRunMs
  CachedRunMeanMs = [Math]::Round($cachedRunMs / $Iterations, 3)
  ArtifactRunTotalMs = $artifactRunMs
  ArtifactRunMeanMs = [Math]::Round($artifactRunMs / $Iterations, 3)
  ArtifactBytes = (Get-Item $artifact).Length
}
