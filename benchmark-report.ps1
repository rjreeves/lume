param(
  # How many times each benchmark script is run. One run says little on a
  # shared cloud VM - BENCHMARKS.md's own contract is "at least 30 runs"
  # per measurement inside each script, and this repeats whole scripts on
  # top of that so run-to-run variance on the machine is visible too.
  [int]$Repeat = 3,
  # Adds the larger and incremental benchmarks (slower).
  [switch]$Extended,
  [string]$OutFile = (Join-Path $PSScriptRoot 'dist\benchmark-report.md')
)

$ErrorActionPreference = 'Stop'

# Runs the repo's own benchmark scripts and writes one markdown report:
# the machine's hardware table (the same rows BENCHMARKS.md's "Hardware
# environment" section records, so a second machine's numbers land in a
# comparable table - see "Reproducing these numbers on another machine"
# there), then every run's result as the script itself printed it. It
# measures nothing itself; the numbers come from the existing scripts.
#
# Run from the repo root after .\build.ps1 has produced dist\lume.exe.
# Used by .github/workflows/benchmarks.yml, but runs fine locally too.

$scripts = @('benchmark.ps1', 'benchmark-10000.ps1', 'benchmark-10000-features.ps1', 'benchmark-10000-generic-dispatch.ps1')
if ($Extended) {
  $scripts += @('benchmark-100000.ps1', 'benchmark-multi-module.ps1', 'benchmark-incremental-rebuild.ps1')
}

if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'dist\lume.exe'))) {
  throw 'dist\lume.exe not found - run .\build.ps1 first'
}

function Get-HardwareRows {
  $cpus = @(Get-CimInstance Win32_Processor)
  $system = Get-CimInstance Win32_ComputerSystem
  $os = Get-CimInstance Win32_OperatingSystem
  $disk = 'unavailable'
  try {
    $physical = Get-PhysicalDisk -ErrorAction Stop | Select-Object -First 1
    $disk = "$($physical.FriendlyName) ($($physical.MediaType))"
  } catch { }
  [ordered]@{
    'CPU'            = $cpus[0].Name.Trim()
    'Cores / logical' = "$(($cpus | Measure-Object NumberOfCores -Sum).Sum) / $(($cpus | Measure-Object NumberOfLogicalProcessors -Sum).Sum)"
    'RAM'            = "$([math]::Round($system.TotalPhysicalMemory / 1GB, 1)) GB"
    'Storage'        = $disk
    'OS'             = "$($os.Caption.Trim()), build $($os.BuildNumber), $($os.OSArchitecture)"
    # Whether this is a VM shows up here (a cloud runner reports a virtual
    # machine model). Win32_ComputerSystem.HypervisorPresent is deliberately
    # not reported: it is True on a physical Windows 11 machine too whenever
    # virtualization-based security or WSL2/Docker is on, so it can't tell the
    # two apart.
    'Machine'        = "$($system.Manufacturer) $($system.Model)".Trim()
  }
}

$report = [System.Text.StringBuilder]::new()
[void]$report.AppendLine('# Benchmark report')
[void]$report.AppendLine()
[void]$report.AppendLine("Generated $((Get-Date).ToUniversalTime().ToString('u')) - $Repeat run(s) of each script.")
[void]$report.AppendLine()
[void]$report.AppendLine('## Hardware environment')
[void]$report.AppendLine()
[void]$report.AppendLine('| Component | Value |')
[void]$report.AppendLine('| --- | --- |')
foreach ($row in (Get-HardwareRows).GetEnumerator()) {
  [void]$report.AppendLine("| $($row.Key) | $($row.Value) |")
}

$failed = @()
foreach ($script in $scripts) {
  [void]$report.AppendLine()
  [void]$report.AppendLine("## $script")
  for ($run = 1; $run -le $Repeat; $run++) {
    Write-Host "== $script (run $run of $Repeat) =="
    [void]$report.AppendLine()
    [void]$report.AppendLine("Run $run of ${Repeat}:")
    [void]$report.AppendLine()
    [void]$report.AppendLine('```text')
    try {
      $result = & (Join-Path $PSScriptRoot $script) | Format-List | Out-String
      [void]$report.AppendLine($result.Trim())
      Write-Host $result
    } catch {
      $failed += "$script (run $run)"
      [void]$report.AppendLine("FAILED: $($_.Exception.Message)")
      Write-Host "FAILED: $($_.Exception.Message)"
    }
    [void]$report.AppendLine('```')
  }
}

New-Item -ItemType Directory -Path (Split-Path -Parent $OutFile) -Force | Out-Null
Set-Content -LiteralPath $OutFile -Value $report.ToString() -Encoding utf8
Write-Host "wrote $OutFile"

if ($failed.Count -gt 0) {
  Write-Host "FAILED: $($failed -join ', ')"
  exit 1
}
