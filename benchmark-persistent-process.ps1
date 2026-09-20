param(
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe'),
  [int]$FreshSamples = 10,
  [int[]]$PersistentIterations = @(1, 5, 20),
  # 3 repeats produced a noisy drift reading on the trivial file (single-
  # digit-to-tens-of-ms absolute magnitudes, where OS scheduling jitter
  # dominates a lone N=1 sample) - 8 repeats settled to a stable, small
  # (+4-7%) reading across repeated runs; kept as the default rather than
  # a faster-but-noisier one.
  [int]$PersistentRepeats = 8
)

$ErrorActionPreference = 'Stop'

# BENCHMARKS.md's own methodology says "Exclude process startup only in
# a separately labelled persistent-daemon test" - a contract every other
# script in this file either honors (by timing a fresh lume.exe process
# per sample, startup included) or has historically violated by
# excluding startup unconditionally (see "Fixing lume benchmark's
# out-of-memory crash" in BENCHMARKS.md). This script is that labelled
# test. It is NOT a real request-serving daemon - Lume has no such
# thing, no IPC, no persistent server. `lume benchmark <path> <N>` (the
# only mechanism that exists) is a same-process repeated-compile loop:
# the closest available proxy, since the OS process itself never
# restarts between compiles.
#
# Certo has no garbage collector or exposed free primitive, so every
# iteration inside one `lume benchmark` call retains its Tokens/
# Instructions/strings for the process's entire lifetime (~110-140 MB
# per iteration on the feature-mix file, confirmed in the same
# out-of-memory checkpoint). Each (file, N) combination below therefore
# runs in its own fresh lume.exe invocation, so growth is bounded to
# within one N rather than accumulating across this whole script's run -
# and this script explicitly checks whether per-iteration time drifts
# upward as N grows (the retained heap's own allocator/page-fault cost),
# rather than assuming a flat per-iteration mean is safe to report.

$trivialPath = Join-Path $PSScriptRoot 'dist\benchmark-10000.lume'
$featurePath = Join-Path $PSScriptRoot 'dist\benchmark-10000-features.lume'
if (-not (Test-Path -LiteralPath $trivialPath)) {
  & (Join-Path $PSScriptRoot 'benchmark-10000.ps1') -Lume $Lume | Out-Null
}
if (-not (Test-Path -LiteralPath $featurePath)) {
  & (Join-Path $PSScriptRoot 'benchmark-10000-features.ps1') -Lume $Lume | Out-Null
}
if (-not (Test-Path -LiteralPath $trivialPath)) { throw "missing $trivialPath after regeneration attempt" }
if (-not (Test-Path -LiteralPath $featurePath)) { throw "missing $featurePath after regeneration attempt" }

function Measure-FreshMeanMs([string]$Path, [int]$Count) {
  $samples = 1..$Count | ForEach-Object {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    & $Lume check $Path | Out-Null
    $watch.Stop()
    if ($LASTEXITCODE -ne 0) { throw "lume check failed during a fresh-process sample (exit $LASTEXITCODE)" }
    $watch.Elapsed.TotalMilliseconds
  }
  ($samples | Measure-Object -Average).Average
}

function Measure-PersistentPerIterationMs([string]$Path, [int]$N) {
  $result = @(& $Lume benchmark $Path $N)
  if ($LASTEXITCODE -ne 0) { throw "lume benchmark failed for N=$N (exit $LASTEXITCODE)" }
  $totalMs = [double](($result | Where-Object { $_ -like 'compile_total_ms=*' }) -replace '^compile_total_ms=', '')
  $totalMs / $N
}

function Measure-PersistentSweep([string]$Path) {
  # A plain Hashtable, not [ordered]@{} - OrderedDictionary has an
  # ambiguous int indexer (positional access) that silently hijacks an
  # [int] key like $n into an index lookup instead of a dictionary
  # lookup, throwing ArgumentOutOfRangeException the moment $n exceeds
  # however many entries exist so far.
  $byN = @{}
  foreach ($n in $PersistentIterations) {
    $means = 1..$PersistentRepeats | ForEach-Object { Measure-PersistentPerIterationMs $Path $n }
    $byN[$n] = ($means | Measure-Object -Average).Average
  }
  $byN
}

function Measure-Benchmark([string]$Label, [string]$Path) {
  & $Lume check $Path | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "$Label did not compile before measuring" }

  $freshMeanMs = Measure-FreshMeanMs $Path $FreshSamples
  $persistent = Measure-PersistentSweep $Path
  $firstN = $PersistentIterations[0]
  $lastN = $PersistentIterations[$PersistentIterations.Count - 1]
  $firstMeanMs = $persistent[$firstN]
  $lastMeanMs = $persistent[$lastN]
  $driftPercent = if ($firstMeanMs -gt 0) { (($lastMeanMs - $firstMeanMs) / $firstMeanMs) * 100 } else { 0 }
  # `lume benchmark`'s loop times compileSource() alone, on source text
  # already read into memory once before the loop starts - so this gap
  # is process startup + one disk read + CLI dispatch, not process
  # startup in isolation. Named accordingly, not "ProcessStartupMs".
  $overheadMs = $freshMeanMs - $firstMeanMs

  [pscustomobject]@{
    Benchmark                          = $Label
    FreshProcessMeanMs                 = [Math]::Round($freshMeanMs, 3)
    "PersistentPerIterMs(N=$firstN)"   = [Math]::Round($firstMeanMs, 3)
    "PersistentPerIterMs(N=$lastN)"    = [Math]::Round($lastMeanMs, 3)
    DriftPercent                       = [Math]::Round($driftPercent, 1)
    EstimatedStartupAndIoMs            = [Math]::Round($overheadMs, 3)
  }
}

@(
  Measure-Benchmark 'Trivial 10,000-line' $trivialPath
  Measure-Benchmark 'Feature-mix 10,000-line' $featurePath
) | Format-Table -AutoSize
