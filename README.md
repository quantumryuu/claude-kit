# claude-kit

My personal Claude Code skills and subagents, packaged as a plugin marketplace so any machine or repo can load them with one command.

| Plugin | What's in it |
|---|---|
| `core` | **troubleshoot** skill (methodical hardware/network/server diagnosis) · **iac-reviewer**, **hardening-auditor**, **runbook-writer** subagents |
| `homelab` | **homelab-lxc** (Proxmox LXC services: OpenRC/systemd, Docker in LXC, safe deploys, backups) · **gh-actions** (secure workflows, homelab deploys, Dependabot) |
| `powershell` | **powershell-scripts** (5.1/7 compatible, PSScriptAnalyzer, Pester 5) · **packer-windows-template** (Windows golden template on Proxmox) · **proxmox-windows-test** (clone → test → destroy on a throwaway Windows VM) |

## Install on a machine

```bash
claude plugin marketplace add quantumryuu/claude-kit
claude plugin install core@claude-kit
claude plugin install homelab@claude-kit
claude plugin install powershell@claude-kit
```
or clone the repo and run `./bootstrap.sh` (same thing, all three plugins; pass names to pick some).

Skills are namespaced, e.g. `/powershell:powershell-scripts`. Claude also loads them automatically when a task matches their description.

## Enable per project instead

Copy `examples/project-settings.json` to `<repo>/.claude/settings.json` and keep only the plugins that repo needs. Claude Code applies it once you trust the folder.

## Without the plugin system

```bash
git clone https://github.com/quantumryuu/claude-kit && cd claude-kit
./bootstrap.sh --symlink                          # into ~/.claude
./bootstrap.sh --symlink --project ~/src/myrepo   # into one repo's .claude
```
`git pull` then updates every linked skill.

## Machine-specific facts

The skills are deliberately generic. Put your own network, hosts and backup details in `~/.claude/CLAUDE.md` on each machine. Start from `CLAUDE.local-template.md`. Don't commit real values to this repo.

## Updating

Edit a skill, `claude plugin validate plugins/<name>`, commit, push. Bump `version` in that plugin's `plugin.json` so installs pick up the change.

## License

MIT
