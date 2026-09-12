param(
  [int]$Iterations = 20,
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe')
)

$ErrorActionPreference = 'Stop'
$lineCount = 10000
$path = Join-Path $PSScriptRoot 'dist\benchmark-10000-generic-dispatch.lume'

# Unlike benchmark-10000.ps1 (plain arithmetic) and benchmark-10000-
# features.ps1 (one of everything), this generates many distinct
# `T.method(value)` generic-dispatch call sites inside a single generic
# function's body - the specific mechanism checkGenericProtocolCall/
# patchGenericDispatch/the runtime "generic_call" branches implement.
# Type-erased generics check a function's body exactly once regardless of
# how many times that function is later called, so stressing this
# mechanism at scale means many distinct dispatch call SITES, not many
# calls to one - hence one line per generated statement here, each its own
# `T.compare(value, target)` site, rather than one dispatch site called
# from a loop.

$preamble = @'
protocol Comparer {
  fn compare(value: Self, other: int) -> bool
}

type Box {
  amount: int
}

impl Comparer for Box {
  fn compare(value: Box, other: int) -> bool {
    return value.amount == other
  }
}

fn dispatch_many<T: Comparer>(value: T, target: int) -> bool {
'@ -split "`r?`n"

$closing = @('  return r1', '}', '', 'fn main(args: [str]) -> int {', '  print(dispatch_many(Box(amount: 5), 5))', '  return 0', '}')

function Get-IterationLine([int]$i) {
  "  let r$i = T.compare(value, target)"
}

$fixedLineCount = $preamble.Count + $closing.Count
$repetitions = $lineCount - $fixedLineCount

$lines = [Collections.Generic.List[string]]::new($lineCount)
$lines.AddRange([string[]]$preamble)
for ($i = 1; $i -le $repetitions; $i++) {
  $lines.Add((Get-IterationLine $i))
}
$lines.AddRange([string[]]$closing)

if ($lines.Count -ne $lineCount) { throw "generator produced $($lines.Count) lines, expected $lineCount" }
[IO.File]::WriteAllLines($path, $lines, [Text.UTF8Encoding]::new($false))

# Validate the generated program before measuring it.
& $Lume check $path | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'generated generic-dispatch benchmark did not compile' }

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
  DispatchCallSites = $repetitions
  Iterations = $Iterations
  CompileTotalMs = $compileTotal
  CompileMeanMs = [Math]::Round($compileMean, 3)
  CompileLinesPerSecond = [Math]::Round($compileLinesPerSecond)
  BytecodeLoadMeanMs = [Math]::Round($bytecodeMean, 3)
  TargetLinesPerSecond = $targetLinesPerSecond
  TargetMet = $compileLinesPerSecond -ge $targetLinesPerSecond
}
