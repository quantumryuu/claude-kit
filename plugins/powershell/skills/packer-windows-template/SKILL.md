---
name: packer-windows-template
description: Use when creating, changing, debugging or scheduling the Packer build of the Windows golden template on Proxmox (autounattend.xml, VirtIO drivers, provisioning, Windows Update, Sysprep, monthly rebuild workflow).
---

# Packer: Windows golden template on Proxmox

## What this produces
A Proxmox VM **template** (Windows Server 2025 by default) used by the `proxmox-windows-test` skill. It contains: VirtIO drivers + QEMU guest agent, OpenSSH Server (key auth only), PowerShell 7, Pester 5, PSScriptAnalyzer, all Windows updates, generalized with Sysprep.

## Repo layout (keep to this)
```
packer/windows-pstest/
├── windows.pkr.hcl        # source + build blocks
├── variables.pkr.hcl      # every tunable; no secrets with defaults
├── autounattend.xml       # Windows Setup answers
├── unattend-sysprep.xml   # OOBE answers used by Sysprep
└── scripts/
    ├── install-tools.ps1
    ├── harden-and-cleanup.ps1
    └── sysprep.ps1
```

## Plugin and syntax rules
- `packer { required_plugins { proxmox = { source = "github.com/hashicorp/proxmox", version = "~> 1" } } }`, plus `github.com/rgl/windows-update` for updates. Run `packer init` after changing plugins.
- Builder `proxmox-iso` for full builds, `proxmox-clone` for monthly refresh builds.
- Use the `boot_iso {}` block, **not** the deprecated `iso_file`/`iso_url`/`unmount_iso` top-level options. VirtIO ISO and the answer-file CD go in `additional_iso_files {}` blocks. Answer files and scripts go on a CD via `cd_files` + `cd_label` (needs `xorriso` on the build host).
- Auth: API token, `username = "packer@pve!build"`, `token = var.proxmox_token`. Never `root@pam`. Token comes from env/secret (`PKR_VAR_proxmox_token`), never a default value.
- Hardware: `bios = "ovmf"` + `efi_config`, `machine = "q35"`, `scsi_controller = "virtio-scsi-single"`, disk `type = "scsi"`, NIC `model = "virtio"`, `qemu_agent = true`, `os = "win11"` (Proxmox's type for Server 2022/2025 too), TPM only if the OS needs it.
- Communicator: WinRM over HTTP during the build only, on the isolated build network. Password from a sensitive variable.
- Template name includes the build date: `win2025-pstest-${formatdate("YYYY-MM", timestamp())}`; also set `template_description` with the date and git SHA.

## autounattend.xml checklist
- Load VirtIO storage driver from the VirtIO CD (`vioscsi\2k25\amd64`, `NetKVM\2k25\amd64`). A wrong path → "no disk found". Search all drive letters rather than hardcoding one.
- UEFI/GPT partition layout (EFI 100 MB, MSR 16 MB, Windows rest).
- Image selected by `/IMAGE/NAME` (e.g. `Windows Server 2025 SERVERSTANDARDCORE` vs desktop); make it a variable.
- Admin password, auto-logon once, `FirstLogonCommands` that enable WinRM for Packer.
- Keep an evaluation build free of product keys; say in the README which edition/licence is used.

## Provisioning order
1. `install-tools.ps1`: VirtIO guest tools/guest agent from the CD, OpenSSH Server (enable service, firewall rule, `PubkeyAuthentication yes`, `PasswordAuthentication no`, default shell `pwsh`), PowerShell 7 (pinned version; 7.7+ has no MSI, use the 7.6 LTS MSI or the zip, see powershell-scripts skill), `Install-Module Pester -MinimumVersion 5.0`, `Install-Module PSScriptAnalyzer` (AllUsers scope, NuGet provider + PSGallery trusted first).
2. `windows-update` provisioner (`search_criteria = "IsInstalled=0"`, filters exclude preview/driver updates), then a `windows-restart`.
3. `harden-and-cleanup.ps1`: remove the WinRM listener + firewall rule, disable auto-logon, clear temp/update cache, `Optimize-Volume` / `dism /StartComponentCleanup`.
4. `sysprep.ps1` last: `sysprep.exe /generalize /oobe /shutdown /unattend:<unattend-sysprep.xml>`. Packer must not try to talk to the VM afterwards; check the current plugin docs for how to let a guest-initiated shutdown end the build.
Every script: `$ErrorActionPreference='Stop'`, transcript to `C:\Windows\Temp\packer-*.log`, idempotent.

## Two build modes
- **Full (`proxmox-iso`)**: on base changes, or every ~3 months. Fresh install from ISO (also resets an evaluation period).
- **Refresh (`proxmox-clone`)**: monthly. Clone the current template, Windows Update, cleanup, Sysprep, save as new dated template. Much faster. Does not reset an evaluation period.

## Monthly workflow (GitHub Actions, self-hosted runner LXC, private repo)
- Triggers: `schedule` (monthly) + `workflow_dispatch` with input `mode: refresh|full`.
- `timeout-minutes: 240`; `concurrency: packer-windows`.
- Steps: `packer init` → `packer fmt -check` → `packer validate` → `packer build -timestamp-ui` → run the Pester smoke suite against a clone of the **new** template (via `proxmox-windows-test`) → on success, **promote**: update the template ID the tests use (repo variable or a Proxmox tag like `pstest-current`) → keep the previous template, delete older ones.
- On failure: leave the old template in place, delete the half-built VM, fail the workflow.

## Proxmox side (one-time)
- Pool `ci-windows`; role `PackerBuild` with VM.Allocate, VM.Clone, VM.Config.*, VM.PowerMgmt, VM.Audit, VM.Console, Datastore.AllocateSpace, Datastore.AllocateTemplate, Datastore.Audit, SDN.Use; user `packer@pve` + token `build` (privilege separation on) granted on the pool, ISO storage, VM storage and the build bridge only.
- Build bridge/VLAN with internet access but no route to the rest of the LAN.

## Before handing over any change
- `packer fmt` and `packer validate` (with dummy vars) must pass; run them here.
- PSScriptAnalyzer on `scripts/`.
- State plainly that the build itself was not run, and tell the user to watch the first build in the Proxmox console.
