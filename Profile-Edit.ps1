# SPDX-License-Identifier: GPL-3.0-or-later
# Edit only HAL's marked block, without normalising unrelated profile text.
function Set-PowerShellHALProfileBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$StartMarker,
        [Parameter(Mandatory)][string]$EndMarker,
        [Parameter(Mandatory)][string[]]$BodyLines
    )

    $bytes = if ([System.IO.File]::Exists($Path)) {
        [System.IO.File]::ReadAllBytes($Path)
    } else {
        [byte[]]@()
    }
    $skip = 0
    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = [System.Text.UTF8Encoding]::new($true, $true)
        $skip = 3
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = [System.Text.Encoding]::Unicode
        $skip = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = [System.Text.Encoding]::BigEndianUnicode
        $skip = 2
    }

    try {
        $original = $encoding.GetString($bytes, $skip, $bytes.Length - $skip)
    } catch [System.Text.DecoderFallbackException] {
        throw "Unsupported profile encoding; refusing to modify $Path."
    }

    $crlf = [string][char]13 + [char]10
    $lf = [string][char]10
    $newline = if ($original.Contains($crlf)) { $crlf } else { $lf }
    $block = (@($StartMarker) + $BodyLines + @($EndMarker)) -join $newline
    $start = [regex]::Escape($StartMarker)
    $end = [regex]::Escape($EndMarker)
    $starts = [regex]::Matches($original, "(?m)^[ \t]*$start[ \t]*\r?$")
    $ends = [regex]::Matches($original, "(?m)^[ \t]*$end[ \t]*\r?$")

    if ($starts.Count -ne $ends.Count -or $starts.Count -gt 1) {
        throw "Incomplete or duplicate HAL markers in $Path."
    }
    if ($starts.Count -eq 1) {
        $pattern = "(?ms)^[ \t]*$start[ \t]*\r?\n.*?^[ \t]*$end[ \t]*(?=\r?\n|\z)"
        $match = [regex]::Match($original, $pattern)
        if (-not $match.Success) {
            throw "Malformed HAL marker block in $Path."
        }
        $updated = $original.Substring(0, $match.Index) + $block +
            $original.Substring($match.Index + $match.Length)
    } else {
        $separator = if ($original.Length -eq 0) {
            ''
        } elseif ($original.EndsWith($lf)) {
            $newline
        } else {
            $newline + $newline
        }
        $updated = $original + $separator + $block + $newline
    }

    if ($updated -cne $original) {
        [System.IO.File]::WriteAllText($Path, $updated, $encoding)
    }
}
