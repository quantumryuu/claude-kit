---
name: homelab-lxc
description: Use when creating, deploying to, updating or debugging a service in a Proxmox homelab (Alpine/Debian LXCs, OpenRC or systemd services, Docker in LXC, restic/PBS backups, a NAS).
---

# Homelab LXC work

## Environment facts
Site-specific facts (subnet, host names, NAS, backup target) live in the user's `~/.claude/CLAUDE.md`, not here. Read them from there. If a fact you need is missing, check the live system or ask; never guess IPs, CT IDs or paths.

## Before changing anything
1. Identify the distro: `cat /etc/os-release`. Alpine and Debian differ in init (OpenRC vs systemd), package manager (`apk` vs `apt`) and libc (musl vs glibc).
2. Get the CT's real IP: `pct exec <id> -- ip -4 addr`.
3. Take a snapshot first: `pct snapshot <id> pre-<change>-$(date +%F)`.
4. Note what is listening: `ss -tlnp` (Debian) / `netstat -tlnp` (Alpine busybox).

## Alpine service pattern (OpenRC)
Create `/etc/init.d/<name>`:
```sh
#!/sbin/openrc-run
name="<name>"
command="/opt/<name>/<binary>"
command_args=""
command_user="<name>:<name>"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/<name>.log"
error_log="/var/log/<name>.err"
depend() { need net; }
```
Then `chmod +x`, `rc-update add <name> default`, `rc-service <name> start`.
Never write a systemd unit for an Alpine CT.

## Deploying a binary (Go etc.)
- Build off-box for the right arch (`GOOS=linux GOARCH=amd64 CGO_ENABLED=0` for x86 Alpine; `GOARCH=arm64` for ARM boards).
- Copy as `<binary>.new`, then atomically `mv` and restart, so a failed copy never leaves a broken binary.
- Keep the previous binary as `<binary>.old` for one-command rollback.

## Docker in LXC
- Needs `nesting=1` (and usually `keyctl=1`) on the CT. Prefer a dedicated Debian CT for Docker.
- Bind-mount source folders must exist on the host before `docker run`; create them first.

## Backups
- Any new service with state: add its data dir to the backup include list and run one manual backup, then list snapshots to confirm it's there.
- Never run `restic forget --prune` without `--dry-run` first.

## Output
End with: what changed, how to verify it, and the exact rollback command.
