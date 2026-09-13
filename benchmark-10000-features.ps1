param(
  # Each iteration spawns a fresh lume.exe process (see Measure-Samples
  # below) rather than looping inside one process via `lume benchmark`,
  # since Certo has no garbage collector or exposed free primitive - a
  # long-running process retains every Token/Instruction/string a compile
  # pass allocates for its entire lifetime. `lume benchmark <path> 20`
  # reliably OOMs on this feature-rich workload well before 20 iterations
  # (confirmed: ~110-140 MB retained per iteration, no plateau - 20
  # iterations reaches 2.4 GB, 200 reaches 22+ GB). A fresh process per
  # sample sidesteps this entirely, since the OS reclaims memory on exit,
  # so 30 (BENCHMARKS.md's own "at least 30 runs" contract) is safe here
  # unlike the in-process `lume benchmark` approach this replaced. A
  # single `lume check` of this file takes ~277 ms, so 30 samples costs
  # under 10 seconds.
  [int]$Iterations = 30,
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe')
)

$ErrorActionPreference = 'Stop'
$lineCount = 10000
$path = Join-Path $PSScriptRoot 'dist\benchmark-10000-features.lume'

# A representative-feature benchmark: unlike benchmark-10000.ps1's plain
# `total = total + 1` repetition, every generated iteration exercises
# records, an enum matched with `match`, a marker protocol constraint, a
# user-defined generic function, an inline closure capturing a `let`, and
# list.map/filter/fold with both `&name` references and a closure — the
# full feature surface a real Lume program actually uses, not just
# arithmetic. See BENCHMARKS.md for why benchmark-10000.ps1 alone cannot
# tell you whether these features cost anything at compile time.

$preamble = @'
enum Priority {
  low
  medium
  high
}

type Metric {
  id: int
  priority: Priority
}

protocol Sized {}

impl Sized for Metric {}

fn classify(value: int) -> Priority {
  if value % 3 == 0 {
    return Priority.high()
  }
  if value % 2 == 0 {
    return Priority.medium()
  }
  return Priority.low()
}

fn describe(priority: Priority) -> str {
  return match priority {
    low => "LOW"
    medium => "MEDIUM"
    high => "HIGH"
  }
}

fn is_even(value: int) -> bool {
  return value % 2 == 0
}

fn add(total: int, value: int) -> int {
  return total + value
}

fn pick<T>(items: [T]) -> Option<T> {
  if list.len(items) == 0 {
    return Option.None()
  }
  return Option.Some(value: list.get(items, 0))
}

fn tag<T: Sized>(value: T) -> str {
  return "sized"
}

fn main(args: [str]) -> int {
  var total = 0
'@ -split "`r?`n"

$closing = @('  return total', '}')

function Get-IterationBlock([int]$i) {
  @(
    "  let items$i = [1, 2, 3, 4, 5]",
    "  let bonus$i = $i",
    "  let doubled$i = list.map(items$i, fn(value: int) -> int => value * 2 + bonus$i)",
    "  let evens$i = list.filter(items$i, &is_even)",
    "  let summed$i = list.fold(items$i, 0, &add)",
    "  let metric$i = Metric(id: $i, priority: classify($i))",
    "  let updated$i = metric$i with { priority: Priority.high() }",
    "  let label$i = describe(updated$i.priority)",
    "  let picked$i = pick(evens$i)",
    "  let tagged$i = tag(metric$i)",
    "  total = total + summed$i + list.len(doubled$i)"
  )
}

$blockLineCount = (Get-IterationBlock 1).Count
$fixedLineCount = $preamble.Count + $closing.Count
$budget = $lineCount - $fixedLineCount
$repetitions = [Math]::Floor($budget / $blockLineCount)
$paddingCount = $budget - ($repetitions * $blockLineCount)

$lines = [Collections.Generic.List[string]]::new($lineCount)
$lines.AddRange([string[]]$preamble)
for ($i = 1; $i -le $repetitions; $i++) {
  $lines.AddRange([string[]](Get-IterationBlock $i))
}
for ($p = 0; $p -lt $paddingCount; $p++) {
  $lines.Add('  total = total + 1')
}
$lines.AddRange([string[]]$closing)

if ($lines.Count -ne $lineCount) { throw "generator produced $($lines.Count) lines, expected $lineCount" }
[IO.File]::WriteAllLines($path, $lines, [Text.UTF8Encoding]::new($false))

# Validate the generated program compiles before measuring it.
& $Lume check $path | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'generated feature benchmark did not compile' }

# One fresh lume.exe process per sample (see the -Iterations comment above
# for why) - mirrors benchmark.ps1's own Measure-Runs, but keeps every
# individual sample rather than only a total, since median/p95 need the
# per-run distribution.
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
  Repetitions = $repetitions
  Iterations = $Iterations
  CompileMeanMs = [Math]::Round($compileMean, 3)
  MedianMs = [Math]::Round($medianMs, 3)
  P95Ms = [Math]::Round($p95Ms, 3)
  StdDevMs = [Math]::Round($stdDevMs, 3)
  CompileLinesPerSecond = [Math]::Round($compileLinesPerSecond)
  TargetLinesPerSecond = $targetLinesPerSecond
  TargetMet = $compileLinesPerSecond -ge $targetLinesPerSecond
}
