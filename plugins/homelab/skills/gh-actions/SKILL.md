---
name: gh-actions
description: Use when writing or reviewing GitHub Actions workflows, Dependabot config, or CI/CD that deploys to a homelab.
---

# GitHub Actions

## Security defaults (always)
- Top-level `permissions: contents: read`; widen per job only where needed.
- Pin third-party actions to a full commit SHA with a `# vX.Y` comment; Dependabot keeps them current.
- Self-hosted runners only on **private** repos. Public repos reaching the LAN use `tailscale/github-action` with an ephemeral, tagged auth key.
- Never echo secrets; never use `pull_request_target` with a checkout of PR code.
- Interpolate `${{ github.event.* }}` values via `env:`, not directly in `run:` (script injection).

## Structure
- `concurrency:` group per branch for deploy workflows, `cancel-in-progress: false` for deploys.
- Separate jobs: lint/test → build → deploy (deploy `needs:` the others).
- Cache dependencies (`actions/setup-*` built-in caching).
- Use `workflow_dispatch` on deploy workflows so they can be run by hand.

## Homelab deploys
- Build artifacts on the runner, copy as `.new`, atomic `mv`, restart the service, then a health check (`curl -fsS` or `rc-service <x> status`). Roll back on failed health check.

## Scheduled jobs
- Weekly integration runs against fresh distro images catch upstream breakage.
- Public repos disable schedules after 60 days without activity.

## Dependabot
- `github-actions` + the language ecosystem, grouped, monthly, so it's one PR.

## Validate
Run `actionlint` on every workflow you write or change, and fix what it reports.
