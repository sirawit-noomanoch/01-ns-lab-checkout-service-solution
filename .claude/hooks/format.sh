#!/usr/bin/env bash
# PostToolUse hook (matcher: Edit|Write)
# Auto-formats the file Claude just wrote, so nobody has to ask for it.
#
# stdin: hook payload JSON. jq is not available on the team's Windows boxes,
# so the file path is pulled out with node (always present — this is a Node repo).
# Always exits 0: a formatter problem must never block Claude's edit.

set -uo pipefail

payload=$(cat)

file=$(printf '%s' "$payload" | node -e '
let s = "";
process.stdin.on("data", d => (s += d)).on("end", () => {
  try {
    const j = JSON.parse(s);
    const p = (j.tool_response && j.tool_response.filePath) ||
              (j.tool_input && j.tool_input.file_path) || "";
    process.stdout.write(String(p));
  } catch { /* malformed payload -> no path -> no-op */ }
});
' 2>/dev/null)

[ -n "$file" ] || exit 0
[ -f "$file" ] || exit 0

# Only touch what prettier actually understands.
case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md|*.yml|*.yaml) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# --no-install: use the repo's pinned prettier, never silently fetch one.
npx --no-install prettier --write --ignore-unknown "$file" >/dev/null 2>&1 || true

exit 0
