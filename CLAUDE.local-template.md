# My homelab (copy into ~/.claude/CLAUDE.md on each machine; do NOT commit real values)

Claude reads ~/.claude/CLAUDE.md in every session. The public skills stay generic and
look here for the facts about this setup.

## Network
- LAN subnet: <e.g. 192.168.1.0/24>
- Proxmox host: <name / IP>
- CI/test bridge or VLAN (internet only, no LAN): <vmbrX / VLAN id>

## Hosts and services
- <CT id> <name> <IP> <distro> <what it runs, init system>
- NAS: <model>, <OS>, data under /mnt/<...>

## Backups
- Method: <PBS / restic>, target: <e.g. storage box>, repo env file: <path>

## CI on Proxmox
- Test VM ID range: 9500-9599, pool: ci-windows
- Template tag: pstest-current
