#!/usr/bin/env bash
# Claude Code PostToolUse hook (Write|Edit): format the file Claude just
# changed, using the tool versions pinned in .pre-commit-config.yaml.
#
#   *.py  ruff import sorting (rule I) + ruff format
#   *.md  rumdl fmt, only for files that don't exist on origin/master.
#         Preexisting Markdown is never touched.
#
# Formatting only: lint findings are left for pre-commit / the fork-pr skill.
# The hook never fails the edit; it always exits 0.
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
cd "$root" 2>/dev/null || exit 0

file=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -n "$file" && -f "$file" ]] || exit 0

# Only files inside this repo.
case "$file" in
  "$root"/*) rel="${file#"$root"/}" ;;
  *) exit 0 ;;
esac

# "pkg@version" using the rev pinned for a pre-commit repo, or plain "pkg".
pinned_tool() {
  local version
  version=$(awk -v repo="$2" '
    index($0, repo) { getline; gsub(/["'\'']/, ""); sub(/.*rev:[ \t]*v?/, ""); print; exit }
  ' .pre-commit-config.yaml 2>/dev/null)
  if [[ -n "$version" ]]; then echo "$1@$version"; else echo "$1"; fi
}

case "$rel" in
  *.py)
    ruff=$(pinned_tool ruff astral-sh/ruff-pre-commit)
    uvx -q "$ruff" check --select I --fix --force-exclude --quiet "$rel" >/dev/null 2>&1
    uvx -q "$ruff" format --force-exclude --quiet "$rel" >/dev/null 2>&1
    ;;
  *.md)
    base=origin/master
    git rev-parse -q --verify "$base" >/dev/null || base=HEAD
    git cat-file -e "$base:$rel" 2>/dev/null && exit 0
    rumdl=$(pinned_tool rumdl rvben/rumdl-pre-commit)
    uvx -q "$rumdl" fmt "$rel" >/dev/null 2>&1
    ;;
esac
exit 0
