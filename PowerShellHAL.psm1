Set-StrictMode -Version Latest

$script:PowerShellHALChord = $null

function Get-PowerShellHALModel {
    if (-not [string]::IsNullOrWhiteSpace($env:POWERSHELL_HAL_MODEL)) {
        return $env:POWERSHELL_HAL_MODEL
    }

    return 'gpt-6-luna'
}

function Show-PowerShellHALPrompt {
    [CmdletBinding()]
    param()

    if ($env:OS -ne 'Windows_NT') {
        return Read-Host 'HAL'
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'PowerShell HAL'
    $form.Width = 700
    $form.Height = 165
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
    $form.TopMost = $true
    $form.KeyPreview = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = 'What do you want PowerShell to do?'
    $label.AutoSize = $true
    $label.Left = 12
    $label.Top = 12
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Left = 12
    $textBox.Top = 36
    $textBox.Width = 660
    $textBox.Height = 48
    $textBox.Multiline = $true
    $textBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $form.Controls.Add($textBox)

    $insertButton = New-Object System.Windows.Forms.Button
    $insertButton.Text = 'Insert'
    $insertButton.Left = 502
    $insertButton.Top = 92
    $insertButton.Width = 80
    $insertButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($insertButton)
    $form.AcceptButton = $insertButton

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Left = 592
    $cancelButton.Top = 92
    $cancelButton.Width = 80
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $form.Add_Shown({ $textBox.Focus() })

    try {
        $result = $form.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return $textBox.Text.Trim()
        }

        return $null
    }
    finally {
        $form.Dispose()
    }
}

function Invoke-PowerShellHAL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Request,

        [string]$CurrentLine = ''
    )

    if ([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
        throw 'OPENAI_API_KEY is not set. Set it in this PowerShell session or as a user environment variable.'
    }

    $model = Get-PowerShellHALModel
    $edition = $PSVersionTable.PSEdition
    $version = $PSVersionTable.PSVersion.ToString()
    $platform = if ($PSVersionTable.PSObject.Properties.Name -contains 'Platform') {
        $PSVersionTable.Platform
    }
    elseif ($env:OS -eq 'Windows_NT') {
        'Win32NT'
    }
    else {
        'Unknown'
    }

    $instructions = @'
You are PowerShell HAL, an inline PowerShell command generator.
Convert the user's natural-language request into executable PowerShell suitable for the current host.
Return ONLY the PowerShell to insert into the command line.
Do not use Markdown fences, prose, labels, comments, or explanations.
Do not pretend a command ran or that a connection succeeded.
Prefer native PowerShell cmdlets and currently supported Microsoft modules.
When authentication or a connection is required to perform the requested operation, include the required connection command before the operation.
For a destructive operation, generate the requested operation accurately; do not silently substitute a read-only command.
The generated text will be inserted into an editable PowerShell prompt and will NOT be executed automatically.
'@

    $input = @"
User request:
$Request

Host context:
PowerShell edition: $edition
PowerShell version: $version
Platform: $platform
Current directory: $((Get-Location).Path)
Existing command-line buffer: $CurrentLine
"@

    $body = @{
        model = $model
        instructions = $instructions
        input = $input
        max_output_tokens = 800
    } | ConvertTo-Json -Depth 8 -Compress

    $headers = @{
        Authorization = "Bearer $($env:OPENAI_API_KEY)"
        'Content-Type' = 'application/json'
    }

    try {
        $response = Invoke-RestMethod -Uri 'https://api.openai.com/v1/responses' -Method Post -Headers $headers -Body $body -TimeoutSec 60
    }
    catch {
        $message = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $message = "$message $($_.ErrorDetails.Message)"
        }
        throw "OpenAI request failed: $message"
    }

    $parts = @()
    foreach ($item in @($response.output)) {
        if ($item.type -ne 'message') { continue }
        foreach ($content in @($item.content)) {
            if ($content.type -eq 'output_text' -and $content.text) {
                $parts += [string]$content.text
            }
        }
    }

    $command = ($parts -join "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw 'The model returned no PowerShell command.'
    }

    if ($command -match '(?s)^\s*```(?:powershell|pwsh|ps1)?\s*(.*?)\s*```\s*$') {
        $command = $Matches[1].Trim()
    }

    return $command
}

function Enable-PowerShellHAL {
    [CmdletBinding()]
    param(
        [string]$Chord = 'Ctrl+Spacebar'
    )

    if (-not (Get-Module -Name PSReadLine)) {
        Import-Module PSReadLine -ErrorAction Stop
    }

    $script:PowerShellHALChord = $Chord

    Set-PSReadLineKeyHandler -Chord $Chord -BriefDescription 'PowerShell HAL' -Description 'Ask HAL for PowerShell and insert the generated command at the cursor.' -ScriptBlock {
        param($key, $arg)

        try {
            $line = ''
            $cursor = 0
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

            $request = Show-PowerShellHALPrompt
            if ([string]::IsNullOrWhiteSpace($request)) {
                return
            }

            $command = Invoke-PowerShellHAL -Request $request -CurrentLine $line
            if (-not [string]::IsNullOrWhiteSpace($command)) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($command)
            }
        }
        catch {
            [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
            Write-Host "`nPowerShell HAL: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Disable-PowerShellHAL {
    [CmdletBinding()]
    param()

    if ([string]::IsNullOrWhiteSpace($script:PowerShellHALChord)) {
        return
    }

    $chord = $script:PowerShellHALChord
    Remove-PSReadLineKeyHandler -Chord $chord -ErrorAction SilentlyContinue

    if ($chord -eq 'Ctrl+Spacebar') {
        Set-PSReadLineKeyHandler -Chord 'Ctrl+Spacebar' -Function MenuComplete
    }

    $script:PowerShellHALChord = $null
}

Export-ModuleMember -Function Show-PowerShellHALPrompt, Invoke-PowerShellHAL, Enable-PowerShellHAL, Disable-PowerShellHAL
