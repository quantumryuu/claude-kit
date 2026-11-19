---
name: powershell-scripts
description: Use when writing or fixing PowerShell scripts for Windows machines, VMs or provisioning (installers, dev-tool setup, window/monitor automation, admin tasks).
---

# PowerShell scripts

## Structure
- Comment-based help at the top (`.SYNOPSIS`, `.EXAMPLE` with real commands).
- A `param()` block; no prompts inside the script unless asked. Use `[switch]` for flags.
- Support `-WhatIf` via `[CmdletBinding(SupportsShouldProcess)]` for anything that changes the system.
- `$ErrorActionPreference = 'Stop'` and `try/catch` around each install step, logging which step failed.

## Compatibility
- State which version the script targets. Default to working on **Windows PowerShell 5.1** too, unless it's explicitly pwsh-only. Avoid `??`, `?.`, ternary and `ForEach-Object -Parallel` in 5.1-compatible scripts.
- Use `-UseBasicParsing` on `Invoke-WebRequest`/`Invoke-RestMethod` for 5.1.
- Set TLS 1.2 for 5.1 downloads: `[Net.ServicePointManager]::SecurityProtocol = 'Tls12'`.

## Installers and downloads
- Idempotent: check for the installed binary/version first and skip if present.
- Resolve download URLs from the vendor's API (e.g. GitHub releases), select assets by regex, and **sort by version, not date**.
- Don't assume an asset type still exists (PowerShell 7.7+ ships no MSI). Fail with a clear message if no asset matches.
- Use `winget` when available; fall back to direct download.
- Verify hashes when the vendor publishes them.

## Win32 / UI automation
- Call `SetProcessDPIAware()` before reading screen coordinates.
- Wait for windows with a timeout loop instead of fixed sleeps.

## Lint with PSScriptAnalyzer (every script you write or change)
- If missing: `Install-Module PSScriptAnalyzer -Scope CurrentUser -Force`.
- Run `Invoke-ScriptAnalyzer -Path <file-or-folder> -Recurse -Severity Warning,Error` and fix what it reports before handing over.
- If the repo has `PSScriptAnalyzerSettings.psd1`, pass it with `-Settings`. If not and the project has several scripts, propose one:
  ```powershell
  @{
      Severity     = @('Error','Warning')
      ExcludeRules = @()   # add a rule only with a comment explaining why
      Rules        = @{
          PSUseCompatibleSyntax = @{ Enable = $true; TargetVersions = @('5.1','7.4') }
      }
  }
  ```
- Suppress a rule only on the specific function, with a justification:
  `[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost','', Justification='Interactive progress output')]`
- `pwsh` runs on Linux, so lint here even for Windows-only scripts.

## Test with Pester 5
- If missing: `Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck`.
- Put tests next to the code as `<Name>.Tests.ps1` (or in `tests/`), using v5 syntax: `BeforeAll { . $PSScriptRoot/<Name>.ps1 }`, `Describe` / `Context` / `It`, `Should -Be`. No v4-style `Should Be`.
- So functions can be tested, keep logic in functions and guard the entry point:
  `if ($MyInvocation.InvocationName -ne '.') { Main @PSBoundParameters }`
- Mock everything that touches the system or network (`Invoke-RestMethod`, `Start-Process`, `Set-ItemProperty`, installers) with `Mock` and check with `Should -Invoke`. Tests must never install or change anything for real.
- Cover at minimum: the happy path, the "already installed → skip" path, and the failure path (e.g. no matching download asset throws a clear error).
- Run: `Invoke-Pester -Path ./tests -Output Detailed`. For CI: `$c = New-PesterConfiguration; $c.Run.Path='./tests'; $c.Run.Exit=$true; $c.TestResult.Enabled=$true; Invoke-Pester -Configuration $c`.
- Windows-only behaviour (registry, Win32 calls) gets `-Skip:(-not $IsWindows)` (`$IsWindows` is unset on 5.1, so treat `$null` as Windows) rather than being left untested silently.

## CI (if the repo uses GitHub Actions)
- Every push: a Linux job (`ubuntu-latest` with `shell: pwsh`, or `container: mcr.microsoft.com/dotnet/sdk:8.0`) runs PSScriptAnalyzer and Pester; fail on analyzer errors or failed tests.
- Real Windows (5.1 + pwsh, registry/MSI/Win32 paths): on `main`, scheduled or manual only. Prefer the ephemeral Proxmox VM (see the `proxmox-windows-test` skill); use `windows-latest` only if the repo is public or the user asks for GitHub-hosted.

## Delivery
- Report the analyzer result and the Pester pass/fail count you got here (in `pwsh` on Linux).
- Say plainly that Windows-only paths were not run on Windows, and give the exact command to test it once.
- For scheduled or shortcut use, give the full `powershell.exe -ExecutionPolicy Bypass -File ...` line.
