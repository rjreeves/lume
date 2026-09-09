param(
  [int]$Iterations = 20,
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe')
)

$ErrorActionPreference = 'Stop'
$lineCount = 10000
$path = Join-Path $PSScriptRoot 'dist\benchmark-10000.lume'
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
  Iterations = $Iterations
  CompileTotalMs = $compileTotal
  CompileMeanMs = [Math]::Round($compileMean, 3)
  CompileLinesPerSecond = [Math]::Round($compileLinesPerSecond)
  BytecodeLoadMeanMs = [Math]::Round($bytecodeMean, 3)
  TargetLinesPerSecond = $targetLinesPerSecond
  TargetMet = $compileLinesPerSecond -ge $targetLinesPerSecond
}
