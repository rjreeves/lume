param(
  [Parameter(Mandatory)]
  [string]$Candidates,
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe'),
  [string]$Tasks = (Join-Path $PSScriptRoot 'ai\tasks.json')
)

$ErrorActionPreference = 'Stop'
$taskList = Get-Content -LiteralPath $Tasks -Raw | ConvertFrom-Json
$results = foreach ($task in $taskList) {
  $source = Join-Path $Candidates ($task.id + '.lume')
  if (-not (Test-Path -LiteralPath $source)) {
    [pscustomobject]@{ Task = $task.id; Compiles = $false; Runs = $false; Correct = $false; Detail = 'missing candidate' }
    continue
  }

  $diagnostic = & $Lume check $source --json 2>&1
  $compiles = $LASTEXITCODE -eq 0
  if (-not $compiles) {
    [pscustomobject]@{ Task = $task.id; Compiles = $false; Runs = $false; Correct = $false; Detail = ($diagnostic -join "`n") }
    continue
  }

  $arguments = @('run', $source) + @($task.args)
  $actual = & $Lume @arguments 2>&1
  $runs = $LASTEXITCODE -eq 0
  $actualText = ($actual -join "`n").Trim()
  $correct = $runs -and $actualText -ceq ([string]$task.stdout).Trim()
  [pscustomobject]@{
    Task = $task.id
    Compiles = $compiles
    Runs = $runs
    Correct = $correct
    Detail = if ($correct) { 'ok' } else { "expected: $($task.stdout); actual: $actualText" }
  }
}

$results | Format-Table -AutoSize
$total = @($results).Count
$correctCount = @($results | Where-Object Correct).Count
$compileCount = @($results | Where-Object Compiles).Count
Write-Host "Compile rate: $compileCount/$total"
Write-Host "Correct rate: $correctCount/$total"
if ($correctCount -ne $total) { exit 1 }
