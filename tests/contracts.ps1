# SPDX-License-Identifier: GPL-3.0-or-later
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$module = Import-Module (Join-Path $PSScriptRoot '../PowerShellHAL.psd1') -Force -PassThru
$originalKey = $env:OPENAI_API_KEY
try {
    $env:OPENAI_API_KEY = 'fixture-key-never-sent'
    & $module {
        $script:ResponseFixture = $null
        $script:Handlers = @{}
        $script:Removed = New-Object 'System.Collections.Generic.List[string]'
        function script:Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body, $TimeoutSec)
            if ($Uri -ne 'https://api.openai.com/v1/responses') { throw 'Wrong endpoint' }
            $script:CapturedBody = $Body | ConvertFrom-Json
            return $script:ResponseFixture
        }
        function script:Get-Module { param($Name) return [pscustomobject]@{ Name = 'PSReadLine' } }
        function script:Set-PSReadLineKeyHandler {
            param($Chord, $BriefDescription, $Description, $ScriptBlock, $Function)
            if ($Chord -eq 'Invalid') { throw 'Invalid chord' }
            $script:Handlers[$Chord] = if ($Function) { $Function } else { 'HAL' }
        }
        function script:Remove-PSReadLineKeyHandler {
            param($Chord, $ErrorAction)
            $script:Removed.Add($Chord)
            $script:Handlers.Remove($Chord)
        }
        function Check($Condition, [string]$Message) {
            if (-not $Condition) { throw $Message }
        }
        function Reject([scriptblock]$Action, [string]$Expected) {
            $rejected = $false
            try { & $Action | Out-Null }
            catch {
                $rejected = $true
                Check ($_.Exception.Message -like "*$Expected*") "Unexpected rejection: $($_.Exception.Message)"
            }
            Check $rejected "Expected rejection containing '$Expected'"
        }
        function Complete([string]$Text) {
            $script:ResponseFixture = [pscustomobject]@{
                status = 'completed'
                output = @([pscustomobject]@{
                    type = 'message'
                    content = @([pscustomobject]@{ type = 'output_text'; text = $Text })
                })
            }
        }
        Complete 'Get-Process'
        Check ((Invoke-PowerShellHAL -Request 'list processes') -eq 'Get-Process') 'Completed command changed'
        Check ($script:CapturedBody.input -match 'PowerShell version:') 'Host context was omitted'
        Complete ('```powershell' + "`nGet-Service`n" + '```')
        Check ((Invoke-PowerShellHAL -Request 'list services') -eq 'Get-Service') 'Code fence was not removed'

        Complete 'Remove-Item -LiteralPath'
        $script:ResponseFixture.status = 'incomplete'
        Reject { Invoke-PowerShellHAL -Request 'fixture' } 'did not complete'
        $script:ResponseFixture.status = 'failed'
        Reject { Invoke-PowerShellHAL -Request 'fixture' } 'did not complete'

        $script:ResponseFixture = [pscustomobject]@{ status = 'completed' }
        Reject { Invoke-PowerShellHAL -Request 'fixture' } 'no command output'
        $script:ResponseFixture = [pscustomobject]@{ output = @() }
        Reject { Invoke-PowerShellHAL -Request 'fixture' } 'did not complete'
        $script:ResponseFixture = [pscustomobject]@{ status = 'completed'; output = @() }
        Reject { Invoke-PowerShellHAL -Request 'fixture' } 'no PowerShell command'
        $script:ResponseFixture = [pscustomobject]@{
            status = 'completed'
            output = @([pscustomobject]@{
                type = 'message'
                content = @([pscustomobject]@{ type = 'refusal'; refusal = 'fixture' })
            })
        }
        Reject { Invoke-PowerShellHAL -Request 'fixture' } 'declined'
        $env:OPENAI_API_KEY = ''
        Reject { Invoke-PowerShellHAL -Request 'fixture' } 'OPENAI_API_KEY'
        $env:OPENAI_API_KEY = 'fixture-key-never-sent'

        Enable-PowerShellHAL
        Check ($script:Handlers['Ctrl+Spacebar'] -eq 'HAL') 'Default chord was not bound'
        Reject { Enable-PowerShellHAL -Chord 'Invalid' } 'Invalid chord'
        Check ($script:Handlers['Ctrl+Spacebar'] -eq 'HAL') 'Failed rebind removed the active handler'
        Enable-PowerShellHAL -Chord 'Ctrl+h'
        Check ($script:Handlers['Ctrl+Spacebar'] -eq 'MenuComplete') 'Old chord was not restored'
        Check ($script:Handlers['Ctrl+h'] -eq 'HAL') 'New chord was not bound'
        Disable-PowerShellHAL
        Check (-not $script:Handlers.ContainsKey('Ctrl+h')) 'Old HAL handler survived disable'
        Disable-PowerShellHAL
    }
    'PowerShell HAL response and binding contracts passed.'
}
finally {
    Remove-Module PowerShellHAL -ErrorAction SilentlyContinue
    $env:OPENAI_API_KEY = $originalKey
}
