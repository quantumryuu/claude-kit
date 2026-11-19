#!/usr/bin/env bash
# Install claude-kit on this machine (or into one project).
#
#   ./bootstrap.sh                      # plugin install, all plugins, user scope
#   ./bootstrap.sh core homelab         # only these plugins
#   ./bootstrap.sh --symlink            # no plugin system: symlink skills/agents into ~/.claude
#   ./bootstrap.sh --symlink --project /path/to/repo   # symlink into <repo>/.claude
#
# Re-running is safe. With --symlink, `git pull` in this repo updates everything.
set -euo pipefail

REPO="${CLAUDE_KIT_REPO:-quantumryuu/claude-kit}"
MARKET="claude-kit"
ALL_PLUGINS=(core homelab powershell)
MODE="plugin"
TARGET="$HOME/.claude"
PLUGINS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --symlink) MODE="symlink" ;;
    --project) shift; TARGET="$(cd "${1:?--project needs a path}" && pwd)/.claude" ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) PLUGINS+=("$1") ;;
  esac
  shift
done
[[ ${#PLUGINS[@]} -eq 0 ]] && PLUGINS=("${ALL_PLUGINS[@]}")

for p in "${PLUGINS[@]}"; do
  [[ " ${ALL_PLUGINS[*]} " == *" $p "* ]] || { echo "Unknown plugin: $p (choose from: ${ALL_PLUGINS[*]})" >&2; exit 1; }
done

if [[ "$MODE" == "plugin" ]]; then
  command -v claude >/dev/null || { echo "Claude Code CLI not found. Install it first, or use --symlink." >&2; exit 1; }
  if claude plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
    claude plugin marketplace update "$MARKET"
  else
    claude plugin marketplace add "$REPO"
  fi
  for p in "${PLUGINS[@]}"; do
    claude plugin install "$p@$MARKET"
  done
  echo "Done. Start a new Claude Code session to load: ${PLUGINS[*]}"
  exit 0
fi

# --symlink mode: link from a local clone of this repo
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$SRC/plugins" ]] || { echo "Run --symlink from inside a clone of the repo." >&2; exit 1; }
mkdir -p "$TARGET/skills" "$TARGET/agents"
link() {  # link <source> <dest>; never overwrite a real file/dir
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then ln -sfn "$src" "$dst"
  elif [[ -e "$dst" ]]; then echo "  skip (exists, not a link): $dst"; return
  else ln -s "$src" "$dst"; fi
  echo "  linked $(basename "$dst")"
}
for p in "${PLUGINS[@]}"; do
  echo "$p:"
  for d in "$SRC/plugins/$p"/skills/*/;  do [[ -d "$d" ]] && link "${d%/}" "$TARGET/skills/$(basename "$d")"; done
  for f in "$SRC/plugins/$p"/agents/*.md; do [[ -f "$f" ]] && link "$f" "$TARGET/agents/$(basename "$f")"; done
done
echo "Done. Skills and agents linked into $TARGET"
