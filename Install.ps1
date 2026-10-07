$ErrorActionPreference = 'Stop'

$moduleName = 'PowerShellHAL'
$version = '0.1.0'
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceModule = Join-Path $sourceRoot 'PowerShellHAL.psm1'
$sourceManifest = Join-Path $sourceRoot 'PowerShellHAL.psd1'

if (-not (Test-Path $sourceModule) -or -not (Test-Path $sourceManifest)) {
    throw 'PowerShellHAL.psm1 and PowerShellHAL.psd1 must be beside Install.ps1.'
}

$documents = [Environment]::GetFolderPath('MyDocuments')
$moduleBase = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path $documents 'PowerShell\Modules'
}
else {
    Join-Path $documents 'WindowsPowerShell\Modules'
}

$destination = Join-Path $moduleBase "$moduleName\$version"
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item $sourceModule (Join-Path $destination 'PowerShellHAL.psm1') -Force
Copy-Item $sourceManifest (Join-Path $destination 'PowerShellHAL.psd1') -Force

$profilePath = $PROFILE.CurrentUserAllHosts
$profileDirectory = Split-Path -Parent $profilePath
New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$startMarker = '# >>> PowerShell HAL >>>'
$endMarker = '# <<< PowerShell HAL <<<'
$profileBlock = @"
$startMarker
Import-Module PowerShellHAL -ErrorAction SilentlyContinue
Enable-PowerShellHAL -Chord 'Ctrl+Spacebar'
$endMarker
"@

$profileText = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($null -eq $profileText) { $profileText = '' }

$escapedStart = [regex]::Escape($startMarker)
$escapedEnd = [regex]::Escape($endMarker)
$pattern = "(?s)$escapedStart.*?$escapedEnd\s*"
$profileText = [regex]::Replace($profileText, $pattern, '').TrimEnd()

if ($profileText.Length -gt 0) {
    $profileText += "`r`n`r`n"
}
$profileText += $profileBlock
Set-Content -Path $profilePath -Value $profileText -Encoding UTF8

Import-Module (Join-Path $destination 'PowerShellHAL.psd1') -Force
Enable-PowerShellHAL -Chord 'Ctrl+Spacebar'

Write-Host ''
Write-Host 'PowerShell HAL 0.1.0 installed.' -ForegroundColor Green
Write-Host 'Ctrl+Spacebar opens HAL and inserts the generated command into the current PowerShell prompt.'
Write-Host 'HAL never presses Enter for you.'
Write-Host ''
if ([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
    Write-Host 'OPENAI_API_KEY is not set yet.' -ForegroundColor Yellow
    Write-Host 'Set it, then open a fresh PowerShell window.'
}
