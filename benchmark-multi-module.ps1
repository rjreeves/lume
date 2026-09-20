param(
  # Same fresh-process-per-sample rationale and iteration count as
  # benchmark-100000.ps1 - see that script's own header comment. Using
  # the identical iteration count here (not independently re-derived)
  # is what makes the two scripts' numbers directly comparable.
  [int]$Iterations = 30,
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe')
)

$ErrorActionPreference = 'Stop'

# The exact same total 100,000 lines and the exact same trivial
# `total = total + 1` shape as benchmark-100000.ps1, but split across ten
# `use`-linked files instead of one - so the two benchmarks answer one
# real question (does splitting into modules cost anything at compile
# time beyond the raw line count), not two unrelated numbers. Each chunk
# is its own module-qualified function (`pub fn chunkN.run()`, the same
# filename-qualified naming examples\modules\math.lume/stats.lume already
# use) so `use chunkN` resolves it with no lume.json/lume install needed -
# same-directory `use` needs no manifest.
$chunkCount = 10
$chunkBodyLines = 9996
$chunkTotalLines = $chunkBodyLines + 4  # fn header, var total, return, closing brace
$moduleDir = Join-Path $PSScriptRoot 'dist\benchmark-multi-module'
New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

for ($chunk = 1; $chunk -le $chunkCount; $chunk++) {
  $chunkPath = Join-Path $moduleDir "chunk$chunk.lume"
  $chunkLines = [Collections.Generic.List[string]]::new($chunkTotalLines)
  $chunkLines.Add("pub fn chunk$chunk.run() -> int {")
  $chunkLines.Add('  var total = 0')
  for ($index = 0; $index -lt $chunkBodyLines; $index++) {
    $chunkLines.Add('  total = total + 1')
  }
  $chunkLines.Add('  return total')
  $chunkLines.Add('}')
  if ($chunkLines.Count -ne $chunkTotalLines) { throw "chunk$chunk generator produced $($chunkLines.Count) lines, expected $chunkTotalLines" }
  [IO.File]::WriteAllLines($chunkPath, $chunkLines, [Text.UTF8Encoding]::new($false))
}

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

$chunkTotal = $chunkCount * $chunkTotalLines
$totalLines = $chunkTotal + $rootLines.Count

# Validate before measuring - both that it compiles and that every `use`
# actually resolved and contributed (not just that check exited 0). The
# expected total is chunkBodyLines increments per chunk, chunkCount times.
& $Lume check $rootPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'generated multi-module benchmark did not compile' }
$runOutput = & $Lume run $rootPath
$expectedExitCode = $chunkBodyLines * $chunkCount
if ($LASTEXITCODE -ne $expectedExitCode) { throw "expected exit code $expectedExitCode ($chunkBodyLines * $chunkCount), got $LASTEXITCODE - a use import silently failed to contribute" }

# One fresh lume.exe process per sample - same Measure-Samples as
# benchmark-100000.ps1 and benchmark-10000-features.ps1.
function Measure-Samples([scriptblock]$Action, [int]$Count) {
  1..$Count | ForEach-Object {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    & $Action | Out-Null
    $watch.Stop()
    if ($LASTEXITCODE -ne 0) { throw "lume check failed during a timed sample (exit $LASTEXITCODE)" }
    $watch.Elapsed.TotalMilliseconds
  }
}

$samples = @(Measure-Samples { & $Lume check $rootPath } $Iterations)
$sorted = @($samples | Sort-Object)
$compileMean = ($samples | Measure-Object -Average).Average
$medianMs = $sorted[[Math]::Floor(($Iterations - 1) / 2)]
$p95Index = [Math]::Min($Iterations - 1, [Math]::Ceiling(0.95 * $Iterations) - 1)
$p95Ms = $sorted[$p95Index]
$variance = (($samples | ForEach-Object { [Math]::Pow($_ - $compileMean, 2) } | Measure-Object -Sum).Sum) / $Iterations
$stdDevMs = [Math]::Sqrt($variance)
$targetLinesPerSecond = 10000
$compileLinesPerSecond = $totalLines / ($compileMean / 1000)

[pscustomobject]@{
  ChunkCount = $chunkCount
  ChunkLines = $chunkTotal
  RootLines = $rootLines.Count
  TotalLines = $totalLines
  Iterations = $Iterations
  CompileMeanMs = [Math]::Round($compileMean, 3)
  MedianMs = [Math]::Round($medianMs, 3)
  P95Ms = [Math]::Round($p95Ms, 3)
  StdDevMs = [Math]::Round($stdDevMs, 3)
  CompileLinesPerSecond = [Math]::Round($compileLinesPerSecond)
  TargetLinesPerSecond = $targetLinesPerSecond
  TargetMet = $compileLinesPerSecond -ge $targetLinesPerSecond
}
