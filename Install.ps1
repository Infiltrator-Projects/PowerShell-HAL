$ErrorActionPreference = 'Stop'

$moduleName = 'PowerShellHAL'
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceModule = Join-Path $sourceRoot 'PowerShellHAL.psm1'
$sourceManifest = Join-Path $sourceRoot 'PowerShellHAL.psd1'

if (-not (Test-Path $sourceModule) -or -not (Test-Path $sourceManifest)) {
    throw 'PowerShellHAL.psm1 and PowerShellHAL.psd1 must be beside Install.ps1.'
}

$manifest = Import-PowerShellDataFile -LiteralPath $sourceManifest
$version = ([Version]$manifest.ModuleVersion).ToString()

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
$profileLines = @(
    'Import-Module PowerShellHAL -ErrorAction SilentlyContinue'
    "Enable-PowerShellHAL -Chord 'Ctrl+Spacebar'"
)
. (Join-Path $sourceRoot 'Profile-Edit.ps1')

foreach ($target in $targets) {
    $destination = Join-Path $target.ModuleBase "$moduleName\$version"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item $sourceModule (Join-Path $destination 'PowerShellHAL.psm1') -Force
    Copy-Item $sourceManifest (Join-Path $destination 'PowerShellHAL.psd1') -Force

    $profileDirectory = Split-Path -Parent $target.ProfilePath
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
    Set-PowerShellHALProfileBlock -Path $target.ProfilePath -StartMarker $startMarker -EndMarker $endMarker -BodyLines $profileLines
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
Write-Host "PowerShell HAL $version installed." -ForegroundColor Green
Write-Host 'Ctrl+Spacebar opens HAL and inserts the generated command into the current PowerShell prompt.'
Write-Host 'HAL never presses Enter for you.'
Write-Host ''
if ([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
    Write-Host 'OPENAI_API_KEY is not set yet.' -ForegroundColor Yellow
    Write-Host 'Set it, then open a fresh PowerShell window.'
}
