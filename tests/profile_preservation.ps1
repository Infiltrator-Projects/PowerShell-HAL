# SPDX-License-Identifier: GPL-3.0-or-later
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Profile-Edit.ps1')
$folder = Join-Path ([System.IO.Path]::GetTempPath()) ('hal-profile-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $folder | Out-Null
$start = '# >>> PowerShell HAL >>>'
$end = '# <<< PowerShell HAL <<<'
$lines = @('Import-Module PowerShellHAL -ErrorAction SilentlyContinue', "Enable-PowerShellHAL -Chord 'Ctrl+Spacebar'")
$crlf = [string][char]13 + [char]10
try {
    foreach ($encoding in @(
        [System.Text.UTF8Encoding]::new($false),
        [System.Text.UTF8Encoding]::new($true),
        [System.Text.Encoding]::Unicode
    )) {
        $path = Join-Path $folder ([guid]::NewGuid().ToString() + '.ps1')
        $prefix = '# User-owned content' + $crlf + 'Write-Output "before"' + $crlf + $crlf
        $suffix = $crlf + $crlf + '# Other profile content' + $crlf + 'Write-Output "after"' + $crlf
        $original = $prefix + $start + $crlf + 'old HAL binding' + $crlf + $end + $suffix
        [System.IO.File]::WriteAllText($path, $original, $encoding)
        Set-PowerShellHALProfileBlock -Path $path -StartMarker $start -EndMarker $end -BodyLines $lines
        $updated = [System.IO.File]::ReadAllText($path, $encoding)
        if (-not $updated.StartsWith($prefix) -or -not $updated.EndsWith($suffix)) {
            throw 'Profile text outside HAL markers changed.'
        }
        if ($updated -notmatch 'Enable-PowerShellHAL') { throw 'HAL block missing.' }
        $first = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($path))
        Set-PowerShellHALProfileBlock -Path $path -StartMarker $start -EndMarker $end -BodyLines $lines
        $second = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($path))
        if ($first -ne $second) { throw 'Repeated installation rewrote a stable profile.' }
    }

    $newPath = Join-Path $folder 'fresh.ps1'
    Set-PowerShellHALProfileBlock -Path $newPath -StartMarker $start -EndMarker $end -BodyLines $lines
    if (-not [System.IO.File]::Exists($newPath)) { throw 'New profile not created.' }

    $bad = Join-Path $folder 'broken.ps1'
    [System.IO.File]::WriteAllText($bad, '# User text' + $crlf + $start + $crlf)
    $before = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($bad))
    $rejected = $false
    try {
        Set-PowerShellHALProfileBlock -Path $bad -StartMarker $start -EndMarker $end -BodyLines $lines
    } catch { $rejected = $true }
    $after = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($bad))
    if (-not $rejected -or $before -ne $after) {
        throw 'Incomplete HAL markers must be rejected without changes.'
    }
    'PowerShell HAL profile preservation contracts passed.'
} finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}
