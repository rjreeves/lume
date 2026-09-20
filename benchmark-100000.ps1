param(
  # Fresh-process-per-sample, not `lume benchmark`'s in-process loop -
  # BENCHMARKS.md's own "Fixing lume benchmark's out-of-memory crash"
  # checkpoint explicitly says any future large-program benchmark script
  # should follow benchmark-10000-features.ps1's pattern instead, since
  # Certo has no garbage collector and retains every allocation across
  # iterations. A single `lume check` of this 100,000-line file takes
  # ~624 ms (measured directly before choosing this iteration count), so
  # 30 samples (this file's own "at least 30 runs" contract) costs under
  # 20 seconds.
  [int]$Iterations = 30,
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe')
)

$ErrorActionPreference = 'Stop'
$lineCount = 100000
$path = Join-Path $PSScriptRoot 'dist\benchmark-100000.lume'

# The exact same trivial `total = total + 1` shape as benchmark-10000.ps1,
# scaled 10x - the first measurement in this file past 10,000 lines. See
# benchmark-multi-module.ps1 for the same total line count split across
# ten `use`-linked files, measured the same way, for a direct comparison.
$lines = [Collections.Generic.List[string]]::new($lineCount)
$lines.Add('fn main(args: [str]) -> int {')
$lines.Add('  var total = 0')
for ($index = 0; $index -lt ($lineCount - 4); $index++) {
  $lines.Add('  total = total + 1')
}
$lines.Add('  return total')
$lines.Add('}')

if ($lines.Count -ne $lineCount) { throw "generator produced $($lines.Count) lines" }
[IO.File]::WriteAllLines($path, $lines, [Text.UTF8Encoding]::new($false))

# Validate the generated program before measuring it.
& $Lume check $path | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'generated benchmark did not compile' }

# One fresh lume.exe process per sample - see the -Iterations comment
# above. Mirrors benchmark-10000-features.ps1's own Measure-Samples.
function Measure-Samples([scriptblock]$Action, [int]$Count) {
  1..$Count | ForEach-Object {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    & $Action | Out-Null
    $watch.Stop()
    if ($LASTEXITCODE -ne 0) { throw "lume check failed during a timed sample (exit $LASTEXITCODE)" }
    $watch.Elapsed.TotalMilliseconds
  }
}

$samples = @(Measure-Samples { & $Lume check $path } $Iterations)
$sorted = @($samples | Sort-Object)
$compileMean = ($samples | Measure-Object -Average).Average
$medianMs = $sorted[[Math]::Floor(($Iterations - 1) / 2)]
$p95Index = [Math]::Min($Iterations - 1, [Math]::Ceiling(0.95 * $Iterations) - 1)
$p95Ms = $sorted[$p95Index]
$variance = (($samples | ForEach-Object { [Math]::Pow($_ - $compileMean, 2) } | Measure-Object -Sum).Sum) / $Iterations
$stdDevMs = [Math]::Sqrt($variance)
$targetLinesPerSecond = 10000
$compileLinesPerSecond = $lineCount / ($compileMean / 1000)

[pscustomobject]@{
  SourceLines = $lineCount
  Iterations = $Iterations
  CompileMeanMs = [Math]::Round($compileMean, 3)
  MedianMs = [Math]::Round($medianMs, 3)
  P95Ms = [Math]::Round($p95Ms, 3)
  StdDevMs = [Math]::Round($stdDevMs, 3)
  CompileLinesPerSecond = [Math]::Round($compileLinesPerSecond)
  TargetLinesPerSecond = $targetLinesPerSecond
  TargetMet = $compileLinesPerSecond -ge $targetLinesPerSecond
}
