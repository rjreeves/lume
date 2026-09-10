param(
  # NOTE: default is 1, not 20 like benchmark-10000.ps1's. The in-process
  # `lume benchmark` command retains state across iterations, and on this
  # feature-rich workload that leads to `certo panic: out of memory` well
  # before 20 iterations complete (confirmed: it OOMs during iteration
  # accumulation, not during the one-off `lume check` validation pass,
  # which alone takes ~23s). Raise this only to intentionally reproduce
  # that crash.
  [int]$Iterations = 1,
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

# Validate the generated program before measuring it.
& $Lume check $path | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'generated feature benchmark did not compile' }

$result = @(& $Lume benchmark $path $Iterations)
if ($LASTEXITCODE -ne 0) { throw 'in-process benchmark failed' }
$compileTotal = [double](($result | Where-Object { $_ -like 'compile_total_ms=*' }) -replace '^compile_total_ms=', '')
$bytecodeTotal = [double](($result | Where-Object { $_ -like 'bytecode_load_total_ms=*' }) -replace '^bytecode_load_total_ms=', '')
$compileMean = $compileTotal / $Iterations
$bytecodeMean = $bytecodeTotal / $Iterations
$targetLinesPerSecond = 10000
$compileLinesPerSecond = $lineCount / ($compileMean / 1000)

[pscustomobject]@{
  SourceLines = $lineCount
  Repetitions = $repetitions
  Iterations = $Iterations
  CompileTotalMs = $compileTotal
  CompileMeanMs = [Math]::Round($compileMean, 3)
  CompileLinesPerSecond = [Math]::Round($compileLinesPerSecond)
  BytecodeLoadMeanMs = [Math]::Round($bytecodeMean, 3)
  TargetLinesPerSecond = $targetLinesPerSecond
  TargetMet = $compileLinesPerSecond -ge $targetLinesPerSecond
}
