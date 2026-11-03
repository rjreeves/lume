# Packages this extension as dist\<name>-<version>.vsix with no tooling beyond
# PowerShell (no node, npm, or vsce): a .vsix is a zip with a fixed layout.
param(
  [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\..\dist')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$package = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'package.json') -Raw | ConvertFrom-Json
$escape = { param($s) [System.Security.SecurityElement]::Escape($s) }

$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="$($package.name)" Version="$($package.version)" Publisher="$($package.publisher)" />
    <DisplayName>$(& $escape $package.displayName)</DisplayName>
    <Description xml:space="preserve">$(& $escape $package.description)</Description>
    <Categories>$($package.categories -join ',')</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="$($package.engines.vscode)" />
      <Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="workspace" />
    </Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code" /></Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
    <Asset Type="Microsoft.VisualStudio.Services.Content.Details" Path="extension/readme.md" Addressable="true" />
  </Assets>
</PackageManifest>
"@

$contentTypes = '<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".json" ContentType="application/json"/><Default Extension=".js" ContentType="application/javascript"/><Default Extension=".md" ContentType="text/markdown"/><Default Extension=".vsixmanifest" ContentType="text/xml"/></Types>'

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$output = Join-Path (Resolve-Path $OutputDirectory) "$($package.name)-$($package.version).vsix"
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$zip = [System.IO.Compression.ZipFile]::Open($output, 'Create')
try {
  $addText = {
    param($name, $text)
    $entry = $zip.CreateEntry($name)
    $stream = $entry.Open()
    $bytes = $utf8.GetBytes($text)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Dispose()
  }
  & $addText '[Content_Types].xml' $contentTypes
  & $addText 'extension.vsixmanifest' $manifest
  foreach ($file in 'package.json', 'extension.js', 'lspClient.js') {
    & $addText "extension/$file" (Get-Content -LiteralPath (Join-Path $PSScriptRoot $file) -Raw)
  }
  & $addText 'extension/readme.md' (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Raw)
} finally {
  $zip.Dispose()
}

Write-Output "wrote $output"
