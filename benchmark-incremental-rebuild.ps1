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
# content. Each sample swaps the target file between two pre-generated
# variants before timing, so every sample is a genuine, freshly-
# invalidated rebuild. Both variants are generated once, up front, and
# swapped into place via a plain file copy per sample - not regenerated
# via a PowerShell string-building loop each time. An earlier draft
# regenerated the full 100,000-line content on every sample and left a
# real, confirmed artifact: building a 100,000-element List<string> and
# writing it costs ~1000ms of PowerShell-side CPU/GC work (measured in
# isolation), a full order of magnitude more than the ~100ms the same
# pattern costs for a single 10,000-line chunk - even though that cost
# was already excluded from the timed interval, the sheer amount of
# preceding CPU/GC/IO work measurably disturbed the immediately-
# following timed `lume run` launch (confirmed by isolating the two
# effects separately: raw file overwrite-vs-create costs under 1ms,
# reading a just-written file over a settled one costs a few ms, neither
# comes close to explaining the ~190ms gap that pattern produced - only
# swapping to a plain file copy, which does no PowerShell-side
# generation at all, isolates the actual compileOrCache cost cleanly).
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

# `SwapVariant` takes an Int (1 or 2) and makes the target file exactly
# that pre-generated variant's content, however it likes - a plain file
# copy for the cases below, not a content regeneration.
function Measure-Program([string]$Label, [string]$RootPath, [scriptblock]$SwapVariant, [int]$ExpectedVariant1, [int]$ExpectedVariant2) {
  $cachePath = "$RootPath.lbc"

  # Validate both variants actually produce their own distinct, correct
  # result before timing anything - confirms the edit is real and gets
  # picked up (not silently cached away), not just that `run` exits.
  $SwapVariant.Invoke(1) | Out-Null
  & $Lume run $RootPath | Out-Null
  if ($LASTEXITCODE -ne $ExpectedVariant1) { throw "$Label variant 1 expected exit $ExpectedVariant1, got $LASTEXITCODE" }
  $SwapVariant.Invoke(2) | Out-Null
  & $Lume run $RootPath | Out-Null
  if ($LASTEXITCODE -ne $ExpectedVariant2) { throw "$Label variant 2 expected exit $ExpectedVariant2, got $LASTEXITCODE" }
  $SwapVariant.Invoke(1) | Out-Null

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

  # One line changed: swap to the other pre-generated variant before
  # every timed sample. The swap itself happens *outside* the timed
  # interval, same as cold/warm only ever time the `lume run` call.
  $current = 1
  $changedSamples = @(1..$Iterations | ForEach-Object {
    $current = if ($current -eq 1) { 2 } else { 1 }
    $SwapVariant.Invoke($current) | Out-Null
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

function Write-GeneratedLines([Collections.Generic.List[string]]$Lines, [int]$LastValue, [string]$TargetPath) {
  $Lines.Add("  total = total + $LastValue")
  $Lines.Add('  return total')
  $Lines.Add('}')
  [IO.File]::WriteAllLines($TargetPath, $Lines, [Text.UTF8Encoding]::new($false))
}

# --- Single-file 100,000-line program (same shape as benchmark-100000.ps1) ---
# Both variants generated once, up front - the "changed" phase below only
# ever copies one of these two already-built files into place.
$singleLineCount = 100000
$singlePath = Join-Path $PSScriptRoot 'dist\benchmark-incremental-single.lume'
$singleVariant1Path = Join-Path $PSScriptRoot 'dist\benchmark-incremental-single-v1.lume'
$singleVariant2Path = Join-Path $PSScriptRoot 'dist\benchmark-incremental-single-v2.lume'

function New-SingleFileVariant([int]$LastValue, [string]$TargetPath) {
  $lines = [Collections.Generic.List[string]]::new($singleLineCount)
  $lines.Add('fn main(args: [str]) -> int {')
  $lines.Add('  var total = 0')
  for ($index = 0; $index -lt ($singleLineCount - 5); $index++) { $lines.Add('  total = total + 1') }
  Write-GeneratedLines $lines $LastValue $TargetPath
  if ((Get-Content -LiteralPath $TargetPath).Count -ne $singleLineCount) { throw "single-file generator produced the wrong line count for variant $LastValue" }
}
New-SingleFileVariant 1 $singleVariant1Path
New-SingleFileVariant 2 $singleVariant2Path

$swapSingle = {
  param([int]$Variant)
  $source = if ($Variant -eq 1) { $singleVariant1Path } else { $singleVariant2Path }
  [IO.File]::Copy($source, $singlePath, $true)
}
$singleExpected1 = ($singleLineCount - 5) + 1
$singleExpected2 = ($singleLineCount - 5) + 2
$singleResult = Measure-Program 'Single file (100,000 lines)' $singlePath $swapSingle $singleExpected1 $singleExpected2

# --- Multi-module: ten 10,000-line chunks, only chunk1 ever changes -
# the actual "one function" in "one-function incremental rebuild". Both
# of chunk1's own variants are pre-generated once too, same reasoning. ---
$chunkCount = 10
$chunkBodyLines = 9995
$chunkTotalLines = $chunkBodyLines + 5  # fn header, var total, variant line, return, closing brace
$moduleDir = Join-Path $PSScriptRoot 'dist\benchmark-incremental-multi'
New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

function New-ChunkVariant([int]$Chunk, [int]$LastValue, [string]$TargetPath) {
  $lines = [Collections.Generic.List[string]]::new($chunkTotalLines)
  $lines.Add("pub fn chunk$Chunk.run() -> int {")
  $lines.Add('  var total = 0')
  for ($index = 0; $index -lt $chunkBodyLines; $index++) { $lines.Add('  total = total + 1') }
  Write-GeneratedLines $lines $LastValue $TargetPath
  if ((Get-Content -LiteralPath $TargetPath).Count -ne $chunkTotalLines) { throw "chunk$Chunk generator produced the wrong line count for variant $LastValue" }
}

# Chunks 2-10 never change for the lifetime of this script - only
# chunk1 is swapped per sample, mirroring "you edited one function".
for ($chunk = 2; $chunk -le $chunkCount; $chunk++) {
  $chunkPath = Join-Path $moduleDir "chunk$chunk.lume"
  New-ChunkVariant $chunk 1 $chunkPath
}

$chunk1Path = Join-Path $moduleDir 'chunk1.lume'
$chunk1Variant1Path = Join-Path $moduleDir 'chunk1-v1.lume'
$chunk1Variant2Path = Join-Path $moduleDir 'chunk1-v2.lume'
New-ChunkVariant 1 1 $chunk1Variant1Path
New-ChunkVariant 1 2 $chunk1Variant2Path

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

$swapMulti = {
  param([int]$Variant)
  $source = if ($Variant -eq 1) { $chunk1Variant1Path } else { $chunk1Variant2Path }
  [IO.File]::Copy($source, $chunk1Path, $true)
}
$otherChunksTotal = ($chunkBodyLines + 1) * ($chunkCount - 1)
$multiExpected1 = $otherChunksTotal + ($chunkBodyLines + 1)
$multiExpected2 = $otherChunksTotal + ($chunkBodyLines + 2)
$multiResult = Measure-Program 'Multi-module (10 files, only chunk1 changes)' $rootPath $swapMulti $multiExpected1 $multiExpected2

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
