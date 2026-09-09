param(
  [string]$Lume = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist\lume.exe')
)

$ErrorActionPreference = 'Stop'
$inputStream = [Console]::OpenStandardInput()
$outputStream = [Console]::OpenStandardOutput()
$utf8 = [Text.UTF8Encoding]::new($false)
$documents = @{}
$shutdown = $false

function Send-Message($value) {
  $json = ConvertTo-Json $value -Depth 30 -Compress
  $body = $utf8.GetBytes($json)
  $header = $utf8.GetBytes("Content-Length: $($body.Length)`r`n`r`n")
  $outputStream.Write($header, 0, $header.Length)
  $outputStream.Write($body, 0, $body.Length)
  $outputStream.Flush()
}

function Read-Message {
  $headerBytes = [Collections.Generic.List[byte]]::new()
  while ($true) {
    $next = $inputStream.ReadByte()
    if ($next -lt 0) { return $null }
    $headerBytes.Add([byte]$next)
    $count = $headerBytes.Count
    if ($count -ge 4 -and $headerBytes[$count-4] -eq 13 -and
        $headerBytes[$count-3] -eq 10 -and $headerBytes[$count-2] -eq 13 -and
        $headerBytes[$count-1] -eq 10) { break }
  }
  $headers = $utf8.GetString($headerBytes.ToArray())
  $match = [regex]::Match($headers, '(?im)^Content-Length:\s*(\d+)\s*$')
  if (-not $match.Success) { throw 'LSP message has no Content-Length header' }
  $length = [int]$match.Groups[1].Value
  $body = [byte[]]::new($length)
  $offset = 0
  while ($offset -lt $length) {
    $read = $inputStream.Read($body, $offset, $length - $offset)
    if ($read -le 0) { throw 'Unexpected end of LSP message' }
    $offset += $read
  }
  return ($utf8.GetString($body) | ConvertFrom-Json)
}

function Get-Word($text, $position) {
  $lines = $text -split "`r?`n", -1
  if ($position.line -ge $lines.Count) { return '' }
  $line = $lines[[int]$position.line]
  $column = [Math]::Min([int]$position.character, $line.Length)
  $start = $column
  while ($start -gt 0 -and $line[$start - 1] -match '[A-Za-z0-9_.]') { $start-- }
  $end = $column
  while ($end -lt $line.Length -and $line[$end] -match '[A-Za-z0-9_.]') { $end++ }
  if ($end -le $start) { return '' }
  return $line.Substring($start, $end - $start)
}

function Format-Lume($text) {
  $result = [Collections.Generic.List[string]]::new()
  $indent = 0
  $lastBlank = $false
  foreach ($raw in ($text -split "`r?`n", -1)) {
    $line = $raw.Trim()
    if ($line.Length -eq 0) {
      if ($result.Count -gt 0 -and -not $lastBlank) { $result.Add('') }
      $lastBlank = $true
      continue
    }
    if ($line.StartsWith('}')) { $indent = [Math]::Max(0, $indent - 1) }
    $result.Add(('  ' * $indent) + $line)
    if ($line.EndsWith('{')) { $indent++ }
    $lastBlank = $false
  }
  while ($result.Count -gt 0 -and $result[$result.Count - 1] -eq '') {
    $result.RemoveAt($result.Count - 1)
  }
  return (($result -join "`n") + "`n")
}

function Get-Diagnostics($uri, $text) {
  $sourcePath = ([Uri]$uri).LocalPath
  $folder = Split-Path -Parent $sourcePath
  if (-not (Test-Path -LiteralPath $folder)) { return @() }
  $temporary = Join-Path $folder ('.lume-lsp-{0}-{1}.lume' -f $PID, [guid]::NewGuid().ToString('N'))
  try {
    [IO.File]::WriteAllText($temporary, $text, $utf8)
    $output = @(& $Lume check $temporary --json 2>&1)
    if ($LASTEXITCODE -eq 0) { return @() }
    $record = $output | ForEach-Object {
      try { $_.ToString() | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ } | Select-Object -Last 1
    if (-not $record) {
      return @(@{ range = @{ start = @{ line = 0; character = 0 }; end = @{ line = 0; character = 1 } }; severity = 1; source = 'lume'; code = 'E0000'; message = ($output -join "`n") })
    }
    $line = [Math]::Max(0, [int]$record.line - 1)
    return @(@{ range = @{ start = @{ line = $line; character = 0 }; end = @{ line = $line; character = 1 } }; severity = 1; source = 'lume'; code = $record.code; message = $record.message })
  } finally {
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
  }
}

function Publish-Diagnostics($uri) {
  $text = [string]$documents[$uri]
  Send-Message @{ jsonrpc = '2.0'; method = 'textDocument/publishDiagnostics'; params = @{ uri = $uri; diagnostics = @(Get-Diagnostics $uri $text) } }
}

$keywords = @('use','pub','fn','let','var','if','else','while','for','in','return','true','false','print','eprint','int','str','bool','ok','err')
$builtins = @()
$apiPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ai\lume-api.json'
if (Test-Path -LiteralPath $apiPath) {
  $api = Get-Content -LiteralPath $apiPath -Raw | ConvertFrom-Json
  $builtins = @($api.builtins)
}

while ($true) {
  $message = Read-Message
  if ($null -eq $message) { break }
  $method = [string]$message.method
  $idPresent = $null -ne $message.PSObject.Properties['id']
  try {
    switch ($method) {
      'initialize' {
        Send-Message @{ jsonrpc = '2.0'; id = $message.id; result = @{ capabilities = @{ textDocumentSync = 1; completionProvider = @{ triggerCharacters = @('.') }; hoverProvider = $true; definitionProvider = $true; documentFormattingProvider = $true }; serverInfo = @{ name = 'lume-lsp'; version = '0.1.0' } } }
      }
      'initialized' {}
      'shutdown' { $shutdown = $true; Send-Message @{ jsonrpc = '2.0'; id = $message.id; result = $null } }
      'exit' { if ($shutdown) { exit 0 } else { exit 1 } }
      'textDocument/didOpen' {
        $uri = [string]$message.params.textDocument.uri
        $documents[$uri] = [string]$message.params.textDocument.text
        Publish-Diagnostics $uri
      }
      'textDocument/didChange' {
        $uri = [string]$message.params.textDocument.uri
        $documents[$uri] = [string]$message.params.contentChanges[-1].text
        Publish-Diagnostics $uri
      }
      'textDocument/didSave' { Publish-Diagnostics ([string]$message.params.textDocument.uri) }
      'textDocument/didClose' {
        $uri = [string]$message.params.textDocument.uri
        $documents.Remove($uri)
        Send-Message @{ jsonrpc = '2.0'; method = 'textDocument/publishDiagnostics'; params = @{ uri = $uri; diagnostics = @() } }
      }
      'textDocument/completion' {
        $items = @($keywords | ForEach-Object { @{ label = $_; kind = 14 } })
        $items += @($builtins | ForEach-Object { @{ label = $_.name; kind = 3; detail = "Lume builtin ($($_.arity) arguments)"; insertText = $_.name } })
        Send-Message @{ jsonrpc = '2.0'; id = $message.id; result = @{ isIncomplete = $false; items = $items } }
      }
      'textDocument/hover' {
        $uri = [string]$message.params.textDocument.uri
        $word = Get-Word ([string]$documents[$uri]) $message.params.position
        $builtin = $builtins | Where-Object { $_.name -eq $word } | Select-Object -First 1
        $value = $null
        if ($builtin) { $value = @{ kind = 'markdown'; value = ('`{0}(...)`  ' + "`n" + 'Lume builtin; {1} argument(s).' -f $builtin.name, $builtin.arity) } }
        elseif ($keywords -contains $word) { $value = @{ kind = 'markdown'; value = ('`{0}` - Lume keyword' -f $word) } }
        Send-Message @{ jsonrpc = '2.0'; id = $message.id; result = $(if ($value) { @{ contents = $value } } else { $null }) }
      }
      'textDocument/definition' {
        $uri = [string]$message.params.textDocument.uri
        $text = [string]$documents[$uri]
        $word = Get-Word $text $message.params.position
        $short = ($word -split '\.')[-1]
        $match = [regex]::Match($text, "(?m)^\s*(?:pub\s+)?fn\s+$([regex]::Escape($short))\s*\(")
        $location = $null
        if ($match.Success) {
          $line = ($text.Substring(0, $match.Index) -split "`n", -1).Count - 1
          $character = [Math]::Max(0, $match.Value.LastIndexOf($short))
          $location = @{ uri = $uri; range = @{ start = @{ line = $line; character = $character }; end = @{ line = $line; character = $character + $short.Length } } }
        }
        Send-Message @{ jsonrpc = '2.0'; id = $message.id; result = $location }
      }
      'textDocument/formatting' {
        $uri = [string]$message.params.textDocument.uri
        $text = [string]$documents[$uri]
        $lines = $text -split "`r?`n", -1
        $edit = @{ range = @{ start = @{ line = 0; character = 0 }; end = @{ line = $lines.Count; character = 0 } }; newText = Format-Lume $text }
        Send-Message @{ jsonrpc = '2.0'; id = $message.id; result = @($edit) }
      }
      default {
        if ($idPresent) { Send-Message @{ jsonrpc = '2.0'; id = $message.id; error = @{ code = -32601; message = "Method not found: $method" } } }
      }
    }
  } catch {
    if ($idPresent) { Send-Message @{ jsonrpc = '2.0'; id = $message.id; error = @{ code = -32603; message = $_.Exception.Message } } }
  }
}
