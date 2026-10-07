@{
    RootModule = 'PowerShellHAL.psm1'
    ModuleVersion = '0.1.0'
    GUID = '3d4a1fd0-928a-4b3f-9ad3-e9e1457d3396'
    Author = 'Infiltrator Projects'
    CompanyName = 'Infiltrator Projects'
    Copyright = '(c) Infiltrator Projects'
    Description = 'Inline AI assistance for PowerShell. Ask in natural language and inject the generated PowerShell into the active PSReadLine prompt without executing it.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Show-PowerShellHALPrompt',
        'Invoke-PowerShellHAL',
        'Enable-PowerShellHAL',
        'Disable-PowerShellHAL'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('PowerShell', 'AI', 'PSReadLine', 'OpenAI')
            ProjectUri = 'https://github.com/Infiltrator-Projects/PowerShell-HAL'
        }
    }
}
