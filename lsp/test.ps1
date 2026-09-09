$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$server = Join-Path $PSScriptRoot 'lume-lsp.ps1'
$fixture = Join-Path $root 'examples\lsp-buffer.lume'
$utf8 = [Text.UTF8Encoding]::new($false)

$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = 'powershell.exe'
$start.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$server`""
$start.UseShellExecute = $false
$start.RedirectStandardInput = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$process = [Diagnostics.Process]::new()
$process.StartInfo = $start
[void]$process.Start()
$inputStream = $process.StandardInput.BaseStream
$outputStream = $process.StandardOutput.BaseStream

function Send-TestMessage($value) {
  $body = $utf8.GetBytes((ConvertTo-Json $value -Depth 20 -Compress))
  $header = $utf8.GetBytes("Content-Length: $($body.Length)`r`n`r`n")
  $inputStream.Write($header, 0, $header.Length)
  $inputStream.Write($body, 0, $body.Length)
  $inputStream.Flush()
}

function Read-TestMessage {
  $header = [Collections.Generic.List[byte]]::new()
  while ($true) {
    $next = $outputStream.ReadByte()
    if ($next -lt 0) { throw "Language server ended: $($process.StandardError.ReadToEnd())" }
    $header.Add([byte]$next)
    $n = $header.Count
    if ($n -ge 4 -and $header[$n-4] -eq 13 -and $header[$n-3] -eq 10 -and $header[$n-2] -eq 13 -and $header[$n-1] -eq 10) { break }
  }
  $match = [regex]::Match($utf8.GetString($header.ToArray()), '(?im)^Content-Length:\s*(\d+)\s*$')
  if (-not $match.Success) { throw 'Response has no Content-Length' }
  $length = [int]$match.Groups[1].Value
  $body = [byte[]]::new($length)
  $offset = 0
  while ($offset -lt $length) { $offset += $outputStream.Read($body, $offset, $length - $offset) }
  return ($utf8.GetString($body) | ConvertFrom-Json)
}

try {
  Send-TestMessage @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{} }
  $initialize = Read-TestMessage
  if (-not $initialize.result.capabilities.hoverProvider) { throw 'initialize did not advertise hover' }

  $uri = [Uri]::new($fixture).AbsoluteUri
  $source = "fn main(args: [str]) -> int {`n  return missing`n}`n"
  Send-TestMessage @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $uri; languageId = 'lume'; version = 1; text = $source } } }
  $diagnostics = Read-TestMessage
  if ($diagnostics.method -ne 'textDocument/publishDiagnostics' -or $diagnostics.params.diagnostics.Count -ne 1) { throw 'expected one live diagnostic' }

  Send-TestMessage @{ jsonrpc = '2.0'; id = 2; method = 'textDocument/completion'; params = @{ textDocument = @{ uri = $uri }; position = @{ line = 1; character = 2 } } }
  $completion = Read-TestMessage
  if (-not ($completion.result.items.label -contains 'process.run')) { throw 'core completion is missing' }

  Send-TestMessage @{ jsonrpc = '2.0'; id = 3; method = 'textDocument/formatting'; params = @{ textDocument = @{ uri = $uri }; options = @{ tabSize = 2; insertSpaces = $true } } }
  $formatting = Read-TestMessage
  if ($formatting.result.Count -ne 1) { throw 'formatter returned no edit' }

  Send-TestMessage @{ jsonrpc = '2.0'; id = 4; method = 'shutdown'; params = $null }
  [void](Read-TestMessage)
  Send-TestMessage @{ jsonrpc = '2.0'; method = 'exit'; params = $null }
  $inputStream.Close()
  if (-not $process.WaitForExit(5000)) { throw 'language server did not exit' }
  if ($process.ExitCode -ne 0) { throw "language server exited $($process.ExitCode): $($process.StandardError.ReadToEnd())" }
  Write-Host 'PASS LSP framing, diagnostics, completion, and formatting'
} finally {
  if (-not $process.HasExited) { $process.Kill() }
  $process.Dispose()
}

