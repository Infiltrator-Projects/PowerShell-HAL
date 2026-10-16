# PowerShell HAL

PowerShell HAL is an inline natural-language assistant for PowerShell.

Press **Ctrl+Spacebar**, tell HAL what you want PowerShell to do, and HAL inserts the generated PowerShell directly into the active command line at the cursor.

It does **not** execute the command. You can inspect or edit the injected PowerShell and press Enter yourself.

## Example

1. At a normal PowerShell prompt, press `Ctrl+Spacebar`.
2. Type: `connect to Entra and find Fred Bloggs`
3. Choose **Insert**.
4. HAL places the generated Microsoft Graph PowerShell directly into the live prompt.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- PSReadLine
- An OpenAI API key with API billing enabled
- Internet access to `https://api.openai.com`

PowerShell HAL uses the OpenAI Responses API. The default model is `gpt-6-luna` for low latency and low cost. Override it with the `POWERSHELL_HAL_MODEL` environment variable.

## Install on Windows

Download or clone this repository, then double-click:

`Install.cmd`

The installer copies the module into both the Windows PowerShell and PowerShell 7 module paths and adds the HAL binding to their current-user profiles. The module manifest owns the installed version.

`Ctrl+Spacebar` normally belongs to PSReadLine's `MenuComplete`; PowerShell HAL deliberately takes that chord while enabled.

## API key

For the current PowerShell session:

```powershell
$env:OPENAI_API_KEY = 'your-api-key'
```

To persist it for your Windows user:

```powershell
[Environment]::SetEnvironmentVariable('OPENAI_API_KEY', 'your-api-key', 'User')
```

Open a new PowerShell window after setting a persistent user environment variable.

## Model override

For example:

```powershell
$env:POWERSHELL_HAL_MODEL = 'gpt-6-sol'
```

## Commands

```powershell
Enable-PowerShellHAL
Disable-PowerShellHAL
Show-PowerShellHALPrompt
Invoke-PowerShellHAL -Request 'show stopped automatic services'
```

`Invoke-PowerShellHAL` returns generated PowerShell as text. The hotkey path calls it and injects that result into the active PSReadLine buffer.

## Design rule

The application has one job:

**natural language -> PowerShell -> insert at cursor -> user decides whether to press Enter**

No background agent, no autonomous execution, no hidden command runner.

## Engineering and validation

The [module manifest](PowerShellHAL.psd1) owns release identity. The [engineering philosophy](PHILOSOPHY.md), [architecture](docs/ARCHITECTURE.md) and [validation](docs/VALIDATION.md) define the maintained contracts. [Releases](https://github.com/Infiltrator-Projects/PowerShell-HAL/releases/latest) contain the exact tested source ZIP and checksums.
