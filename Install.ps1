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
$targets = @(
    [pscustomobject]@{
        Name = 'Windows PowerShell'
        ModuleBase = Join-Path $documents 'WindowsPowerShell\Modules'
        ProfilePath = Join-Path $documents 'WindowsPowerShell\profile.ps1'
    },
    [pscustomobject]@{
        Name = 'PowerShell 7+'
        ModuleBase = Join-Path $documents 'PowerShell\Modules'
        ProfilePath = Join-Path $documents 'PowerShell\profile.ps1'
    }
)

$startMarker = '# >>> PowerShell HAL >>>'
$endMarker = '# <<< PowerShell HAL <<<'
$profileBlock = @"
$startMarker
Import-Module PowerShellHAL -ErrorAction SilentlyContinue
Enable-PowerShellHAL -Chord 'Ctrl+Spacebar'
$endMarker
"@

foreach ($target in $targets) {
    $destination = Join-Path $target.ModuleBase "$moduleName\$version"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item $sourceModule (Join-Path $destination 'PowerShellHAL.psm1') -Force
    Copy-Item $sourceManifest (Join-Path $destination 'PowerShellHAL.psd1') -Force

    $profileDirectory = Split-Path -Parent $target.ProfilePath
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
    if (-not (Test-Path $target.ProfilePath)) {
        New-Item -ItemType File -Path $target.ProfilePath -Force | Out-Null
    }

    $profileText = Get-Content $target.ProfilePath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $profileText) { $profileText = '' }

    $escapedStart = [regex]::Escape($startMarker)
    $escapedEnd = [regex]::Escape($endMarker)
    $pattern = "(?s)$escapedStart.*?$escapedEnd\s*"
    $profileText = [regex]::Replace($profileText, $pattern, '').TrimEnd()

    if ($profileText.Length -gt 0) {
        $profileText += "`r`n`r`n"
    }
    $profileText += $profileBlock
    Set-Content -Path $target.ProfilePath -Value $profileText -Encoding UTF8

    Write-Host "Configured $($target.Name)." -ForegroundColor DarkGray
}

$currentModuleBase = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path $documents 'PowerShell\Modules'
}
else {
    Join-Path $documents 'WindowsPowerShell\Modules'
}
$currentDestination = Join-Path $currentModuleBase "$moduleName\$version"
Import-Module (Join-Path $currentDestination 'PowerShellHAL.psd1') -Force
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
