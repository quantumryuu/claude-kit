---
name: proxmox-windows-test
description: Use when running or wiring up PowerShell tests on a real, throwaway Windows VM on Proxmox (linked clone of the golden template → run Pester/PSScriptAnalyzer under Windows PowerShell 5.1 and pwsh → collect results → destroy), locally or from GitHub Actions.
---

# Ephemeral Windows test VMs on Proxmox

## When to use it
Linux (`pwsh` on ubuntu or `mcr.microsoft.com/dotnet/sdk` container) runs the analyzer + Pester on every push. This skill is the **Windows** layer: real Windows PowerShell 5.1, registry, MSI, winget, Win32. Run it on `main`, nightly/weekly, or on demand, not on every push.

## Building blocks
- Template from the `packer-windows-template` skill. Its ID comes from the repo variable `PSTEST_TEMPLATE_ID` (or the Proxmox tag `pstest-current`), never hardcoded.
- Runner: self-hosted GitHub runner in an LXC, **private repos only**. Labels e.g. `[self-hosted, proxmox]`.
- Auth: Proxmox API token `ci@pve!pstest` with role `PSTestRunner` on pool `ci-windows` only: VM.Clone, VM.Allocate, VM.Config.Network, VM.Config.Options, VM.PowerMgmt, VM.Audit, VM.GuestAgent.Audit, VM.GuestAgent.Unrestricted (only if using guest exec), Datastore.AllocateSpace, SDN.Use. No node or root rights.
- Access into the VM: SSH key (template has OpenSSH, key auth only). Private key in a runner secret, injected at run time; nothing baked into the repo.
- Network: test VMs on the isolated CI bridge/VLAN (internet yes, LAN no).

## The run script: `ci/run-windows-tests.sh`
Write it in bash with `set -euo pipefail` and these stages. Use the Proxmox API via `pvesh`-equivalent HTTPS calls or `curl` with the token header (`Authorization: PVEAPIToken=ci@pve!pstest=<secret>`); the runner is not the Proxmox host, so no `qm` there.

1. **Pick a VM ID** in a reserved range (e.g. 9500–9599) with `/cluster/nextid?vmid=...` or a lock file; name `pstest-<run_id>`; add tag `pstest-ephemeral`.
2. **`trap cleanup EXIT`** *before* cloning: stop (force after 60 s) and destroy with `purge=1&destroy-unreferenced-disks=1`. Cleanup must run on success, failure and cancel.
3. **Linked clone** of the template into pool `ci-windows` (`full=0`), wait for the clone task (`/nodes/<node>/tasks/<upid>/status`) to finish.
4. **Start**, then **wait for the guest agent** (`agent/ping`) with a timeout (default 5 min), then read the IP from `agent/network-get-interfaces` (first IPv4 on the CI subnet, skip 169.254/loopback).
5. **Wait for SSH** (port 22) with a timeout; use `StrictHostKeyChecking=accept-new` with a throwaway `UserKnownHostsFile` per run.
6. **Copy** the repo's scripts + tests (`scp -r` or tar over ssh) to `C:\pstest`.
7. **Run, twice**:
   - `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester ... -CI"` (Windows PowerShell 5.1)
   - `pwsh -NoProfile -Command "Invoke-Pester ... -CI"` (PowerShell 7)
   - Also `Invoke-ScriptAnalyzer -Recurse -Severity Error,Warning` once.
   - Each writes NUnit/JUnit XML (`testResults-ps51.xml`, `testResults-pwsh.xml`). Use a `New-PesterConfiguration` with `TestResult.Enabled`, `Run.Exit`.
8. **Collect** the result XML + transcripts back to `./artifacts/`, even if tests failed (capture exit codes, don't let `set -e` skip the copy).
9. Exit non-zero if either Pester run or the analyzer failed. `trap` destroys the VM.

Hard limits: overall timeout (default 30 min) via `timeout`; never print the token or SSH key; never touch VMs outside the reserved ID range / without the `pstest-ephemeral` tag.

## Janitor
A separate scheduled job (daily) lists VMs tagged `pstest-ephemeral` older than 2 hours and destroys them, to catch anything a killed runner left behind.

## Workflow job
```yaml
windows-real:
  if: github.ref == 'refs/heads/main' || github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
  needs: lint-and-test-linux
  runs-on: [self-hosted, proxmox]
  timeout-minutes: 45
  concurrency: { group: pstest-windows, cancel-in-progress: false }
  permissions: { contents: read }
  steps:
    - uses: actions/checkout@<sha> # pin
    - run: ci/run-windows-tests.sh
      env:
        PVE_URL: ${{ vars.PVE_URL }}
        PVE_NODE: ${{ vars.PVE_NODE }}
        PVE_TOKEN_ID: ${{ vars.PVE_TOKEN_ID }}
        PVE_TOKEN_SECRET: ${{ secrets.PVE_TOKEN_SECRET }}
        PSTEST_TEMPLATE_ID: ${{ vars.PSTEST_TEMPLATE_ID }}
        PSTEST_SSH_KEY: ${{ secrets.PSTEST_SSH_KEY }}
    - uses: actions/upload-artifact@<sha> # pin
      if: always()
      with: { name: windows-test-results, path: artifacts/ }
```
Add a test-report step (e.g. a JUnit reporter action, pinned) if the user wants results in the PR.

## Local use
The same script must run from a shell on the LAN (Mint box / WSL) with the env vars exported, so the user can test without pushing. Provide a `ci/.env.example` (no real values) and add `ci/.env` to `.gitignore`.

## Before handing over
- `shellcheck ci/run-windows-tests.sh`, `actionlint` on the workflow, PSScriptAnalyzer on any `.ps1` you wrote.
- Dry-run mode (`--dry-run`) that prints the API calls it would make; run that here.
- Say plainly that it was not run against the real Proxmox host, and suggest the first real run be `workflow_dispatch` while watching the Proxmox task log.
