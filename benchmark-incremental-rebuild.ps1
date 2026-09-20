param(
  # Same fresh-process rationale as every other large-program script in
  # this file since the OOM fix (see benchmark-10000-features.ps1's own
  # header comment) - a `lume run` on a 100,000-line program is squarely
  # a "large-program benchmark" by this file's existing definition.
  [int]$Iterations = 30,
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe')
)

$ErrorActionPreference = 'Stop'

# Reading compileOrCache/loadModule directly (src/lume.cto) first, rather
# than assuming what "incremental" means here, found the real answer:
# there is no incremental compilation in this compiler at any
# granularity, function or file. loadModule concatenates every
# use-imported file's source into one combined string; `run`'s own
# compileOrCache hashes that *entire combined blob* as its one cache key
# - changing one character anywhere invalidates the whole cached
# artifact. `check` doesn't even go through compileOrCache at all, so
# this is the one benchmark script here that measures `lume run`
# instead - caching is a run-only code path.
#
# "One line changed" can't be sampled by repeating the same edit - the
# very next run after an edit is itself a fresh warm cache for the *new*
# content. Each sample alternates the target's last line between two
# variants (`total = total + 1` / `total = total + 2`) before timing, so
# every sample is a genuine, freshly-invalidated rebuild.

# Unlike every other script here (which times `lume check`, where exit
# code 0 means success), this one times `lume run` - and `lume run`'s
# own exit code *is* the executed program's return value (confirmed
# live: this generator's program legitimately exits ~99996, not 0).
# Correctness is validated once per variant in Measure-Program instead
# of on every timed sample, matching the fixed-content cold/warm phases'
# own "validate once before timing" convention every script here uses.
function Measure-Samples([scriptblock]$Action, [int]$Count) {
  1..$Count | ForEach-Object {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    & $Action | Out-Null
    $watch.Stop()
    $watch.Elapsed.TotalMilliseconds
  }
}

function Get-Stats([double[]]$Samples) {
  $sorted = @($Samples | Sort-Object)
  $count = $Samples.Count
  $mean = ($Samples | Measure-Object -Average).Average
  $median = $sorted[[Math]::Floor(($count - 1) / 2)]
  $p95Index = [Math]::Min($count - 1, [Math]::Ceiling(0.95 * $count) - 1)
  $p95 = $sorted[$p95Index]
  $variance = (($Samples | ForEach-Object { [Math]::Pow($_ - $mean, 2) } | Measure-Object -Sum).Sum) / $count
  [pscustomobject]@{
    MeanMs = [Math]::Round($mean, 3)
    MedianMs = [Math]::Round($median, 3)
    P95Ms = [Math]::Round($p95, 3)
    StdDevMs = [Math]::Round([Math]::Sqrt($variance), 3)
  }
}

function Measure-Program([string]$Label, [string]$RootPath, [scriptblock]$WriteVariant, [int]$ExpectedVariant1, [int]$ExpectedVariant2) {
  $cachePath = "$RootPath.lbc"

  # Validate both variants actually produce their own distinct, correct
  # result before timing anything - confirms the edit is real and gets
  # picked up (not silently cached away), not just that `run` exits.
  $WriteVariant.Invoke(1) | Out-Null
  & $Lume run $RootPath | Out-Null
  if ($LASTEXITCODE -ne $ExpectedVariant1) { throw "$Label variant 1 expected exit $ExpectedVariant1, got $LASTEXITCODE" }
  $WriteVariant.Invoke(2) | Out-Null
  & $Lume run $RootPath | Out-Null
  if ($LASTEXITCODE -ne $ExpectedVariant2) { throw "$Label variant 2 expected exit $ExpectedVariant2, got $LASTEXITCODE" }
  $WriteVariant.Invoke(1) | Out-Null

  # Cold: no .lbc, must compile from scratch and write a fresh one. Each
  # sample deletes the cache first - a real repeated "first build".
  $coldSamples = @(Measure-Samples {
    if (Test-Path $cachePath) { Remove-Item -LiteralPath $cachePath -Force }
    & $Lume run $RootPath
  } $Iterations)

  # Warm: cache now exists and matches the current (variant 1) source -
  # left untouched across every sample, a real repeated cache hit.
  & $Lume run $RootPath | Out-Null
  $warmSamples = @(Measure-Samples { & $Lume run $RootPath } $Iterations)

  # One line changed: alternate the variant before every timed sample.
  # The write itself happens *outside* the timed interval, same as
  # cold/warm only ever time the `lume run` call - regenerating a
  # 100,000-line Text file in PowerShell is a real cost, but it's a
  # PowerShell cost, not a compiler one, and folding it into the timed
  # interval would measure the wrong thing entirely (confirmed live:
  # an earlier draft that timed the write too showed the single-file
  # "changed" case as slower than "cold", which never made sense once
  # traced back to the write itself dominating the measurement).
  $current = 1
  $changedSamples = @(1..$Iterations | ForEach-Object {
    $current = if ($current -eq 1) { 2 } else { 1 }
    $WriteVariant.Invoke($current) | Out-Null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    & $Lume run $RootPath | Out-Null
    $watch.Stop()
    $watch.Elapsed.TotalMilliseconds
  })

  $coldStats = Get-Stats $coldSamples
  $warmStats = Get-Stats $warmSamples
  $changedStats = Get-Stats $changedSamples

  [pscustomobject]@{
    Label = $Label
    Cold = $coldStats
    Warm = $warmStats
    Changed = $changedStats
  }
}

# --- Single-file 100,000-line program (same shape as benchmark-100000.ps1) ---
$singleLineCount = 100000
$singlePath = Join-Path $PSScriptRoot 'dist\benchmark-incremental-single.lume'
$writeSingle = {
  param([int]$LastValue)
  $lines = [Collections.Generic.List[string]]::new($singleLineCount)
  $lines.Add('fn main(args: [str]) -> int {')
  $lines.Add('  var total = 0')
  for ($index = 0; $index -lt ($singleLineCount - 5); $index++) { $lines.Add('  total = total + 1') }
  $lines.Add("  total = total + $LastValue")
  $lines.Add('  return total')
  $lines.Add('}')
  if ($lines.Count -ne $singleLineCount) { throw "single-file generator produced $($lines.Count) lines" }
  [IO.File]::WriteAllLines($singlePath, $lines, [Text.UTF8Encoding]::new($false))
}
$singleExpected1 = ($singleLineCount - 5) + 1
$singleExpected2 = ($singleLineCount - 5) + 2
$singleResult = Measure-Program 'Single file (100,000 lines)' $singlePath $writeSingle $singleExpected1 $singleExpected2

# --- Multi-module: ten 10,000-line chunks, only chunk1 ever changes -
# the actual "one function" in "one-function incremental rebuild". ---
$chunkCount = 10
$chunkBodyLines = 9995
$chunkTotalLines = $chunkBodyLines + 5  # fn header, var total, variant line, return, closing brace
$moduleDir = Join-Path $PSScriptRoot 'dist\benchmark-incremental-multi'
New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

function Write-Chunk([int]$Chunk, [int]$LastValue) {
  $chunkPath = Join-Path $moduleDir "chunk$Chunk.lume"
  $lines = [Collections.Generic.List[string]]::new($chunkTotalLines)
  $lines.Add("pub fn chunk$Chunk.run() -> int {")
  $lines.Add('  var total = 0')
  for ($index = 0; $index -lt $chunkBodyLines; $index++) { $lines.Add('  total = total + 1') }
  $lines.Add("  total = total + $LastValue")
  $lines.Add('  return total')
  $lines.Add('}')
  if ($lines.Count -ne $chunkTotalLines) { throw "chunk$Chunk generator produced $($lines.Count) lines" }
  [IO.File]::WriteAllLines($chunkPath, $lines, [Text.UTF8Encoding]::new($false))
}

# Chunks 2-10 never change for the lifetime of this script - only
# chunk1 is rewritten per sample, mirroring "you edited one function".
for ($chunk = 2; $chunk -le $chunkCount; $chunk++) { Write-Chunk $chunk 1 }

$rootPath = Join-Path $moduleDir 'main.lume'
$rootLines = [Collections.Generic.List[string]]::new()
for ($chunk = 1; $chunk -le $chunkCount; $chunk++) { $rootLines.Add("use chunk$chunk") }
$rootLines.Add('')
$rootLines.Add('fn main(args: [str]) -> int {')
$rootLines.Add('  var total = 0')
for ($chunk = 1; $chunk -le $chunkCount; $chunk++) { $rootLines.Add("  total = total + chunk$chunk.run()") }
$rootLines.Add('  return total')
$rootLines.Add('}')
[IO.File]::WriteAllLines($rootPath, $rootLines, [Text.UTF8Encoding]::new($false))

$writeMulti = {
  param([int]$LastValue)
  Write-Chunk 1 $LastValue
}
$otherChunksTotal = ($chunkBodyLines + 1) * ($chunkCount - 1)
$multiExpected1 = $otherChunksTotal + ($chunkBodyLines + 1)
$multiExpected2 = $otherChunksTotal + ($chunkBodyLines + 2)
$multiResult = Measure-Program 'Multi-module (10 files, only chunk1 changes)' $rootPath $writeMulti $multiExpected1 $multiExpected2

[pscustomobject]@{
  Program = $singleResult.Label
  ColdMeanMs = $singleResult.Cold.MeanMs; ColdMedianMs = $singleResult.Cold.MedianMs; ColdP95Ms = $singleResult.Cold.P95Ms; ColdStdDevMs = $singleResult.Cold.StdDevMs
  WarmMeanMs = $singleResult.Warm.MeanMs; WarmMedianMs = $singleResult.Warm.MedianMs; WarmP95Ms = $singleResult.Warm.P95Ms; WarmStdDevMs = $singleResult.Warm.StdDevMs
  ChangedMeanMs = $singleResult.Changed.MeanMs; ChangedMedianMs = $singleResult.Changed.MedianMs; ChangedP95Ms = $singleResult.Changed.P95Ms; ChangedStdDevMs = $singleResult.Changed.StdDevMs
} | Format-List

[pscustomobject]@{
  Program = $multiResult.Label
  ColdMeanMs = $multiResult.Cold.MeanMs; ColdMedianMs = $multiResult.Cold.MedianMs; ColdP95Ms = $multiResult.Cold.P95Ms; ColdStdDevMs = $multiResult.Cold.StdDevMs
  WarmMeanMs = $multiResult.Warm.MeanMs; WarmMedianMs = $multiResult.Warm.MedianMs; WarmP95Ms = $multiResult.Warm.P95Ms; WarmStdDevMs = $multiResult.Warm.StdDevMs
  ChangedMeanMs = $multiResult.Changed.MeanMs; ChangedMedianMs = $multiResult.Changed.MedianMs; ChangedP95Ms = $multiResult.Changed.P95Ms; ChangedStdDevMs = $multiResult.Changed.StdDevMs
} | Format-List

# `lume run`'s own exit code is the executed program's return value, not
# a success signal - without this, the script's own final exit code
# would misleadingly echo that value (e.g. 99996) as if it were a
# failure, confirmed live before adding this line.
exit 0
