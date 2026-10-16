# Architecture

PowerShell HAL separates command generation, prompt presentation, PSReadLine insertion and installation. `Invoke-PowerShellHAL` performs one HTTPS request and returns text. `Show-PowerShellHALPrompt` owns the Windows dialog and disposes it deterministically. The key handler reads the current buffer, requests text and inserts it without accepting or executing the line.

## Response boundary

The OpenAI Responses API is an external service. Only a completed response containing output text can become a command. Failed, cancelled, incomplete, empty and refusal responses produce an error; a truncated command never becomes an apparently complete insertion. Missing optional response fields are inspected explicitly rather than assumed under PowerShell strict mode. The requested model remains configurable through the existing environment variable.

## Lifetime and persistence

One module instance owns one active chord. Changing that chord removes the previous HAL handler, and disabling or unloading the module restores the standard completion chord when applicable. Dialog state and generated commands are not persisted. API credentials are read from the process environment. The client does not log its Authorization header.

`PowerShellHAL.psd1` is the version authority for the module, installer and release. `Install.ps1` owns user-profile integration for both Windows PowerShell and PowerShell 7. The release workflow packages an exact tested Git tree; it does not install onto the runner or require a live API key.
